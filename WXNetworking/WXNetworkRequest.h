//
//  WXNetworkRequest.h
//  WXNetworking
//
//  Created by MaoWX on 2020/08/16.
//  Copyright © 2020 WX. All rights reserved.
//

#import "WXBaseRequest.h"
@class WXNetworkRequest, WXNetworkBatchRequest;

NS_ASSUME_NONNULL_BEGIN

@interface WXResponseModel : NSObject
@property (nonatomic, assign, readonly) BOOL                        isSuccess;
@property (nonatomic, assign, readonly) BOOL                        isCacheData;
@property (nonatomic, assign, readonly) CGFloat                     responseDuration;
@property (nonatomic, assign, readonly) NSInteger                   responseCode;
@property (nonatomic, strong, readonly, nullable) id                responseModel;
@property (nonatomic, strong, readonly, nullable) id                responseObject;//NSDictionary/UIImage/NSData/...
@property (nonatomic, strong, readonly, nullable) NSDictionary      *responseDict;
@property (nonatomic, copy  , readonly, nullable) NSString          *responseMsg;
@property (nonatomic, strong, readonly, nullable) NSError           *error;
@property (nonatomic, strong, readonly, nullable) NSHTTPURLResponse *urlResponse;
@property (nonatomic, strong, readonly, nullable) NSURLRequest      *originalRequest;
@end


@protocol WXNetworkDelegate <NSObject>
/**
 网络请求数据响应回调

 @param request 请求对象
 @param responseModel 响应对象
 */
- (void)wxResponseWithRequest:(WXNetworkRequest *)request
                 responseModel:(WXResponseModel *)responseModel;
@end


@protocol WXNetworkBatchDelegate <WXNetworkDelegate>
/**
 多个网络请求完成后响应一次回调

 @param batchRequest 请求对象数组
 @param responseModelArray 响应对象数组
 */
- (void)wxBatchResponseWithRequest:(WXNetworkBatchRequest *)batchRequest
                         modelArray:(NSArray<WXResponseModel *> *)responseModelArray;
@end


@protocol WXNetworkMulticenter <NSObject>
/**
 * 网络请求将要开始回调
 * @param request 请求对象
 */
- (void)requestWillStart:(WXNetworkRequest *)request;

/**
 * 网络请求回调将要停止 (包括成功或失败)
 * @param responseModel 请求对象
 */
- (void)requestWillStop:(WXNetworkRequest *)request responseModel:(WXResponseModel *)responseModel;

/**
 * 网络请求已经回调完成 (包括成功或失败)
 * @param responseModel 请求对象
 */
- (void)requestDidCompletion:(WXNetworkRequest *)request responseModel:(WXResponseModel *)responseModel;

@end



@interface WXNetworkRequest : WXBaseRequest


/** 请求成功时是否需要自动缓存响应数据 */
@property (nonatomic, assign) BOOL      autoCacheResponse;

/** 请求成功时自定义响应缓存数据, (返回的字典为此次需要保存的缓存数据, 返回nil时,底层则不缓存) */
@property (nonatomic, copy) NSDictionary* (^cacheResponseBlock)(WXResponseModel *responseModel);

/** 请求成功返回后解析成相应的Model返回 */
@property (nonatomic, strong) Class     responseModelCalss;

/** 请求转圈的父视图 */
@property (nonatomic, strong) UIView    *loadingSuperView;

/** 请求失败之后重新请求次数*/
@property (nonatomic, assign) NSInteger retryCountWhenFailure;

/**
 * 网络请求过程多通道回调<将要开始, 将要停止, 已经完成>
 * 注意: 如果没有实现此代理则会回调单例中的全局代理<globleMulticenterDelegate>
 */
@property (nonatomic, weak) id<WXNetworkMulticenter> multicenterDelegate;

/** 可以用来添加几个accossories对象 来做额外的(请求HUD, 加解密, 自定义打印, 上传统计)插件等特殊功能 */
@property (nonatomic, strong) NSArray<id<WXNetworkMulticenter>> *requestAccessories;

/*
 * 缓存key, 可用于清除指定请求
 */
- (NSString *)cacheKey;

/*
 * 单个网络请求->代理回调
 * @parm networkDelegate 请求成功失败回调代理
 */
- (NSURLSessionDataTask *)startRequestWithDelegate:(id<WXNetworkDelegate>)responseDelegate;

/*
 * 单个网络请求->Block回调
 * @parm responseBlock 请求响应block
 */
- (NSURLSessionDataTask *)startRequestWithBlock:(WXNetworkResponseBlock)responseBlock;

/**
 * 取消局部请求链接。（可用于用户退出界面，或搜索框连续请求这样的需求）
 */
+ (void)cancelRequestsWithApiList:(NSArray<WXNetworkRequest *> *)requestList;

/**
 * 取消全局请求管理数组中所有请求操作 (可在注销,退出登录,内存警告时调用此方法)
 */
+ (void)cancelGlobleAllRequestMangerTask;

@end


@interface WXNetworkBatchRequest : NSObject

/** 批量请求是否都请求成功了 */
@property(nonatomic, assign, readonly) BOOL isAllSuccess;

/**
 * 便捷初始化多并发请求函数
 * @param requestArray 请求WXNetworkRequest对象数组
 * @return 多并发请求对象
 */
+ (instancetype)batchArrayRequest:(NSArray<WXNetworkRequest *> *)requestArray;

/**
 批量网络请求

 @param responseDelegate 请求全部完成后的响应代理回调
 @param shouldAllSuccess 是否等待全部请求完成才回调
 */
- (void)startRequestWithDelegate:(id<WXNetworkBatchDelegate>)responseDelegate
                  waitAllSuccess:(BOOL)shouldAllSuccess;

/**
 批量网络请求

 @param responseBlock 请求全部完成后的响应block回调
 @param shouldAllSuccess 是否等待全部请求完成才回调
 */
- (void)startRequestWithBlock:(WXNetworkBatchBlock)responseBlock
               waitAllSuccess:(BOOL)shouldAllSuccess;

@end

NS_ASSUME_NONNULL_END
