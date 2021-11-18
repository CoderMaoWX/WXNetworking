//
//  WXBaseRequest.m
//  WXNetworking
//
//  Created by MaoWX on 2020/08/16.
//  Copyright © 2020 WX. All rights reserved.
//

#import "WXBaseRequest.h"
#import "WXNetworkPlugin.h"
#import "WXNetworkConfig.h"
#import <objc/runtime.h>

///使用全局静态变量避免每次创建
static AFHTTPSessionManager *_sessionManager;

@interface WXBaseRequest ()
@property (nonatomic, strong, readwrite) NSDictionary           *finalParameters;
@property (nonatomic, strong, readwrite) NSURLSessionDataTask   *requestDataTask;
@property (nonatomic, strong, readwrite) NSURLSession           *urlSession;
@end

@implementation WXBaseRequest

#pragma mark - <AFN-SessionManager>

+ (void)initialize {
    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    Class class = [WXNetworkConfig sharedInstance].urlSessionProtocolClasses;
    if (class) {
        sessionConfig.protocolClasses = @[class];
    }
    //多路径TCP服务，提供Wi-Fi和蜂窝之间的无缝切换，以保持连接。
    if (@available(iOS 11.0, *)) {
        if ([WXNetworkConfig sharedInstance].openMultipathService) {
            sessionConfig.multipathServiceType = NSURLSessionMultipathServiceTypeHandover;
        }
    }
    _sessionManager = [[AFHTTPSessionManager alloc] initWithSessionConfiguration:sessionConfig];
}

- (AFHTTPSessionManager *)setupHttpSessionManager {
    // 自定义请求序列化对象
    if ([self.requestSerializer isKindOfClass:[AFHTTPRequestSerializer class]]) {
        _sessionManager.requestSerializer = self.requestSerializer;
    } else {
        _sessionManager.requestSerializer = [AFJSONRequestSerializer serializer];
        _sessionManager.requestSerializer.timeoutInterval = self.timeOut ? : 30;//默认请求超时时间30秒
    }
    _sessionManager.requestSerializer.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    
    // 添加自定义请求头信息
    NSDictionary *headerDict = self.requestHeaderDict;
    if ([headerDict isKindOfClass:[NSDictionary class]]) {
        for (NSString *headerField in headerDict.allKeys) {
            if (![headerField isKindOfClass:[NSString class]]) continue;
            NSString *headerValue = headerDict[headerField];
            if (![headerValue isKindOfClass:[NSString class]]) continue;
            [_sessionManager.requestSerializer setValue:headerValue forHTTPHeaderField:headerField];
        }
    }
    // 自定义响应序列化对象
    if ([self.responseSerializer isKindOfClass:[AFHTTPResponseSerializer class]]) {
        _sessionManager.responseSerializer = self.responseSerializer;
    } else {
        _sessionManager.responseSerializer = [AFJSONResponseSerializer serializer];
    }
    
    // 添加额外响应解析类型
    NSMutableSet *acceptTypesSet = [NSMutableSet setWithSet:_sessionManager.responseSerializer.acceptableContentTypes];
    [acceptTypesSet addObjectsFromArray:@[@"application/zip", @"text/html", @"text/plain"]];
    _sessionManager.responseSerializer.acceptableContentTypes = acceptTypesSet;
    return _sessionManager;
}

- (NSDictionary *)finalParameters {
    if (!_finalParameters) {
        _finalParameters = self.parameters;
        
        BOOL implementTransform = [((id<WXPackParameters>)self).class  instancesRespondToSelector:@selector(parametersWillTransformFromOriginParamete:)];
        if (implementTransform) {
            NSDictionary *finalPara = [((id<WXPackParameters>)self) parametersWillTransformFromOriginParamete:self.parameters];
            if ([finalPara isKindOfClass:[NSDictionary class]]) {
                _finalParameters = finalPara;
            }
        }
    }
    return _finalParameters;
}

#pragma mark - <Request Methods>

/// 根据不同的type 走不同类型的网络请求
- (NSURLSessionDataTask *)baseRequestBlock:(WXNetworkSuccessBlock)successBlock
                              failureBlock:(WXNetworkFailureBlcok)failureBlock
{
    AFHTTPSessionManager *manager = [self setupHttpSessionManager];
    NSError *requestError = nil;
    NSString *method = [self.class configRequestType][@(self.requestType)];
    NSMutableURLRequest *request = nil;
    
    if (self.requestType == WXRequestMethod_POST && self.uploadFileDataArr.count>0) {
        request = [manager.requestSerializer multipartFormRequestWithMethod:method
                                            URLString:self.requestUrl
                                           parameters:self.finalParameters
                            constructingBodyWithBlock:self.uploadConfigDataBlock ?: self.uploadConfigDataBaseBlock
                                                error:&requestError];
    } else {
        request = [manager.requestSerializer requestWithMethod:method
                                                     URLString:self.requestUrl
                                                    parameters:self.finalParameters
                                                         error:&requestError];
    }
    if (requestError) {
        if (failureBlock) {
            failureBlock(requestError);
        }
        return nil;
    }
    void (^completionHandler)(NSURLResponse *, id, NSError *) = ^(NSURLResponse *response, id responseObject, NSError *error){
        if (error) {
            if (failureBlock) {
                failureBlock(error);
            }
        } else if (successBlock) {
            successBlock(responseObject);
        }
    };
    NSURLSessionDataTask *dataTask = [manager dataTaskWithRequest:request
                                                   uploadProgress:self.uploadProgressBlock
                                                 downloadProgress:self.downloadProgressBlock
                                                completionHandler:completionHandler];
    [dataTask resume];
    self.requestDataTask = dataTask;
    self.urlSession = manager.session;
    return dataTask;
}

+ (NSDictionary *)configRequestType {
    return @{
        @(WXRequestMethod_POST)   : @"POST",
        @(WXRequestMethod_GET)    : @"GET",
        @(WXRequestMethod_HEAD)   : @"HEAD",
        @(WXRequestMethod_PUT)    : @"PUT",
        @(WXRequestMethod_DELETE) : @"DELETE",
        @(WXRequestMethod_PATCH)  : @"PATCH",
    };
}

#pragma mark - <ConfiguploadImage>

- (WXNetworkUploadDataBlock)uploadConfigDataBaseBlock {
    if (!_uploadConfigDataBlock) {
        __weak typeof(self) weakSelf = self;
        _uploadConfigDataBlock = ^(id<AFMultipartFormData> formData){

            for (NSInteger i=0; i<weakSelf.uploadFileDataArr.count; i++) {
                NSData *fileData = weakSelf.uploadFileDataArr[i];
                if (![fileData isKindOfClass:[NSData class]]) continue;
                
                NSArray *typeArray = [WXNetworkPlugin typeForFileData:fileData];
                NSString *name = [typeArray.firstObject stringByDeletingLastPathComponent];
                NSString *fileName = [NSString stringWithFormat:@"%@-%d.%@", name, i, typeArray.lastObject];
                
                [formData appendPartWithFileData:fileData
                                            name:name
                                        fileName:fileName
                                        mimeType:typeArray.firstObject];
            }
        };
    }
    return _uploadConfigDataBlock;
}

@end

//=====================================禁止网络代理抓包=====================================

@implementation NSURLSession (WXHttpProxy)

+(void)wx_swizzingMethod:(Class)cls orgSel:(SEL)orgSel swiSel:(SEL)swiSel {
    Method orgMethod = class_getClassMethod(cls, orgSel);
    Method swiMethod = class_getClassMethod(cls, swiSel);
    method_exchangeImplementations(orgMethod, swiMethod);
}

+(void)load {
    [super load];
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [NSURLSession class];
        [self wx_swizzingMethod:class
                         orgSel:NSSelectorFromString(@"sessionWithConfiguration:")
                         swiSel:NSSelectorFromString(@"wx_sessionWithConfiguration:")];
        
        [self wx_swizzingMethod:class
                         orgSel:NSSelectorFromString(@"sessionWithConfiguration:delegate:delegateQueue:")
                         swiSel:NSSelectorFromString(@"wx_sessionWithConfiguration:delegate:delegateQueue:")];
    });
}

+(NSURLSession *)wx_sessionWithConfiguration:(NSURLSessionConfiguration *)configuration
                                    delegate:(nullable id<NSURLSessionDelegate>)delegate
                               delegateQueue:(nullable NSOperationQueue *)queue {
    if (!configuration){
        configuration = [[NSURLSessionConfiguration alloc] init];
    }
    BOOL isForbid = [WXNetworkConfig sharedInstance].forbidProxyCaught;
    if(isForbid){
        configuration.connectionProxyDictionary = @{};
    }
    return [self wx_sessionWithConfiguration:configuration
                                    delegate:delegate
                               delegateQueue:queue];
}

+(NSURLSession *)wx_sessionWithConfiguration:(NSURLSessionConfiguration *)configuration {
    BOOL isForbid = [WXNetworkConfig sharedInstance].forbidProxyCaught;
    if (configuration && isForbid){
        configuration.connectionProxyDictionary = @{};
    }
    return [self wx_sessionWithConfiguration:configuration];
}

@end

