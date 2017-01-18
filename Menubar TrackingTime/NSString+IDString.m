//
//  NSString+IDString.m
//  Leonspok
//
//  Created by Игорь Савельев on 26/04/15.
//  Copyright (c) 2015 Leonspok. All rights reserved.
//

#import "NSString+IDString.h"
#import "NSString+MD5.h"

@implementation NSString (IDString)

+ (instancetype)IDStringForClass:(Class)class {
    NSString *string = [NSString stringWithFormat:@"%@_%@", NSStringFromClass(class), [[NSUUID UUID] UUIDString]];
    return [string MD5String];
}

@end
