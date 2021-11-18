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
@property (nonatomic, assign, readwrite) CGFloat           duration;
@property (nonatomic, assign, readwrite) NSInteger         responseCode;
@property (nonatomic, strong, readwrite) id                responseObject;//NSDictionary/ UIImage/ NSData/...
@property (nonatomic, strong, readwrite) id                parseModel;
@property (nonatomic, strong, readwrite) NSDictionary      *responseDict;
@property (nonatomic, copy  , readwrite) NSString          *responseMsg;
@property (nonatomic, strong, readwrite) NSError           *error;
@property (nonatomic, strong, readwrite) NSHTTPURLResponse *urlResponse;
@property (nonatomic, strong, readwrite) NSURLRequest      *originalRequest;
@property (nonatomic, copy) NSString                       *apiUniquelyIp;
@end

@implementation WXResponseModel

- (NSString *)description {
    return [self yy_modelDescription];
}

- (id)copyWithZone:(NSZone *)zone {
    return [self yy_modelCopy];
}

- (id)mutableCopyWithZone:(NSZone *)zone{
    return [self yy_modelCopy];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [self yy_modelEncodeWithCoder:aCoder];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    return [self yy_modelInitWithCoder:aDecoder];
}

/// 解析对应的数据模型
- (void)configModel:(WXNetworkRequest *)requestApi
       responseDict:(NSDictionary *)responseDict
{
    if (![responseDict isKindOfClass:[NSDictionary class]]) return;
    NSDictionary *parseDict = requestApi.parseModelMap;
    if (![parseDict isKindOfClass:[NSDictionary class]] || parseDict.count != 1) return;
    
    NSString *parseModelKey = parseDict.allKeys.firstObject;
    Class parseModelClass = parseDict.allValues.firstObject;
    
    if ([parseModelKey isKindOfClass:[NSString class]]
        && parseModelKey.length > 0 && parseModelClass) {
        NSObject *matchModelDict = nil;
        
        //1.如果包含点(.)连接, 则采用KeyPath模式寻找匹配解析模型的关键key
        if ([parseModelKey containsString:@"."]) {
            id lastMatchValue = responseDict;
            for (NSString *tmpKey in [parseModelKey componentsSeparatedByString:@"."]) {
                if (lastMatchValue == nil) {
                    return;
                } else {
                    lastMatchValue = [self findParseDict:tmpKey respValue:lastMatchValue];
                }
            }
            matchModelDict = lastMatchValue;
            
        } else { //2.采用直接查找匹配请求成功标识
            matchModelDict = responseDict[parseModelKey];
        }
        
        if ([matchModelDict isKindOfClass:[NSDictionary class]]) {
            self.parseModel = [parseModelClass yy_modelWithJSON:matchModelDict];
            
        } else if ([matchModelDict isKindOfClass:[NSArray class]]) {
            self.parseModel = [NSArray yy_modelArrayWithClass:parseModelClass json:matchModelDict];
        }
    }
}

///寻找最合适的解析: 字典/数组
- (id)findParseDict:(NSString *)modelKey respValue:(NSDictionary *)lastValueDict {
    if (![modelKey isKindOfClass:[NSString class]] ||
        ![lastValueDict isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    __block id dictValue = nil;
    [lastValueDict enumerateKeysAndObjectsUsingBlock:^(id _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if ([modelKey isEqualToString:key]) {
            dictValue = obj;
            *stop = YES;
        }
    }];
    return dictValue;
}

@end

#pragma mark - =====================<WXNetworkRequest>=====================================


static NSMutableDictionary<NSString *, NSDictionary *> *         _globleRequestList;
static NSMutableDictionary<NSString *, NSURLSessionDataTask *> * _globleTasksList;

@interface WXNetworkRequest ()
@property (nonatomic, copy) NSString                *cacheKey;
@property (nonatomic, copy) NSString                *apiUniquelyIp;
@property (nonatomic, assign) NSInteger             retryCount;
@property (nonatomic, assign) double                requestDuration;
@property (nonatomic, weak) id<WXNetworkDelegate>   responseDelegate;
@property (nonatomic, strong) NSString              *parmatersJsonString;
@property (nonatomic, strong) NSString              *managerRequestKey;
@property (nonatomic, copy) WXNetworkResponseBlock  configResponseCallback;
@end

@implementation WXNetworkRequest

+ (void)initialize {
    _globleRequestList = [NSMutableDictionary dictionary];
    _globleTasksList   = [NSMutableDictionary dictionary];
}

#pragma mark - <StartNetwork>

/*
 * 网络请求方法
 * @parm networkDelegate 请求成功失败回调代理
 */
- (NSURLSessionDataTask *)startRequestWithDelegate:(id<WXNetworkDelegate>)responseDelegate {
    self.responseDelegate = responseDelegate;
    return [self startRequest:self.configResponseCallback ?: self.configResponseDelegateCallback];
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
- (NSURLSessionDataTask *)startRequest:(WXNetworkResponseBlock)responseBlock {
    if (![self isValidRequestURL:self.requestUrl]) {
        WXNetworkLog(@"\n❌❌❌无效的请求地址= %@", self.requestUrl);
        [self configResponseBlock:responseBlock responseObj:nil];
        return nil;
    }
    if ([self checkCurrentTaskIsDoing]) {
        [self.class cancelRequestsList:@[self]];
    }
    void(^networkBlock)(id rsp) = ^(id responseObj) {
        [self configResponseBlock:responseBlock responseObj:responseObj];
    };
    if ([self checkRequestInCache]) {
        [self readRequestCacheWithBlock:networkBlock];
    }
    [self handleMulticenter:WXNetworkRequestWillStart responseModel:nil];
    NSURLSessionDataTask *task = [self baseRequestBlock:networkBlock failureBlock:networkBlock];
    [self insertCurrentRequestToRequestTableList:task];
    if (![WXNetworkConfig sharedInstance].closeUrlResponsePrintfLog) {
        if (self.retryCount == 0) {
            WXNetworkLog(@"\n👉👉👉已发出网络请求= %@", self.requestUrl);
        } else {
            WXNetworkLog(@"\n👉👉👉请求失败,第【 %@ 】次尝试重新请求=", self.retryCount, self.requestUrl);
        }
    }
    return task;
}

#pragma mark - <DealWithResponse>

- (void)configResponseBlock:(WXNetworkResponseBlock)responseBlock responseObj:(id)responseObj {
    
    void (^handleResponseFn)(id responseObj) = ^(id responseObj) {
        WXResponseModel *responseModel = [self configResponseModel:responseObj];
        if (responseBlock) {
            responseBlock(responseModel);
        }
        [self handleMulticenter:WXNetworkRequestDidCompletion responseModel:responseModel];
    };
    
    if (self.retryCount < self.retryCountWhenFailure &&
        [responseObj isKindOfClass:[NSError class]] &&
        ![[((NSError *)responseObj) localizedDescription] isEqualToString:@"cancelled"] ) {
        
        // cancelled code=-999: is manual cancelled
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.retryCount ++;
            handleResponseFn(responseObj);
            [self startRequest:responseBlock];
        });
    } else {
        handleResponseFn(responseObj);
    }
}

- (NSString *)configFailMessage {
    NSString *defaultTip = KWXRequestFailueTipMessage;
    NSDictionary *messageDefaultInfo = [WXNetworkConfig sharedInstance].messageTipKeyAndFailInfo;
    if ([messageDefaultInfo isKindOfClass:[NSDictionary class]]) {
        NSString *toastText = messageDefaultInfo.allValues.firstObject;
        if (![toastText isKindOfClass:[NSString class]] || toastText.length == 0) {
            defaultTip = toastText;
        }
    }
    return defaultTip;
}

- (WXResponseModel *)configResponseModel:(id)responseObj {
    WXResponseModel *rspModel  = [[WXResponseModel alloc] init];
    rspModel.duration          = [self getCurrentTimestamp] - self.requestDuration;
    rspModel.apiUniquelyIp     = self.apiUniquelyIp;
    rspModel.responseObject    = responseObj;
    
    rspModel.originalRequest   = self.requestDataTask.originalRequest;
    if ([self.requestDataTask.response isKindOfClass:[NSHTTPURLResponse class]]) {
        rspModel.urlResponse   = (NSHTTPURLResponse *)(self.requestDataTask.response);
    }
    
    WXNetworkConfig *config    = [WXNetworkConfig sharedInstance];
    NSString *messageKey = nil;
    NSString *messageValue = KWXRequestFailueTipMessage;
    if (config.messageTipKeyAndFailInfo.count == 1) {
        messageKey = config.messageTipKeyAndFailInfo.allKeys.firstObject;
        messageValue = config.messageTipKeyAndFailInfo.allValues.firstObject;
    }
    NSInteger defaultErrorCode = -444;
    
    if (!responseObj || [responseObj isKindOfClass:[NSError class]]) {
        if ([responseObj isKindOfClass:[NSError class]]) {
            rspModel.error         = (NSError *)responseObj;
            rspModel.responseMsg   = messageValue;
            rspModel.responseCode  = rspModel.error.code;
        } else {
            rspModel.error         = [NSError errorWithDomain:messageValue code:defaultErrorCode userInfo:nil];;
            rspModel.responseMsg   = messageValue;
            rspModel.responseCode  = defaultErrorCode;
        }
    } else {
        NSString *statusKey = nil;
        NSString *successValue = nil;
        if (self.successStatusMap.count == 1) {
            statusKey = self.successStatusMap.allKeys.firstObject;
            successValue = self.successStatusMap.allValues.firstObject;
            
        } else if (config.successStatusMap.count == 1) {
            statusKey = config.successStatusMap.allKeys.firstObject;
            successValue = config.successStatusMap.allValues.firstObject;
        }
        
        NSDictionary *responseDict  = [self packagingResponseObj:responseObj responseModel:rspModel];
        rspModel.responseDict       = responseDict;
        rspModel.responseCode       = defaultErrorCode;
        
        //1.如果包含点(.)连接,则采用KeyPath模式匹配查找请求成功标识
        if ([statusKey containsString:@"."]) {
            id lastMatchValue = responseDict;
            for (NSString *tmpKey in [statusKey componentsSeparatedByString:@"."]) {
                if (lastMatchValue == nil) {
                    break;
                } else { //寻找匹配请求成功的关键字典
                    lastMatchValue = [self findAppositeDict:tmpKey respValue:lastMatchValue];
                }
            }
            //寻找匹配请求成功的关键key
            if (lastMatchValue) {
                NSString *findMatchValue = [NSString stringWithFormat:@"%@", lastMatchValue];
                rspModel.isSuccess       = [findMatchValue isEqualToString:successValue];
                rspModel.responseCode    = [findMatchValue integerValue];
            }
        } else { //2.采用直接查找匹配请求成功标识
            NSString *responseCode       = [responseDict objectForKey:statusKey];
            rspModel.isSuccess           = [responseCode isEqualToString:successValue];
            if (responseCode) {
                rspModel.responseCode    = [responseCode integerValue];
            }
        }
        NSString *msg = responseDict[messageKey];
        if ([msg isKindOfClass:[NSString class]]) {
            rspModel.responseMsg = msg;
        }
        if (rspModel.isSuccess) {
            //解析对应的数据模型
            [rspModel configModel:self responseDict:responseDict];
        } else {
            rspModel.responseMsg = rspModel.responseMsg ?: messageValue;
            rspModel.error       = [NSError errorWithDomain:rspModel.responseMsg
                                                       code:rspModel.responseCode
                                                   userInfo:responseDict];
        }
    }
    if (!rspModel.isCacheData) {
        [self handleMulticenter:WXNetworkRequestWillStop responseModel:rspModel];
    }
    return rspModel;
}

- (id)findAppositeDict:(NSString *)matchKey respValue:(NSDictionary *)respValue {
    if (![matchKey isKindOfClass:[NSString class]] ||
        ![respValue isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    __block id dictValue = nil;
    [respValue enumerateKeysAndObjectsUsingBlock:^(id _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if ([matchKey isEqualToString:key]) {
            dictValue = obj;
            *stop = YES;
        }
    }];
    return dictValue;
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
    } else if ([responseObj isKindOfClass:[NSString class]]) {
        NSData *data = [(NSString *)responseObj dataUsingEncoding:NSUTF8StringEncoding];
        NSError *parseError = nil; BOOL hasFail = NO;
        if ([data isKindOfClass:[NSData class]]) {
            NSDictionary *toDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&parseError];
            if ([toDict isKindOfClass:[NSDictionary class]]) {
                [responseDcit addEntriesFromDictionary:toDict];
            } else {
                hasFail = YES;
            }
        }
        if (parseError || hasFail) {
            responseDcit[@"response"] = responseObj;
        }
    } else if (responseObj != nil) {
        responseDcit[@"response"] = responseObj;
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
            [self printfResponseLog:responseModel];
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
            [self checkPostNotification:responseModel];
            [WXNetworkPlugin uploadNetworkResponseJson:responseModel request:self];
            
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
            if (responseModel.isCacheData) {
                [self printfResponseLog:responseModel];
            } else {
                [self saveResponseObjToCache:responseModel];
            }
        }
            break;
        default:
            break;
    }
}

- (void)printfResponseLog:(WXResponseModel *)responseModel {
    if ([WXNetworkConfig sharedInstance].closeUrlResponsePrintfLog) return;
#if DEBUG
    NSString *logHeader = [WXNetworkPlugin appendingPrintfLogHeader:responseModel request:self];
    NSString *logFooter = [WXNetworkPlugin appendingPrintfLogFooter:responseModel];
    WXNetworkLog(@"%@", [NSString stringWithFormat:@"%@%@", logHeader, logFooter]);
#endif
}

- (NSString *)apiUniquelyIp {
    if (!_apiUniquelyIp) {
        _apiUniquelyIp = [NSString stringWithFormat:@"%p", self];
    }
    return _apiUniquelyIp;
}

#pragma mark - <Notification>

- (void)checkPostNotification:(WXResponseModel *)responseModel {
    NSDictionary *notifyDict = [WXNetworkConfig sharedInstance].errorCodeNotifyDict;
    if (![notifyDict isKindOfClass:[NSDictionary class]]) return;
    
    for (NSString *notifyName in notifyDict.allKeys) {
        if (![notifyName isKindOfClass:[NSString class]]) continue;
        
        NSNumber *notifyNumber = notifyDict[notifyName];
        if (![notifyNumber isKindOfClass:[NSNumber class]]) continue;
        
        if (responseModel.responseCode == notifyNumber.integerValue) {
            [[NSNotificationCenter defaultCenter] postNotificationName:notifyName object:responseModel];
        }
    }
}

#pragma mark - <verifyUrl>

- (BOOL)isValidRequestURL:(NSString *)requestUrl {
    return ([requestUrl isKindOfClass:[NSString class]] && [NSURL URLWithString:requestUrl]);
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
            _cacheKey = [WXNetworkPlugin MD5String:self.managerRequestKey];
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

- (BOOL)checkCurrentTaskIsDoing {
    NSString *requestKey = self.managerRequestKey;
    NSDictionary *parmaters = _globleRequestList[requestKey];
    if (![parmaters isKindOfClass:[NSDictionary class]]) return NO;
    
    if ([_globleRequestList.allKeys containsObject:requestKey]
        && parmaters.count == 0 && !self.finalParameters) {
        return YES;
    }
    return [parmaters isEqualToDictionary:self.finalParameters];
}

- (void)insertCurrentRequestToRequestTableList:(NSURLSessionDataTask *)sessionDataTask {
    if (!(_globleRequestList && _globleTasksList) || !sessionDataTask)return ;
    
    NSString *requestKey = self.managerRequestKey;
    if ([self.requestUrl isKindOfClass:[NSString class]]) {
        _globleRequestList[requestKey] = self.finalParameters ?: @{};
        
        if ([sessionDataTask isKindOfClass:[NSURLSessionDataTask class]]) {
            _globleTasksList[requestKey] = sessionDataTask;
        }
    }
}

- (void)removeCompleteRequestFromGlobleRequestList {
    NSString *requestKey = self.managerRequestKey;
    [_globleRequestList removeObjectForKey:requestKey];
    [_globleTasksList removeObjectForKey:requestKey];
}

+ (void)cancelGlobleAllRequestMangerTask {
    [_globleTasksList enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSURLSessionDataTask * _Nonnull task, BOOL * _Nonnull stop) {
        if ([task isKindOfClass:[NSURLSessionDataTask class]]) {
            [task cancel];
        }
    }];
    [_globleRequestList removeAllObjects];
    [_globleTasksList removeAllObjects];
}

+ (void)cancelRequestsList:(NSArray<WXNetworkRequest *> *)requestList {
    if (!_globleRequestList || !_globleTasksList)return ;
    [requestList enumerateObjectsUsingBlock:^(WXNetworkRequest * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [_globleRequestList removeObjectForKey:obj.managerRequestKey];
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
    dispatch_async(dispatch_get_main_queue(), ^{
        if (show) {
            [WXNetworkHUD showLoadingToView:self.loadingSuperView];
        } else {
            [WXNetworkHUD hideLoadingFromView:self.loadingSuperView];
        }
    });
}

- (double)getCurrentTimestamp {
    NSDate *dat = [NSDate dateWithTimeIntervalSinceNow:0];
    NSTimeInterval timeInterval = [dat timeIntervalSince1970] * 1000;
    return timeInterval;
}

- (NSString *)parmatersJsonString {
    if (self.finalParameters) {
        if (!_parmatersJsonString) {
            _parmatersJsonString = [self.finalParameters yy_modelToJSONString];;
        }
        return _parmatersJsonString;
    }
    return @"";
}

@end


#pragma mark - =====================<WXNetworkBatchRequest>=====================================

@interface WXNetworkBatchRequest ()
@property (nonatomic, weak) id<WXNetworkBatchDelegate>  responseBatchDelegate;
@property (nonatomic, copy) WXNetworkBatchBlock         responseBatchBlock;
@property (nonatomic, copy) WXNetworkResponseBlock      configBatchDelegateCallback;
@property (nonatomic, assign) NSInteger                 requestCount;
@property(nonatomic, assign, readwrite) BOOL            isAllSuccess;
@property (nonatomic, assign) BOOL                      hasMarkBatchFailure;
@property (nonatomic, assign) BOOL                      waitAllDone;
@property (nonatomic, strong) NSMutableDictionary<NSString *, WXResponseModel *> *responseInfoDict;
@property (nonatomic, strong) WXNetworkBatchRequest     *batchRequest;
@property (nonatomic, strong, readwrite) NSMutableArray *responseDataArray;
@end

@implementation WXNetworkBatchRequest


/** 根据指定的请求获取响应数据 */
- (WXResponseModel *)responseForRequest:(WXNetworkRequest *)request {
    if (![request isKindOfClass:[WXNetworkRequest class]]) return nil;
    WXResponseModel *rspModel = self.responseInfoDict[request.apiUniquelyIp];
    return rspModel;
}

/** 取消所有请求 */
- (void)cancelAllRequest {
    [WXNetworkRequest cancelRequestsList:self.requestArray];
}

- (void)setRequestArray:(NSArray<WXNetworkRequest *> *)requestArray {
    BOOL isApiArray = [requestArray isKindOfClass:[NSArray class]];
    if (!isApiArray) {
        NSAssert(isApiArray, KWXRequestRequestArrayObjAssert);
        return ;
    }
    for (WXNetworkRequest *requestApi in requestArray) {
        BOOL isRequestApi = [requestApi isKindOfClass:[WXNetworkRequest class]];
        if (!isRequestApi) {
            NSAssert(isRequestApi, KWXRequestRequestArrayAssert);
            return;
        }
    }
    _requestArray = [requestArray copy];
    _requestCount = requestArray.count;
}

/**
 批量网络请求: (代理回调方式)

 @param responseBlock 请求全部完成后的响应block回调
 @param batchRequestArr 请求WXNetworkRequest对象数组
 @param waitAllDone 是否等待全部请求完成才回调, 否则回调多次
 */
+ (void)startRequest:(WXNetworkBatchBlock)responseBlock
       batchRequests:(NSArray<WXNetworkRequest *> *)batchRequestArr
         waitAllDone:(BOOL)waitAllDone {
    WXNetworkBatchRequest *batchRequest = [[WXNetworkBatchRequest alloc] init];
    batchRequest.requestArray = batchRequestArr;
    [batchRequest startRequest:responseBlock
                   waitAllDone:waitAllDone];
}

/**
 *批量网络请求
 
 @param responseBlock 请求完成响应block回调
 @param waitAllDone 是否等待全部请求完成
 */
- (void)startRequest:(WXNetworkBatchBlock)responseBlock
         waitAllDone:(BOOL)waitAllDone {
    for (WXNetworkRequest *requestApi in self.requestArray) {
        BOOL isRequestApi = [requestApi isKindOfClass:[WXNetworkRequest class]];
        if (!isRequestApi) {
            NSAssert(isRequestApi, KWXRequestRequestArrayAssert);
            return;
        }
    }
    self.batchRequest = self;
    self.responseBatchBlock = responseBlock;
    self.waitAllDone = waitAllDone;
    self.responseBatchDelegate = nil;
    self.requestCount = 0;
    self.isAllSuccess = NO;
    self.hasMarkBatchFailure = NO;
    [self.responseDataArray removeAllObjects];
    for (WXNetworkRequest *requestApi in self.requestArray) {
        [requestApi startRequest:self.configBatchDelegateCallback];
    }
}

/**
 批量网络请求
 
 @param responseDelegate 请求完成响应代理回调
 @param waitAllDone 是否等待全部请求完成
 */
- (void)startRequestWithDelegate:(id<WXNetworkBatchDelegate>)responseDelegate
                     waitAllDone:(BOOL)waitAllDone
{
    for (WXNetworkRequest *requestApi in self.requestArray) {
        BOOL isRequestApi = [requestApi isKindOfClass:[WXNetworkRequest class]];
        if (!isRequestApi) {
            NSAssert(isRequestApi, KWXRequestRequestArrayAssert);
            return;
        }
    }
    self.batchRequest = self;
    self.responseBatchDelegate = responseDelegate;
    self.waitAllDone = waitAllDone;
    self.responseBatchBlock = nil;
    [self.responseDataArray removeAllObjects];
    self.requestCount = 0;
    self.isAllSuccess = NO;
    self.hasMarkBatchFailure = NO;
    for (WXNetworkRequest *serverApi in self.requestArray) {
        serverApi.configResponseCallback = self.configBatchDelegateCallback;
        [serverApi startRequestWithDelegate:responseDelegate];
    }
}

- (WXNetworkResponseBlock)configBatchDelegateCallback {
    if (!_configBatchDelegateCallback) {
        __weak typeof(self) weakSelf = self;
        _configBatchDelegateCallback = ^(WXResponseModel *responseModel) {
            if (!responseModel.isSuccess) {
                weakSelf.hasMarkBatchFailure = YES;
            }
            if (weakSelf.waitAllDone) {
                [weakSelf dealwithResponseHandle:responseModel];
            } else {
                weakSelf.isAllSuccess = !weakSelf.hasMarkBatchFailure;
                [weakSelf.responseDataArray addObject:responseModel];
                // 请求最终回调
                [weakSelf callbackResponseData];
            }
        };
    }
    return _configBatchDelegateCallback;
}

- (void)dealwithResponseHandle:(WXResponseModel *)responseModel {
    @synchronized (self) {
        if (!responseModel.isCacheData) {
            self.requestCount--;
        }
        self.responseInfoDict[responseModel.apiUniquelyIp] = responseModel;
        
        if (self.requestCount <= 0) {
            self.isAllSuccess = !self.hasMarkBatchFailure;
            NSMutableArray *responseArray = [NSMutableArray array];
            for (NSInteger i=0; i<self.requestArray.count; i++) {
                WXNetworkRequest *requestApi = self.requestArray[i];
                id responseObj = self.responseInfoDict[requestApi.apiUniquelyIp];
                if (responseObj) {
                    [responseArray addObject:responseObj];
                }
            }
            self.responseDataArray = responseArray;
            // 请求最终回调
            [self callbackResponseData];
        }
    }
}

///请求最终回调
- (void)callbackResponseData {
    if (self.responseBatchBlock) {
        self.responseBatchBlock(self);
        
    } else if (self.responseBatchDelegate &&
               [self.responseBatchDelegate respondsToSelector:@selector(wxBatchResponseWithRequest:)]) {
        [self.responseBatchDelegate wxBatchResponseWithRequest:self];
    }
    self.batchRequest = nil;
}

- (NSMutableDictionary *)responseInfoDict {
    if (!_responseInfoDict) {
        _responseInfoDict = [NSMutableDictionary dictionary];
    }
    return _responseInfoDict;
}

- (NSMutableArray<WXResponseModel *> *)responseDataArray {
    if (!_responseDataArray) {
        _responseDataArray = [NSMutableArray array];
    }
    return _responseDataArray;
}

@end
