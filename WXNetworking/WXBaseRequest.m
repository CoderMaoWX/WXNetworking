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
#import <AFNetworking/AFNetworking.h>

@interface WXBaseRequest ()
@property (nonatomic, strong, readwrite) NSDictionary           *finalParameters;
@property (nonatomic, strong, readwrite) NSURLSessionDataTask   *requestDataTask;
@property (nonatomic, strong, readwrite) NSURLSession           *urlSession;
@end

@implementation WXBaseRequest

#pragma mark - <AFN-SessionManager>

- (AFHTTPSessionManager*)setupHttpSessionManager {
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
    
    // AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    AFHTTPSessionManager *manager = [[AFHTTPSessionManager alloc] initWithSessionConfiguration:sessionConfig];
    
    // 自定义请求序列化对象
    if ([self.requestSerializer isKindOfClass:[AFHTTPRequestSerializer class]]) {
        manager.requestSerializer = self.requestSerializer;
    } else {
        manager.requestSerializer = [AFJSONRequestSerializer serializer];
        manager.requestSerializer.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        manager.requestSerializer.timeoutInterval = self.timeOut ? : 30;//默认请求超时时间30秒
    }
    
    // 添加自定义请求头信息
    NSDictionary *headerDict = self.requestHeaderDict;
    if ([headerDict isKindOfClass:[NSDictionary class]]) {
        for (NSString *headerField in headerDict.allKeys) {
            if (![headerField isKindOfClass:[NSString class]]) continue;
            
            NSString *headerValue = headerDict[headerField];
            if (![headerValue isKindOfClass:[NSString class]]) continue;
            [manager.requestSerializer setValue:headerValue forHTTPHeaderField:headerField];
        }
    }
    // 自定义响应序列化对象
    if ([self.responseSerializer isKindOfClass:[AFHTTPResponseSerializer class]]) {
        manager.responseSerializer = self.responseSerializer;
    } else {
        manager.responseSerializer = [AFJSONResponseSerializer serializer];
    }
    
    // 添加额外响应解析类型
    NSMutableSet *acceptTypesSet = [NSMutableSet setWithSet:manager.responseSerializer.acceptableContentTypes];
    [acceptTypesSet addObjectsFromArray:@[@"application/zip", @"text/html", @"text/plain"]];
    manager.responseSerializer.acceptableContentTypes = acceptTypesSet;
    return manager;
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
- (NSURLSessionDataTask *)requestWithBlock:(WXNetworkSuccessBlock)successBlock
                              failureBlock:(WXNetworkFailureBlcok)failureBlock
{
    AFHTTPSessionManager *manager = [self setupHttpSessionManager];
    NSError *requestError = nil;
    NSString *method = [self.class configRequestType][@(self.requestType)];
    NSMutableURLRequest *request = nil;
    
    if (self.requestType == WXNetworkRequestTypePOST && self.uploadFileDataArr.count>0) {
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
        [manager.session finishTasksAndInvalidate];
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
    return @{@(WXNetworkRequestTypePOST)   : @"POST",
             @(WXNetworkRequestTypeGET)    : @"GET",
             @(WXNetworkRequestTypeHEAD)   : @"HEAD",
             @(WXNetworkRequestTypePUT)    : @"PUT",
             @(WXNetworkRequestTypeDELETE) : @"DELETE",
             @(WXNetworkRequestTypePATCH)  : @"PATCH" };
}

#pragma mark - <ConfiguploadImage>

- (WXNetworkUploadDataBlock)uploadConfigDataBaseBlock {
    if (!_uploadConfigDataBlock) {
        __weak typeof(self) weakSelf = self;
        _uploadConfigDataBlock = ^(id<AFMultipartFormData> formData){
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setTimeZone:[NSTimeZone localTimeZone]];
            [formatter setDateFormat:KWXRequestAbsoluteDateFormatterKey];
            
            for (NSData *fileData in weakSelf.uploadFileDataArr) {
                if (![fileData isKindOfClass:[NSData class]]) continue;
                NSArray *typeArray = [WXNetworkPlugin typeForImageData:fileData];
                NSString *locationString = [formatter stringFromDate:[NSDate date]];
                NSString *fileName = [locationString stringByAppendingFormat:@".%@", typeArray.lastObject];
                [formData appendPartWithFileData:fileData
                                            name:@"image"
                                        fileName:fileName
                                        mimeType:typeArray.firstObject];
            }
        };
    }
    return _uploadConfigDataBlock;
}

@end
