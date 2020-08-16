//
//  WXNetworkPlugin.h
//  WXNetworking
//
//  Created by MaoWX on 2020/08/16.
//  Copyright © 2020 WX. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@class WXResponseModel, WXNetworkRequest;

FOUNDATION_EXPORT NSString *const KWXUploadAppsFlyerStatisticsKey;
FOUNDATION_EXPORT NSString *const KWXRequestAbsoluteDateFormatterKey;
FOUNDATION_EXPORT NSString *const kWXRequestDataFromCacheKey;
FOUNDATION_EXPORT NSString *const kWXNetworkResponseCacheKey;
FOUNDATION_EXPORT NSString *const KWXRequestFailueTipMessage;
FOUNDATION_EXPORT NSString *const KWXRequestRequestArrayAssert;
FOUNDATION_EXPORT NSString *const KWXRequestRequestArrayObjAssert;
FOUNDATION_EXPORT NSString *const KWXNetworkRequestDeallocDesc;
FOUNDATION_EXPORT NSString *const KWXNetworkBatchRequestDeallocDesc;


#ifdef DEBUG
#define WXNetworkLog( s, ... ) printf("%s\n",[[NSString stringWithFormat:(s), ##__VA_ARGS__] UTF8String])
#else
#define WXNetworkLog( s, ... )
#endif

@interface WXNetworkPlugin : NSObject

/**
 上传网络日志到服装日志系统入口

 @param responseModel 响应模型
 @param request 请求对象
 */
+ (void)uploadNetworkResponseJson:(WXResponseModel *)responseModel
                          request:(WXNetworkRequest *)request;


/**
 打印日志头部

 @param responseModel 响应模型
 @param request 请求对象
 @return 日志头部字符串
 */
+ (NSString *)appendingPrintfLogHeader:(WXResponseModel *)responseModel
                               request:(WXNetworkRequest *)request;

/**
 打印日志尾部
 
 @param responseModel 响应模型
 @return 日志头部字符串
 */
+ (NSString *)appendingPrintfLogFooter:(WXResponseModel *)responseModel;


/**
 * 上传时获取图片类型

 @param imageData 图片Data
 @return 图片类型描述数组
 */
+ (NSArray *)typeForImageData:(NSData *)imageData;

/**
 MD5加密字符串
 
 @param string 需要MD5的字符串
 @return MD5后的字符串
 */
+ (NSString *)WXMD5String:(NSString *)string;

@end

#pragma mark -===========请求转圈弹框===========

@interface WXNetworkHUD : UIView

/**
* 移除指定参数传进来的View
*/
+ (void)hideLoadingFromView:(UIView *)view;

/**
 * 请求时显示转圈
 */
+ (void)showLoadingToView:(UIView *)view;

@end
