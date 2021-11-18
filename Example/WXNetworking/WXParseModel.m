//
//  WXParseModel.m
//  WXNetworking_Example
//
//  Created by 610582 on 2021/11/18.
//  Copyright © 2021 maowangxin. All rights reserved.
//

#import "WXParseModel.h"


@implementation WXListModel
@end


@implementation WXContextModel
@end


@implementation WXParseModel

+ (NSDictionary *)modelContainerPropertyGenericClass {
    return @{
        @"context" : [WXContextModel class],
        @"list" : [WXListModel class],
    };
}
@end
