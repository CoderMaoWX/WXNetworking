//
//  WXViewController.m
//  WXNetworking
//
//  Created by maowangxin on 08/16/2020.
//  Copyright (c) 2020 maowangxin. All rights reserved.
//

#import "WXViewController.h"
#import "WXNetworking.h"
#import "WXParseModel.h"
#import "AFURLResponseSerialization.h"

@interface WXViewController ()<WXNetworkMulticenter, WXNetworkBatchDelegate, WXNetworkDelegate>
@property (weak, nonatomic) IBOutlet UITextView *tipTextView;
@property (nonatomic, strong) WXNetworkRequest *testApi;
@property (nonatomic, strong) NSURLSessionDataTask *dataTask;
@end

@implementation WXViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [WXNetworkConfig sharedInstance].forbidProxyCaught = YES;//是否禁止代理抓包
    [WXNetworkConfig sharedInstance].closeUrlResponsePrintfLog = NO;
    [WXNetworkConfig sharedInstance].showRequestLaoding = YES;
    [self RequestDemo1];
}

- (IBAction)leftItemAction:(UIBarButtonItem *)sender {
    if (self.testApi.requestDataTask) {
        [self.testApi.requestDataTask cancel];
    }
}

- (IBAction)rightItemAction:(UIBarButtonItem *)sender {
    [self RequestDemo1];
}

#pragma mark -======== 测试单个请求 ========

- (void)RequestDemo1 {
    WXNetworkRequest *api = [[WXNetworkRequest alloc] init];
    api.requestType = WXRequestMethod_GET;
    api.loadingSuperView = self.view;
    api.parameters = @{@"name" : @"张三"};
    api.successStatusMap = @{@"returnCode" : @"SUCCESS"};
    api.parseModelMap = @{@"data.dKeyword" : WXParseModel.class};

//    api.multicenterDelegate = self;
//    api.retryCountWhenFailure = 2;
//    api.autoCacheResponse = YES;
//    api.responseModelCalss = [ZFResultaModel class];
//    [api startRequestWithDelegate:self];
    
    //测试电商页面数据
    api.requestUrl = @"http://123.207.32.32:8000/home/multidata";
    api.responseSerializer = [AFJSONResponseSerializer serializer];//响应: text/json
    self.testApi = api;
    
    //api.requestUrl = @"http://httpbin.org/links/20/1";
    //api.responseSerializer = [AFHTTPResponseSerializer serializer];//响应: default request headers
    
    [api startRequest:^(WXResponseModel *responseModel) {
        if (responseModel.isSuccess) {
            if ([responseModel.responseObject isKindOfClass:[NSData class]]) {
                NSString *repStr = [[NSString alloc] initWithData:responseModel.responseObject encoding:(NSUTF8StringEncoding)];
                self.tipTextView.text = repStr;// [responseModel.responseDict description];
            } else {
                self.tipTextView.text = [responseModel.responseDict description];
            }
        } else {
            self.tipTextView.text = [responseModel.error description];
        }
    }];
}

#pragma mark -======== 测试批量请求 ========

- (void)RequestDemo2 {
    WXNetworkRequest *api1 = [[WXNetworkRequest alloc] init];
    api1.requestType = WXRequestMethod_GET;
    api1.loadingSuperView = self.view;
    api1.multicenterDelegate = self;
    api1.requestUrl = @"http://wthrcdn.etouch.cn/weather_mini";
    api1.parameters = @{@"city" : @"北京"};
    
    WXNetworkRequest *api2 = [[WXNetworkRequest alloc] init];
    api2.requestType = WXRequestMethod_GET;
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
    
/**
    ///2. Block方法
    [batchRequest startRequest:^(WXNetworkBatchRequest *batchRequest) {
        NSLog(@"批量请求回调1: %@", batchRequest.responseDataArray.firstObject);
        NSLog(@"批量请求回调2: %@", [batchRequest responseForRequest:api1]);
    } waitAllDone:YES];


    ///3. 类Block方法
    [WXNetworkBatchRequest startRequest:^(WXNetworkBatchRequest *batchRequest) {
        NSLog(@"批量请求回调3: %@", [batchRequest responseForRequest:api1]);
    } batchRequests:@[api1, api2] waitAllDone:YES];
*/
    
}

#pragma mark -======== 测试下载文件 ========

- (void)RequestDemo3 {
    WXNetworkRequest *api = [[WXNetworkRequest alloc] init];
    api.requestType = WXRequestMethod_GET;
    api.loadingSuperView = self.view;
    api.parameters = nil;
    
    //下载图片文件
    api.requestUrl = @"https://picsum.photos/200/300?random=1";
    api.responseSerializer = [AFImageResponseSerializer serializer];//响应: image/png
    
    //api.requestUrl = @"http://httpbin.org/image";
    //api.requestHeaderDict = @{ @"accept" : @"image/png"};
    //api.responseSerializer = [AFImageResponseSerializer serializer];//响应: image/png
    
    //下载Zip文件
    //api.requestUrl = @"http://i.gtimg.cn/qqshow/admindata/comdata/vipThemeNew_item_2135/2135_i_4_7_i_1.zip";
    //api.responseSerializer = [AFHTTPResponseSerializer serializer];//响应: default request headers
    
    [api startRequest:^(WXResponseModel *responseModel) {
        if (responseModel.isSuccess) {
            NSLog(@"下载图片成功: %@", responseModel.responseObject);
            if ([responseModel.responseObject isKindOfClass:[UIImage class]]) {
                self.tipTextView.hidden = YES;
                self.view.backgroundColor = [UIColor colorWithPatternImage:responseModel.responseObject];
            }
        } else {
            self.tipTextView.hidden = NO;
            self.tipTextView.text = responseModel.error.domain;
        }
    }];
}

#pragma mark -======== 测试上传文件 ========

//上传图片文件
- (void)RequestDemo6 {
    WXNetworkRequest *api = [[WXNetworkRequest alloc] init];
    api.requestType = WXRequestMethod_POST;
    api.loadingSuperView = self.view;
    api.parameters =  @{
        @"appName"  :   @"ZAFUL",
        @"platform" :   @"iOS",
        @"version"  :   @"7.3.3",
    };
    api.requestUrl = @"http://10.8.31.5:8090/uploadImage";
    UIImage *image = [UIImage imageNamed:@"about_logo"];
    NSData *imageData = UIImagePNGRepresentation(image);
    if (imageData) {
        api.uploadFileDataArr = @[imageData];
        api.uploadConfigDataBlock = ^(id<AFMultipartFormData> formData) {
            
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setTimeZone:[NSTimeZone localTimeZone]];
            [formatter setDateFormat:@"yyyy-MM-dd-HHmmssSSS"];
            NSString *locationString = [formatter stringFromDate:[NSDate date]];
            NSString *fileName = [locationString stringByAppendingFormat:@".%@", @"png"];
            [formData appendPartWithFileData:imageData
                                        name:@"files"
                                    fileName:fileName
                                    mimeType:@"png"];
        };
    }
    api.responseSerializer = [AFJSONResponseSerializer serializer];//响应: text/json
    
    [api startRequest:^(WXResponseModel *responseModel) {
        if (responseModel.isSuccess) {
            NSLog(@"上传图片文件成功: %@", @"http://10.8.31.5:8090/showImages");
            if ([responseModel.responseObject isKindOfClass:[UIImage class]]) {
                self.tipTextView.hidden = YES;
                self.view.backgroundColor = [UIColor colorWithPatternImage:responseModel.responseObject];
            }
        } else {
            self.tipTextView.hidden = NO;
            self.tipTextView.text = responseModel.error.domain;
        }
    }];
}


#pragma mark - <WXNetworkBatchDelegate>

/**
 多个网络请求完成后响应一次回调

 @param batchRequest 批量请求管理对象
 */
- (void)wxBatchResponseWithRequest:(WXNetworkBatchRequest *)batchRequest {
    NSLog(@"批量请求回调1: %@", batchRequest.responseDataArray.firstObject);
    NSLog(@"批量请求回调2: %@", [batchRequest responseForRequest:batchRequest.requestArray.firstObject]);
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
    NSLog(@"网络请求将要停止回调===%@", responseModel);
    self.tipTextView.text = responseModel.responseDict.description;
}

/**
 * 网络请求已经停止回调
 * @param responseModel 请求对象
 */
- (void)requestDidCompletion:(WXNetworkRequest *)request responseModel:(WXResponseModel *)responseModel {
    NSLog(@"网络请求已经停止回调===%@", responseModel);
    self.tipTextView.text = responseModel.responseDict.description;
}

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
@end
