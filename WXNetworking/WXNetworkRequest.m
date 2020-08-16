//
//  WXNetworkRequest.m
//  WXNetworking
//
//  Created by MaoWX on 2020/08/16.
//  Copyright © 2020 WX. All rights reserved.
//

#import "WXNetworkRequest.h"
#import "WXNetworkConfig.h"
#import "WXNetworkPlugin.h"
#import <AFNetworking/AFNetworking.h>
#import <YYModel/YYModel.h>
#import <YYCache/YYCache.h>

///  HTTP Request method
typedef NS_ENUM(NSInteger, WXRequestMulticenterType) {
    WXNetworkRequestWillStart = 0,
    WXNetworkRequestWillStop,
    WXNetworkRequestDidCompletion,
};

#pragma mark - =====================<WXResponseModel>=====================================

@interface WXResponseModel ()
@property (nonatomic, assign, readwrite) BOOL              isSuccess;
@property (nonatomic, assign, readwrite) BOOL              isCacheData;
@property (nonatomic, strong, readwrite) id                responseModel;
@property (nonatomic, strong, readwrite) id                responseObject;//可能为UIimage/NSData/...
@property (nonatomic, strong, readwrite) NSDictionary      *responseDict;
@property (nonatomic, assign, readwrite) CGFloat           responseDuration;
@property (nonatomic, assign, readwrite) NSInteger         responseCode;
@property (nonatomic, copy  , readwrite) NSString          *responseMsg;
@property (nonatomic, strong, readwrite) NSError           *error;
@property (nonatomic, strong, readwrite) NSHTTPURLResponse *urlResponse;
@property (nonatomic, strong, readwrite) NSURLRequest      *originalRequest;
@property (nonatomic, copy) NSString                       *apiUniquelyIp;
@end

@implementation WXResponseModel

- (void)configModel:(WXNetworkRequest *)requestApi
       responseDict:(NSDictionary *)responseDict
{
    if (requestApi.responseModelCalss && [responseDict isKindOfClass:[NSDictionary class]]) {
        NSDictionary *modelJSON = responseDict;
        
        NSString *modelKey = [WXNetworkConfig sharedInstance].resultKey;
        if ([modelKey isKindOfClass:[NSString class]]) {
            if (responseDict[modelKey]) {
                modelJSON = responseDict[modelKey];
            }
        }
        self.responseModel = [requestApi.responseModelCalss yy_modelWithJSON:modelJSON];
    }
}
@end

#pragma mark - =====================<WXNetworkRequest>=====================================


static NSMutableDictionary<NSString *, NSDictionary *> *         _globleRequestList;
static NSMutableDictionary<NSString *, NSURLSessionDataTask *> * _globleTasksList;
static NSMutableDictionary<NSString *, NSURLSession *> *         _globleSessionList;

@interface WXNetworkRequest ()
@property (nonatomic, copy) NSString                *cacheKey;
@property (nonatomic, copy) NSString                *apiUniquelyIp;
@property (nonatomic, assign) NSInteger             retryCount;
@property (nonatomic, assign) double                requestDuration;
@property (nonatomic, weak) id<WXNetworkDelegate>  responseDelegate;
@property (nonatomic, strong) NSString              *parmatersJsonString;
@property (nonatomic, strong) NSString              *managerRequestKey;
@property (nonatomic, copy) WXNetworkResponseBlock configResponseCallback;
@end

@implementation WXNetworkRequest

+ (void)initialize {
    _globleRequestList = [NSMutableDictionary dictionary];
    _globleTasksList   = [NSMutableDictionary dictionary];
    _globleSessionList = [NSMutableDictionary dictionary];
}

#pragma mark - <StartNetwork>

/*
 * 网络请求方法
 * @parm networkDelegate 请求成功失败回调代理
 */
- (NSURLSessionDataTask *)startRequestWithDelegate:(id<WXNetworkDelegate>)responseDelegate {
    self.responseDelegate = responseDelegate;
    return [self startRequestWithBlock:self.configResponseCallback ?: self.configResponseDelegateCallback];
}

- (WXNetworkResponseBlock)configResponseDelegateCallback {
    __weak typeof(self) weakSelf = self;
    return ^ (WXResponseModel *responseModel) {
        if (weakSelf.responseDelegate &&
            [weakSelf.responseDelegate respondsToSelector:@selector(wxResponseWithRequest:responseModel:)]) {
            [weakSelf.responseDelegate wxResponseWithRequest:weakSelf responseModel:responseModel];
        }
    };
}

/*
 * 网络请求方法
 * @parm successBlock 请求成功回调block
 * @parm failureBlock 请求失败回调block
 */
- (NSURLSessionDataTask *)startRequestWithBlock:(WXNetworkResponseBlock)responseBlock {
    if ([self requestUrlIsIncorrect:self.requestUrl]) {
        [self configResponseBlock:responseBlock responseObj:nil];
        return nil;
    }
    if ([self checkCurrentTaskDoing]) {
        [self.class cancelRequestsWithApiList:@[self]];
    }
    void(^networkBlock)(id rsp) = ^(id responseObj) {
        [self configResponseBlock:responseBlock responseObj:responseObj];
    };
    if ([self checkRequestInCache]) {
        [self readRequestCacheWithBlock:networkBlock];
    }
    [self handleMulticenter:WXNetworkRequestWillStart responseModel:nil];
    NSURLSessionDataTask *task = [self requestWithBlock:networkBlock failureBlock:networkBlock];
    [self insertCurrentRequestToRequestTableList:task];
    if (![WXNetworkConfig sharedInstance].closeUrlResponsePrintfLog) {
        WXNetworkLog(@"\n👉👉👉页面已发出请求= %@", self.requestUrl);
    }
    return task;
}

#pragma mark - <DealWithResponse>

- (void)configResponseBlock:(WXNetworkResponseBlock)responseBlock responseObj:(id)responseObj {
    if (responseObj) {
        if (self.retryCount < self.retryCountWhenFailure
            && [responseObj isKindOfClass:[NSError class]]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                self.retryCount ++;
                [self startRequestWithBlock:responseBlock];
            });
        } else {
            WXResponseModel *responseModel = [self configResponseModel:responseObj];
            if (responseBlock) {
                responseBlock(responseModel);
            }
            [self handleMulticenter:WXNetworkRequestDidCompletion responseModel:responseModel];
        }
    } else {
        NSError *error = [NSError errorWithDomain:self.configFailMessage code:-444 userInfo:nil];
        WXResponseModel *responseModel = [self configResponseModel:error];
        if (responseBlock) {
            responseBlock(responseModel);
        }
        [self handleMulticenter:WXNetworkRequestDidCompletion responseModel:responseModel];
    }
}

- (WXResponseModel *)configResponseModel:(id)responseObj {
    
    WXResponseModel *rspModel = [[WXResponseModel alloc] init];
    rspModel.responseDuration  = [self getCurrentTimestamp] - self.requestDuration;
    rspModel.apiUniquelyIp     = self.apiUniquelyIp;
    rspModel.responseObject    = responseObj;
    
    rspModel.originalRequest   = self.requestDataTask.originalRequest;
    if ([self.requestDataTask.response isKindOfClass:[NSHTTPURLResponse class]]) {
        rspModel.urlResponse   = (NSHTTPURLResponse *)(self.requestDataTask.response);
    }
    if ([responseObj isKindOfClass:[NSError class]]) {
        rspModel.isSuccess     = NO;
        rspModel.isCacheData   = NO;
        rspModel.responseMsg   = ((NSError *)responseObj).domain;
        rspModel.responseCode  = ((NSError *)responseObj).code;
        rspModel.error         = (NSError *)responseObj;
        
    } else {
        NSDictionary *responseDict  = [self packagingResponseObj:responseObj responseModel:rspModel];
        WXNetworkConfig *config    = [WXNetworkConfig sharedInstance];
        NSString *responseCode      = [responseDict objectForKey:config.statusKey];
        rspModel.responseDict       = responseDict;
        rspModel.responseCode       = [responseCode integerValue];
        rspModel.isSuccess          = (responseCode && rspModel.responseCode == config.statusCode.integerValue);
        
        NSString *msg = responseDict[config.messageKey];
        if ([msg isKindOfClass:[NSString class]]) {
            rspModel.responseMsg    = msg;
        }
        if (rspModel.isSuccess) {
            [rspModel configModel:self responseDict:responseDict];
        } else {
            rspModel.responseMsg    = rspModel.responseMsg ?: self.configFailMessage;
            rspModel.error          = [NSError errorWithDomain:rspModel.responseMsg
                                                          code:rspModel.responseCode
                                                      userInfo:responseDict];
        }
    }
    if (!rspModel.isCacheData) {
        [self handleMulticenter:WXNetworkRequestWillStop responseModel:rspModel];
    }
    return rspModel;
}

- (NSDictionary *)packagingResponseObj:(id)responseObj
                       responseModel:(WXResponseModel *)responseModel {
    
    NSMutableDictionary *responseDcit = [NSMutableDictionary dictionary];
    WXNetworkConfig *config = [WXNetworkConfig sharedInstance];
    
    if ([responseObj isKindOfClass:[NSDictionary class]]) {
        [responseDcit addEntriesFromDictionary:responseObj];
        if ([responseDcit objectForKey:kWXRequestDataFromCacheKey]) {
            [responseDcit removeObjectForKey:kWXRequestDataFromCacheKey];
            responseModel.isCacheData = YES;
        }
    } else if ([responseObj isKindOfClass:[NSData class]]) {
        NSData *rspData = [responseObj mutableCopy];
        if ([rspData isKindOfClass:[NSData class]]) {
            responseModel.responseObject = rspData;
        }
    } else {
        //注意:不能直接赋值responseObj, 因为插件库那边会dataWithJSONObject打印会崩溃
        //responseDcit[config.resultKey] = [responseObj description];
    }
    // 只要返回为非Error就包装一个公共的key, 防止页面当失败解析
    if (![responseDcit valueForKey:config.statusKey]) {
        responseDcit[config.statusKey] = [NSString stringWithFormat:@"%@", config.statusCode];
    }
    return responseDcit;
}

- (void)handleMulticenter:(WXRequestMulticenterType)type
            responseModel:(WXResponseModel *)responseModel {
    
    id<WXNetworkMulticenter> delegate = nil;
    if (self.multicenterDelegate) {
        delegate = self.multicenterDelegate;
    } else {
        delegate = [WXNetworkConfig sharedInstance].globleMulticenterDelegate;
    }
    switch (type) {
        case WXNetworkRequestWillStart: {
            [self judgeShowLoading:YES];
            self.requestDuration = [self getCurrentTimestamp];
            
            SEL selector = @selector(requestWillStart:);            
            if ([delegate respondsToSelector:selector]) {
                [delegate requestWillStart:self];
            }
            for (id<WXNetworkMulticenter> accessory in self.requestAccessories) {
                if ([accessory respondsToSelector:selector]) {
                    [accessory requestWillStart:self];
                }
            }
        }
            break;
        case WXNetworkRequestWillStop: {
            SEL selector = @selector(requestWillStop:responseModel:);
            if ([delegate respondsToSelector:selector]) {
                [delegate requestWillStop:self responseModel:responseModel];
            }
            for (id<WXNetworkMulticenter> accessory in self.requestAccessories) {
                if ([accessory respondsToSelector:selector]) {
                    [accessory requestWillStop:self responseModel:responseModel];
                }
            }
        }
            break;
        case WXNetworkRequestDidCompletion: {
            [self judgeShowLoading:NO];
            [self removeCompleteRequestFromGlobleRequestList];
            [self checkPostNotification:responseModel.responseCode];
            [WXNetworkPlugin uploadNetworkResponseJson:responseModel request:self];
            
            if (![WXNetworkConfig sharedInstance].closeUrlResponsePrintfLog) {
                NSString *logHeader = [WXNetworkPlugin appendingPrintfLogHeader:responseModel request:self];
                NSString *logFooter = [WXNetworkPlugin appendingPrintfLogFooter:responseModel];
                WXNetworkLog(@"%@", [NSString stringWithFormat:@"%@%@", logHeader, logFooter]);
            }
            SEL selector = @selector(requestDidCompletion:responseModel:);
            if ([delegate respondsToSelector:selector]) {
                [delegate requestDidCompletion:self responseModel:responseModel];
            }
            for (id<WXNetworkMulticenter> accessory in self.requestAccessories) {
                if ([accessory respondsToSelector:selector]) {
                    [accessory requestDidCompletion:self responseModel:responseModel];
                }
            }
            // save as much as possible at the end
            if (!responseModel.isCacheData) {
                [self saveResponseObjToCache:responseModel];
            }
        }
            break;
        default:
            break;
    }
}

- (NSString *)apiUniquelyIp {
    if (!_apiUniquelyIp) {
        _apiUniquelyIp = [NSString stringWithFormat:@"%p", self];
    }
    return _apiUniquelyIp;
}

#pragma mark - <Notification>

- (void)checkPostNotification:(NSInteger)responseCode {
    NSDictionary *notifyDict = [WXNetworkConfig sharedInstance].errorCodeNotifyDict;
    if (![notifyDict isKindOfClass:[NSDictionary class]]) return;
    
    for (NSString *notifyName in notifyDict.allKeys) {
        if (![notifyName isKindOfClass:[NSString class]]) continue;
        
        NSNumber *notifyNumber = notifyDict[notifyName];
        if ([notifyNumber isKindOfClass:[NSNumber class]]) continue;
        
        if (responseCode == notifyNumber.integerValue) {
            [[NSNotificationCenter defaultCenter] postNotificationName:notifyName object:nil];
        }
    }
}

#pragma mark - <verifyUrl>

- (BOOL)requestUrlIsIncorrect:(NSString *)requestUrl {
    return (![requestUrl isKindOfClass:[NSString class]] || ![requestUrl hasPrefix:@"http"]);
}

#pragma mark - <DealWithCache>

- (BOOL)checkRequestInCache {
    if (self.cacheResponseBlock || self.autoCacheResponse) {
        YYDiskCache *cache = [WXNetworkConfig sharedInstance].networkDiskCache;
        return (cache && [cache containsObjectForKey:self.cacheKey]);
    }
    return NO;
}

- (NSString *)cacheKey {
    if (self.cacheResponseBlock || self.autoCacheResponse) {
        if (!_cacheKey) {
            _cacheKey = [WXNetworkPlugin WXMD5String:self.managerRequestKey];
        }
        return _cacheKey;
    }
    return nil;
}

- (void)readRequestCacheWithBlock:(void(^)(NSDictionary *))fetchCacheBlock {
    if (self.cacheResponseBlock || self.autoCacheResponse) {
        YYDiskCache *cache = [WXNetworkConfig sharedInstance].networkDiskCache;
        [cache objectForKey:self.cacheKey withBlock:^(NSString *key, id cacheObject) {
            if (![cacheObject isKindOfClass:[NSDictionary class]])return;
            if (!fetchCacheBlock)return;
            
            NSMutableDictionary *cacheDcit = [NSMutableDictionary dictionaryWithDictionary:cacheObject];
            cacheDcit[kWXRequestDataFromCacheKey] = @(YES);
            if ([NSThread isMainThread]) {
                fetchCacheBlock(cacheDcit);
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    fetchCacheBlock(cacheDcit);
                });
            }
        }];
    }
}

- (void)saveResponseObjToCache:(WXResponseModel *)responseModel {
    
    if (self.cacheResponseBlock) {
        NSDictionary *customResponseObject = self.cacheResponseBlock(responseModel);
        if (![customResponseObject isKindOfClass:[NSDictionary class]]) return;
        
        YYDiskCache *cache = [WXNetworkConfig sharedInstance].networkDiskCache;
        [cache setObject:customResponseObject forKey:self.cacheKey withBlock:^{
        }];
        
    } else if (self.autoCacheResponse) {
        if (![responseModel.responseObject isKindOfClass:[NSDictionary class]]) return;
        YYDiskCache *cache = [WXNetworkConfig sharedInstance].networkDiskCache;
        [cache setObject:responseModel.responseObject forKey:self.cacheKey withBlock:^{
        }];
    }
}

#pragma mark - <DealWithTask>
- (NSString *)managerRequestKey {
    if (!_managerRequestKey) {
        _managerRequestKey = [NSString stringWithFormat:@"%@%@",self.requestUrl, self.parmatersJsonString];
    }
    return _managerRequestKey;
}

- (BOOL)checkCurrentTaskDoing {
    NSDictionary *parmaters = _globleRequestList[self.managerRequestKey];
    if (![parmaters isKindOfClass:[NSDictionary class]]) return NO;
    return [parmaters isEqualToDictionary:self.finalParameters];
}

- (void)insertCurrentRequestToRequestTableList:(NSURLSessionDataTask *)sessionDataTask {
    if (!(_globleRequestList && _globleTasksList && _globleSessionList) || !sessionDataTask)return ;
    
    if ([self.requestUrl isKindOfClass:[NSString class]]) {
        _globleRequestList[self.managerRequestKey] = self.finalParameters ?: @{};
        _globleSessionList[self.managerRequestKey] = self.urlSession;
        
        if ([sessionDataTask isKindOfClass:[NSURLSessionDataTask class]]) {
            _globleTasksList[self.managerRequestKey] = sessionDataTask;
        }
    }
}

- (void)removeCompleteRequestFromGlobleRequestList {
    [_globleRequestList removeObjectForKey:self.managerRequestKey];
    [_globleTasksList removeObjectForKey:self.managerRequestKey];
    [_globleSessionList removeObjectForKey:self.managerRequestKey];
}

+ (void)cancelGlobleAllRequestMangerTask {
    [_globleTasksList enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSURLSessionDataTask * _Nonnull task, BOOL * _Nonnull stop) {
        if ([task isKindOfClass:[NSURLSessionDataTask class]]) {
            [task cancel];
        }
    }];
    [_globleSessionList enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSURLSession * _Nonnull session, BOOL * _Nonnull stop) {
        if ([session isKindOfClass:[NSURLSession class]]) {
            [session finishTasksAndInvalidate];
        }
    }];
    [_globleRequestList removeAllObjects];
    [_globleTasksList removeAllObjects];
    [_globleSessionList removeAllObjects];
}

+ (void)cancelRequestsWithApiList:(NSArray<WXNetworkRequest *> *)requestList {
    if (!_globleRequestList || !_globleTasksList)return ;
    [requestList enumerateObjectsUsingBlock:^(WXNetworkRequest * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [_globleRequestList removeObjectForKey:obj.managerRequestKey];
        
        NSURLSession *session = _globleSessionList[obj.managerRequestKey];
        if ([session isKindOfClass:[NSURLSession class]]) {
            [session finishTasksAndInvalidate];
        }
        NSURLSessionDataTask *task = _globleTasksList[obj.managerRequestKey];
        if ([task isKindOfClass:[NSURLSessionDataTask class]]) {
            [task cancel];
        }
        [_globleTasksList removeObjectForKey:obj.managerRequestKey];
    }];
}

#pragma mark - <DealWithHUD>

- (void)judgeShowLoading:(BOOL)show {
    if (![WXNetworkConfig sharedInstance].showRequestLaoding) return;
    if (![self.loadingSuperView isKindOfClass:[UIView class]]) return;
    if (show) {
        [WXNetworkHUD showLoadingToView:self.loadingSuperView];
    } else {
        [WXNetworkHUD hideLoadingFromView:self.loadingSuperView];
    }
}

- (double)getCurrentTimestamp {
    NSDate *dat = [NSDate dateWithTimeIntervalSinceNow:0];
    NSTimeInterval timeInterval = [dat timeIntervalSince1970] * 1000;
    return timeInterval;
}

- (NSString *)configFailMessage {
    NSString *toastText = [WXNetworkConfig sharedInstance].requestFailDefaultMessage;
    if (![toastText isKindOfClass:[NSString class]] || toastText.length == 0) {
        toastText = KWXRequestFailueTipMessage;
    }
    return toastText;
}

- (NSString *)parmatersJsonString {
    if (self.finalParameters) {
        if (!_parmatersJsonString) {
            _parmatersJsonString = [self.finalParameters yy_modelToJSONString];;
        }
        return _parmatersJsonString;
    }
    return @"";//self.apiUniquelyIp;
}

@end


#pragma mark - =====================<WXNetworkBatchRequest>=====================================

@interface WXNetworkBatchRequest ()
@property (nonatomic, weak) id<WXNetworkBatchDelegate>  responseBatchDelegate;
@property (nonatomic, copy) WXNetworkBatchBlock         responseBatchBlock;
@property (nonatomic, copy) WXNetworkResponseBlock      configBatchDelegateCallback;
@property (nonatomic, assign) NSInteger                  requestCount;
@property (nonatomic, strong) NSMutableArray             *requestApiArray;
@property (nonatomic, strong) NSMutableDictionary        *responseInfoDict;
@property(nonatomic, assign, readwrite) BOOL             isAllSuccess;
@property (nonatomic, assign) BOOL                       hasMarkBatchFailure;
@property (nonatomic, assign) BOOL                       waitAllSuccess;
@property (nonatomic, strong) WXNetworkBatchRequest     *batchRequest;
@end

@implementation WXNetworkBatchRequest

/**
 * 便捷初始化多并发请求函数
 * @param requestArray 请求WXNetworkRequest对象数组
 * @return 多并发请求对象
 */
+ (instancetype)batchArrayRequest:(NSArray<WXNetworkRequest *> *)requestArray {
    return [[WXNetworkBatchRequest alloc] initWithRequestArray:requestArray];
}

- (instancetype)initWithRequestArray:(NSArray<WXNetworkRequest *> *)requestArray {
    self = [super init];
    if (self) {
        _requestApiArray = [requestArray copy];
        _requestCount = _requestApiArray.count;
        for (WXNetworkRequest *requestApi in _requestApiArray) {
            BOOL isRequestApi = [requestApi isKindOfClass:[WXNetworkRequest class]];
            if (!isRequestApi) {
                NSAssert(isRequestApi, KWXRequestRequestArrayAssert);
                return nil;
            }
        }
    }
    return self;
}

/**
 批量网络请求
 
 @param responseDelegate 请求完成响应代理回调
 @param waitAllSuccess 是否等待全部请求完成
 */
- (void)startRequestWithDelegate:(id<WXNetworkBatchDelegate>)responseDelegate
                  waitAllSuccess:(BOOL)waitAllSuccess
{
    BOOL isApiArray = [_requestApiArray isKindOfClass:[NSArray class]];
    if (!isApiArray) {
        NSAssert(isApiArray, KWXRequestRequestArrayObjAssert);
        return ;
    }
    self.batchRequest = self;
    self.responseBatchDelegate = responseDelegate;
    self.waitAllSuccess = waitAllSuccess;
    self.responseBatchBlock = nil;
    for (WXNetworkRequest *serverApi in self.requestApiArray) {
        serverApi.configResponseCallback = self.configBatchDelegateCallback;
        [serverApi startRequestWithDelegate:responseDelegate];
    }
}

/**
 *批量网络请求
 
 @param responseBlock 请求完成响应block回调
 @param waitAllSuccess 是否等待全部请求完成
 */
- (void)startRequestWithBlock:(WXNetworkBatchBlock)responseBlock
               waitAllSuccess:(BOOL)waitAllSuccess {
    BOOL isApiArray = [_requestApiArray isKindOfClass:[NSArray class]];
    if (!isApiArray) {
        NSAssert(isApiArray, KWXRequestRequestArrayObjAssert);
        return ;
    }
    self.batchRequest = self;
    self.responseBatchBlock = responseBlock;
    self.waitAllSuccess = waitAllSuccess;
    self.responseBatchDelegate = nil;
    for (WXNetworkRequest *requestApi in self.requestApiArray) {
        [requestApi startRequestWithBlock:self.configBatchDelegateCallback];
    }
}

- (WXNetworkResponseBlock)configBatchDelegateCallback {
    if (!_configBatchDelegateCallback) {
        __weak typeof(self) weakSelf = self;
        _configBatchDelegateCallback = ^(WXResponseModel *responseModel) {
            if (!responseModel.isCacheData) {
                [weakSelf dealwithResponseHandle:responseModel];
            }
            if (!responseModel.isSuccess && !weakSelf.waitAllSuccess && !weakSelf.hasMarkBatchFailure) {
                weakSelf.hasMarkBatchFailure = YES;
                for (WXNetworkRequest *requestApi in weakSelf.requestApiArray) {
                    if (![requestApi.apiUniquelyIp isEqualToString:responseModel.apiUniquelyIp]) {
                        [requestApi.requestDataTask cancel];
                        [requestApi.urlSession finishTasksAndInvalidate];
                    }
                }
            }
        };
    }
    return _configBatchDelegateCallback;
}

- (void)dealwithResponseHandle:(WXResponseModel *)responseModel {
    @synchronized (self) {
        self.requestCount--;
        self.responseInfoDict[responseModel.apiUniquelyIp] = responseModel;
        
        if (self.requestCount <= 0) {
            self.isAllSuccess = !self.hasMarkBatchFailure;
            NSMutableArray *responseArray = [NSMutableArray array];
            for (NSInteger i=0; i<self.requestApiArray.count; i++) {
                WXNetworkRequest *requestApi = self.requestApiArray[i];
                id responseObj = self.responseInfoDict[requestApi.apiUniquelyIp];
                if (responseObj) {
                    [responseArray addObject:responseObj];
                }
            }
            // 请求最终回调
            if (self.responseBatchBlock) {
                self.responseBatchBlock(responseArray, self);
                
            } else if (self.responseBatchDelegate &&
                       [self.responseBatchDelegate respondsToSelector:@selector(wxBatchResponseWithRequest:modelArray:)]) {
                [self.responseBatchDelegate wxBatchResponseWithRequest:self modelArray:responseArray];
            }
            self.batchRequest = nil;
        }
    }
}

- (NSMutableDictionary *)responseInfoDict {
    if (!_responseInfoDict) {
        _responseInfoDict = [NSMutableDictionary dictionary];
    }
    return _responseInfoDict;
}

@end
