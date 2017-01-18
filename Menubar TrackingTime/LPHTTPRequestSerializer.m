//
//  LPHTTPRequestSerializer.m
//  Leonspok
//
//  Created by Игорь Савельев on 24/06/16.
//  Copyright © 2016 Leonspok. All rights reserved.
//

#import "LPHTTPRequestSerializer.h"
#import "NSCharacterSet+QueryParams.h"

@implementation LPHTTPRequestSerializer

+ (NSMutableURLRequest *)requestWithMethod:(NSString *)method url:(NSURL *)url params:(NSDictionary<NSString *, id> *)params {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    [request setHTTPMethod:[method uppercaseString]];
    if (params.count > 0) {
        NSMutableString *queryString = [NSMutableString string];
        NSUInteger i = 0;
        for (NSString *key in params.allKeys) {
            NSString *valueString = nil;
            id value = [params objectForKey:key];
            if ([value isKindOfClass:NSString.class]) {
                valueString = value;
            } else if ([value isKindOfClass:NSNumber.class]) {
                NSNumber *number = value;
                if (strcmp([number objCType], @encode(BOOL)) == 0) {
                    valueString = [number boolValue]? @"true" : @"false";
                } else {
                    valueString = [number stringValue];
                }
            } else {
                valueString = [value description];
            }
            
            [queryString appendFormat:@"%@=%@", [key stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]], [valueString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryParameterValueAllowedCharacterSet]]];
            if (i < params.count-1) {
                [queryString appendString:@"&"];
            }
            i++;
        }
        
        if ([[method uppercaseString] isEqualToString:@"GET"]) {
            request.URL = [NSURL URLWithString:[[request.URL absoluteString] stringByAppendingFormat:request.URL.query ? @"&%@" : @"?%@", queryString]];
        } else {
            [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
            [request setHTTPBody:[queryString dataUsingEncoding:NSUTF8StringEncoding]];
        }
    }
    return request;
}

+ (NSMutableURLRequest *)multipartRequestWithURL:(NSURL *)url params:(NSDictionary<NSString *, id> *)params {
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
	[request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
	[request setHTTPMethod:@"POST"];
	
	NSString *boundary = [[NSUUID UUID] UUIDString];
	NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
	[request addValue:contentType forHTTPHeaderField:@"Content-Type"];
	
	NSMutableData *body = [NSMutableData data];
	
	for (NSString *key in [params allKeys]) {
		[body appendData:[[NSString stringWithFormat:@"\n--%@\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
		
		id value = [params objectForKey:key];
		if ([value isKindOfClass:NSData.class]) {
			[body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"file.bin\"\n", key] dataUsingEncoding:NSUTF8StringEncoding]];
			[body appendData:[@"Content-Type: application/octet-stream\n\n" dataUsingEncoding:NSUTF8StringEncoding]];
			[body appendData:value];
		} else {
			[body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\n\n", key] dataUsingEncoding:NSUTF8StringEncoding]];
			NSString *valueString = nil;
			if ([value isKindOfClass:NSString.class]) {
				valueString = value;
			} else if ([value isKindOfClass:NSNumber.class]) {
				NSNumber *number = value;
				if (strcmp([number objCType], @encode(BOOL)) == 0) {
					valueString = [number boolValue]? @"true" : @"false";
				} else {
					valueString = [number stringValue];
				}
			} else {
				valueString = [value description];
			}
			[body appendData:[valueString dataUsingEncoding:NSUTF8StringEncoding]];
		}
	}
	[body appendData:[[NSString stringWithFormat:@"\n--%@--\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
	[request setHTTPBody:body];
	return request;
}

@end
