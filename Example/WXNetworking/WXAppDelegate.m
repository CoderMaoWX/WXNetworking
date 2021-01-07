//
//  WXAppDelegate.m
//  WXNetworking
//
//  Created by maowangxin on 08/16/2020.
//  Copyright (c) 2020 maowangxin. All rights reserved.
//

#import "WXAppDelegate.h"
#import "WXNetworking.h"

@implementation WXAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // 捕获全局崩溃
    NSSetUncaughtExceptionHandler (&UncaughtExceptionHandler);
    
    return YES;
}

/**
 * 捕获全局崩溃, 防止主页数据有脏数据缓存导致启动App崩溃, 需要清除所有接口的缓存数据
 * 如果某一个时段内崩溃次数较多, 需要清掉有的NSUserDefaults数据
 */
void UncaughtExceptionHandler(NSException *exception) {
    NSLog(@"处理全局崩溃信息: %@ \n%@ \n%@", exception.name, exception.reason, exception.userInfo);
    [WXAppDelegate uploadCrashInfo:exception];
}

+ (void)uploadCrashInfo:(NSException *)exception {
//    NSString *urlStr = [NSString stringWithFormat:@"https://www.baidu.com"];
//        NSURL *url = [NSURL URLWithString:[urlStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
//        [[UIApplication sharedApplication] openURL:url];
//    return;
    
    WXNetworkRequest *api = [[WXNetworkRequest alloc] init];
    api.requestType = WXNetworkRequestTypePOST;
    api.requestUrl = @"http://wxpusher.zjiecode.com/api/send/message";
    
    api.parameters = @{
        @"appToken" : @"AT_dxtUnqIpZQJrTHyyBCIxCG4lkmaqE4q8",
        @"content" : exception.name,
        @"summary" : exception.userInfo.description,
        @"contentType" : @"1",
        @"topicIds" : @[@"1308"],
        @"uids" : @[@"UID_A53p3pm6VHhDC08ad62tiBrMm2hB"],
        @"url" : @"https://www.zaful.com",
    };
    
    
    [api startRequestWithBlock:^(WXResponseModel *responseModel) {
    
    }];
}


- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
