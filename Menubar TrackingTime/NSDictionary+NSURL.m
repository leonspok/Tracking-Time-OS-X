//
//  NSDictionary+NSURL.m
//  Leonspok
//
//  Created by Игорь Савельев on 20/03/14.
//  Copyright (c) 2014 Leonspok. All rights reserved.
//

#import "NSDictionary+NSURL.h"

@implementation NSDictionary (NSURL)

+ (NSDictionary *)dictionaryWithURL:(NSURL *)URL {
    NSString *queryString = [URL query];
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    NSArray *parameters = [queryString componentsSeparatedByString:@"&"];
    for (NSString *parameter in parameters) {
        NSArray *parts = [parameter componentsSeparatedByString:@"="];
        NSString *key = [[parts objectAtIndex:0] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        if ([parts count] > 1) {
            id value = [[parts objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            if (key) {
                [result setObject:value forKey:key];
            }
        }
    }
    return result;
}

@end
