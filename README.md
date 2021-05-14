# WXNetworking

[![CI Status](https://img.shields.io/travis/maowangxin/WXNetworking.svg?style=flat)](https://travis-ci.org/maowangxin/WXNetworking)
[![Version](https://img.shields.io/cocoapods/v/WXNetworking.svg?style=flat)](https://cocoapods.org/pods/WXNetworking)
[![License](https://img.shields.io/cocoapods/l/WXNetworking.svg?style=flat)](https://cocoapods.org/pods/WXNetworking)
[![Platform](https://img.shields.io/cocoapods/p/WXNetworking.svg?style=flat)](https://cocoapods.org/pods/WXNetworking)

## Requirements

To run the example project, clone the repo, and run `pod install` from the Example directory first.


## Installation

WXNetworking is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'WXNetworking'
```

## Examples

一、根据需求可灵活配置的公共属性.

```
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

/** 是否打开多路径TCP服务，提供Wi-Fi和蜂窝之间的无缝切换，默认关闭 */
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

@end
```


二、针对单个请求配置需求的属性.

```
@interface WXBaseRequest : NSObject

/** 请求类型 */
@property (nonatomic, assign) WXNetworkRequestType     requestType;

/** 请求地址 */
@property (nonatomic, copy)   NSString                  *requestUrl;

/** 请求参数 */
@property (nonatomic, strong) NSDictionary              *parameters;

/** 请求超时，默认30s */
@property (nonatomic, assign) NSInteger                 timeOut;

/** 请求自定义头信息 */
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *requestHeaderDict;

/** 请求序列化对象 */
@property (nonatomic, strong) AFHTTPRequestSerializer  *requestSerializer;

/** 响应序列化对象 */
@property (nonatomic, strong) AFHTTPResponseSerializer *responseSerializer;

/** 上传文件Data数组 */
@property (nonatomic, strong) NSArray<NSData *>        *uploadFileDataArr;

/** 上传时包装的数据Data对象 */
@property (nonatomic, copy) WXNetworkUploadDataBlock  uploadConfigDataBlock;

/** 监听上传进度 */
@property (nonatomic, copy) WXNetworkProgressBlock    uploadProgressBlock;

/** 监听下载进度 */
@property (nonatomic, copy) WXNetworkProgressBlock    downloadProgressBlock;

/** 底层最终的请求参数 (页面上可实现<WXPackParameters>协议来实现重新包装请求参数) */
@property (nonatomic, strong, readonly) NSDictionary    *finalParameters;

/** 请求任务对象 */
@property (nonatomic, strong, readonly) NSURLSessionDataTask *requestDataTask;

/** 请求Session对象 */
@property (nonatomic, strong, readonly) NSURLSession    *urlSession;

/** 需要单独解析Model时的key, 如果单独设置则会忽略单例中的全局解析key */
@property (nonatomic, copy) NSString        *customModelKey;

@end

```

三、单个请求的示例用法

```
WXNetworkRequest *api = [[WXNetworkRequest alloc] init];
api.requestType = WXNetworkRequestTypeGET;
api.loadingSuperView = self.view;
    
//    api.multicenterDelegate = self;
//    api.retryCountWhenFailure = 2;
//    api.autoCacheResponse = YES;
//    api.responseModelCalss = [ZFResultaModel class];
//    [api startRequestWithDelegate:self];
    
    api.requestUrl = @"http://www.tianqiapi.com/api?version=v9&appid=23035354&appsecret=8YvlPNrz";
    api.parameters = nil;
    
    [api startRequestWithBlock:^(WXResponseModel *responseModel) {
        if (responseModel.isSuccess) {
            self.tipTextView.text = [responseModel.responseDict description];
        } else {
            self.tipTextView.text = [responseModel.error description];
        }
    }];

```


四、批量请求的示例用法

```
WXNetworkRequest *api1 = [[WXNetworkRequest alloc] init];
api1.requestType = WXNetworkRequestTypeGET;
api1.loadingSuperView = self.view;
api1.multicenterDelegate = self;
api1.requestUrl = @"http://wthrcdn.etouch.cn/weather_mini";
api1.parameters = @{@"city" : @"北京"};

WXNetworkRequest *api2 = [[WXNetworkRequest alloc] init];
api2.requestType = WXNetworkRequestTypeGET;
api2.loadingSuperView = self.view;
api2.multicenterDelegate = self;
api2.requestUrl = @"https://www.tianqiapi.com/api";
api2.parameters = @{
    @"version"  : @"v6",
    @"appid"    : @"21375891",
    @"appsecret": @"fTYv7v5E",
    @"city"     : @"南京",
};

WXNetworkBatchRequest *batchRequest = [WXNetworkBatchRequest new];
batchRequest.requestArray = @[api2, api1];

///1. 代理方法
[batchRequest startRequestWithDelegate:self waitAllDone:YES];


///2. Block方法
[batchRequest startRequestWithBlock:^(WXNetworkBatchRequest *batchRequest) {
    NSLog(@"批量请求回调1: %@", batchRequest.responseDataArray.firstObject);
    NSLog(@"批量请求回调2: %@", [batchRequest responseForRequest:api1]);
} waitAllDone:YES];


///3. 类Block方法
[WXNetworkBatchRequest startRequestWithBlock:^(WXNetworkBatchRequest *batchRequest) {
    NSLog(@"批量请求回调3: %d", [batchRequest responseForRequest:api1]);
} batchRequests:@[api1, api2] waitAllDone:YES];


#pragma mark - <WXNetworkDelegate>

/**
 * 网络请求数据响应回调
 * @param responseModel 请求对象
 */
- (void)wxResponseWithRequest:(WXNetworkRequest *)request
                 responseModel:(WXResponseModel *)responseModel {
    NSLog(@"====网络请求数据响应回调====%@", responseModel);
    self.tipTextView.text = responseModel.responseDict.description;
}


#pragma mark - <WXNetworkMulticenter>

/**
 * 网络请求将要开始回调
 * @param request 请求对象
 */
- (void)requestWillStart:(WXNetworkRequest *)request {
    self.tipTextView.text = @"请求中...";
    NSLog(@"网络请求将要开始回调===%@", [request description]);
}

/**
 * 网络请求将要停止回调
 * @param responseModel 请求对象
 */
- (void)requestWillStop:(WXNetworkRequest *)request responseModel:(WXResponseModel *)responseModel {
    NSLog(@"网络请求将要停止回调===%@", [responseModel description]);
    self.tipTextView.text = responseModel.responseDict.description;
}

/**
 * 网络请求已经停止回调
 * @param responseModel 请求对象
 */
- (void)requestDidCompletion:(WXNetworkRequest *)request responseModel:(WXResponseModel *)responseModel {
    NSLog(@"网络请求已经停止回调===%@", [responseModel description]);
    self.tipTextView.text = responseModel.responseDict.description;
}

```


## Author

maowangxin, maowangxin_2013@163.com

## License

WXNetworking is available under the MIT license. See the LICENSE file for more info.


