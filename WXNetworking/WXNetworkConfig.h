//
//  WXNetworkConfig.h
//  WXNetworking
//
//  Created by MaoWX on 2020/08/16.
//  Copyright © 2020 WX. All rights reserved.
//

#import <Foundation/Foundation.h>

@class YYDiskCache, WXNetworkRequest;
@protocol WXNetworkMulticenter;


@interface WXNetworkConfig : NSObject

/** 各站自定义请求成功标识 */
@property (nonatomic, copy) NSString        *statusKey;
@property (nonatomic, copy) NSString        *statusCode;
@property (nonatomic, copy) NSString        *messageKey;

/** 需要解析Model时的全局key,(可选) */
@property (nonatomic, copy) NSString        *customModelKey;

/** 请求失败时的默认提示 */
@property (nonatomic, copy) NSString        *requestFailDefaultMessage;

/** 全局网络请求拦截类 */
@property (nonatomic, strong) Class         urlSessionProtocolClasses;

/** 取请求缓存时用到的YYChache对象 */
@property (nonatomic, strong, readonly) YYDiskCache *networkDiskCache;

/** 请求遇到相应Code时触发通知: @{ @"notificationName" : @(200) } */
@property (nonatomic, strong) NSDictionary<NSString *, NSNumber *> *errorCodeNotifyDict;

/**
 * 是否需要全局管理 网络请求过程多通道回调<将要开始, 将要完成, 已经完成>
 * 注意: 此代理与请求对象中的<multicenterDelegate>代理互斥, 两者都实现时只会回调请求对象中的代理
 */
@property (nonatomic, weak) id<WXNetworkMulticenter> globleMulticenterDelegate;

/** 是否禁止所有的网络请求设置代理抓包 (警告: 一定要放在首次发请求之前设值, 默认不禁止) */
@property (nonatomic, assign) BOOL          forbidProxyCaught;

/** 是否打开多路径TCP服务，提供Wi-Fi和蜂窝之间的无缝切换，(默认关闭) */
@property (nonatomic, assign) BOOL          openMultipathService;

/** 请求HUD时的类名*/
@property (nonatomic, strong) Class         requestLaodingCalss;

/** 请求HUD全局开关, 默认不显示HUD */
@property (nonatomic, assign) BOOL          showRequestLaoding;

/** 是否为正式上线环境: 如果为真,则下面的所有日志上传/打印将全都被忽略 */
@property (nonatomic, assign) BOOL          isDistributionOnlineRelease;

/** 在底层打印时提示环境,只作打印使用 */
@property (nonatomic, copy) NSString        *networkHostTitle;

/** 上传请求日志到指定的URL */
@property (nonatomic, copy) NSString        *uploadRequestLogToUrl;

/** 日志系统抓包时的标签名 */
@property (nonatomic, copy) NSString        *uploadCatchLogTagStr;

/** 是否上传日志到远程日志系统，默认不上传 */
@property (nonatomic, assign) BOOL          uploadResponseJsonToLogSystem;

/** 是否关闭打印: 接口响应日志，默认关闭 */
@property (nonatomic, assign) BOOL          closeUrlResponsePrintfLog;

/** 是否关闭打印: 统计上传日志，默认关闭 */
@property (nonatomic, assign) BOOL          closeStatisticsPrintfLog;

/*
 * 构建单例
 */
+ (instancetype)sharedInstance;

/** 清除所有缓存 */
- (void)clearWXNetworkAllRequestCache;

/** 清除指定缓存 */
- (void)clearWXNetworkCacheOfRequest:(WXNetworkRequest *)serverApi;

@end
