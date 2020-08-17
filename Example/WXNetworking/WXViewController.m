//
//  WXViewController.m
//  WXNetworking
//
//  Created by maowangxin on 08/16/2020.
//  Copyright (c) 2020 maowangxin. All rights reserved.
//

#import "WXViewController.h"
#import "WXNetworking.h"

@interface WXViewController ()
@property (weak, nonatomic) IBOutlet UITextView *tipTextView;
@end

@implementation WXViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [WXNetworkConfig sharedInstance].closeUrlResponsePrintfLog = NO;
    [WXNetworkConfig sharedInstance].showRequestLaoding = YES;
    
    [self RequestDemo1];
}

- (IBAction)requestAction:(id)sender {
    [self RequestDemo1];
}

#pragma mark - 测试方法

- (void)RequestDemo1 {
    self.tipTextView.text = @"请求中...";
    
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
}

#pragma mark - <WXNetworkMulticenter>

/**
 * 网络请求将要开始回调
 * @param request 请求对象
 */
- (void)requestWillStart:(WXNetworkRequest *)request {
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

#pragma mark - <WXNetworkDelegate>

/**
 * 网络请求数据响应回调
 * @param responseModel 请求对象
 */
- (void)gfzResponseWithRequest:(WXNetworkRequest *)request
                 responseModel:(WXResponseModel *)responseModel
{
    NSLog(@"====网络请求数据响应回调====%@", responseModel);
    self.tipTextView.text = responseModel.responseDict.description;
}
@end
