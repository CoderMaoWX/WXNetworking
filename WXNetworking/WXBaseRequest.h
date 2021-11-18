//
//  WXBaseRequest.h
//  WXNetworking
//
//  Created by MaoWX on 2020/08/16.
//  Copyright © 2020 WX. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AFNetworking/AFNetworking.h>

@class WXResponseModel, WXNetworkBatchRequest;

///  HTTP Request method
typedef NS_ENUM(NSInteger, WXRequestMethod) {
    WXRequestMethod_POST = 0,
    WXRequestMethod_GET,
    WXRequestMethod_HEAD,
    WXRequestMethod_PUT,
    WXRequestMethod_DELETE,
    WXRequestMethod_PATCH,
};

typedef void(^WXNetworkResponseBlock) (WXResponseModel *responseModel);
typedef void(^WXNetworkBatchBlock) (WXNetworkBatchRequest *batchRequest);
typedef void(^WXNetworkSuccessBlock) (id responseObject);
typedef void(^WXNetworkFailureBlcok) (NSError *error);
typedef void(^WXNetworkProgressBlock) (NSProgress *progress);
typedef void(^WXNetworkUploadDataBlock) (id<AFMultipartFormData> formData);


@protocol WXPackParameters <NSObject>
@optional
/**
 外部可包装最终网络底层最终请求参数

 @param parameters 默认外部传进来的<parameters>
 @return 网络底层最终的请求参数
 */
- (NSDictionary *)parametersWillTransformFromOriginParamete:(NSDictionary *)parameters;

@end


@interface WXBaseRequest : NSObject

/** 请求类型 */
@property (nonatomic, assign) WXRequestMethod          requestType;

/** 请求地址 */
@property (nonatomic, copy)   NSString                 *requestUrl;

/** 请求参数 */
@property (nonatomic, strong) NSDictionary             *parameters;

/** 请求超时，默认30s */
@property (nonatomic, assign) NSInteger                timeOut;

/** 请求自定义头信息 */
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *requestHeaderDict;

/** 请求序列化对象 */
@property (nonatomic, strong) AFHTTPRequestSerializer  *requestSerializer;

/** 响应序列化对象 */
@property (nonatomic, strong) AFHTTPResponseSerializer *responseSerializer;

/** 上传文件Data数组 */
@property (nonatomic, strong) NSArray<NSData *>        *uploadFileDataArr;

/** 上传时包装的数据Data对象 */
@property (nonatomic, copy) WXNetworkUploadDataBlock   uploadConfigDataBlock;

/** 监听上传进度 */
@property (nonatomic, copy) WXNetworkProgressBlock     uploadProgressBlock;

/** 监听下载进度 */
@property (nonatomic, copy) WXNetworkProgressBlock     downloadProgressBlock;

/** 底层最终的请求参数 (页面上可实现<WXPackParameters>协议来实现重新包装请求参数) */
@property (nonatomic, strong, readonly) NSDictionary   *finalParameters;

/** 请求任务对象 */
@property (nonatomic, strong, readonly) NSURLSessionDataTask *requestDataTask;

/** 请求Session对象 */
@property (nonatomic, strong, readonly) NSURLSession   *urlSession;

/*
 * 网络请求方法 (不做任何额外处理的原始AFNetwork请求，页面上不建议直接用，请使用子类请求方法)
 * @parm successBlock 请求成功回调block
 * @parm failureBlock 请求失败回调block
 */
- (NSURLSessionDataTask *)baseRequestBlock:(WXNetworkSuccessBlock)successBlock
                              failureBlock:(WXNetworkFailureBlcok)failureBlock;

@end
