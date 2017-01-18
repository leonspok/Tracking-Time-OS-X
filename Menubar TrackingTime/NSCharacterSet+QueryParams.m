//
//  NSCharacterSet+QueryParams.m
//  Leonspok
//
//  Created by Игорь Савельев on 29/08/16.
//  Copyright © 2016 Leonspok. All rights reserved.
//

#import "NSCharacterSet+QueryParams.h"

@implementation NSCharacterSet (QueryParams)

+ (instancetype)URLQueryParameterValueAllowedCharacterSet {
    static NSString * const kGeneralDelimitersToEncode = @":#[]@";
    static NSString * const kSubDelimitersToEncode = @"!$&'()*+,;=";
    
    NSMutableCharacterSet * allowedCharacterSet = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
    [allowedCharacterSet removeCharactersInString:[kGeneralDelimitersToEncode stringByAppendingString:kSubDelimitersToEncode]];
    
    return allowedCharacterSet;
}

@end
