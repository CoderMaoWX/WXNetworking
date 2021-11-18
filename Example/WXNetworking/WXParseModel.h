//
//  WXParseModel.h
//  WXNetworking_Example
//
//  Created by 610582 on 2021/11/18.
//  Copyright © 2021 maowangxin. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WXListModel : NSObject
@property (nonatomic, copy) NSString *acm;
@property (nonatomic, copy) NSString *defaultKeyWord;
@end

@interface WXContextModel : NSObject
@property (nonatomic, assign) double currentTime;
@end

@interface WXParseModel : NSObject
@property (nonatomic, strong) WXContextModel *context;
@property (nonatomic, strong) NSArray<WXListModel *> *list;
@property (nonatomic, assign) BOOL isEnd;
@property (nonatomic, assign) NSInteger nextPage;
@end

