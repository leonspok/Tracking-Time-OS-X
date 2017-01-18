//
//  LPHTTPRequestSerializer.h
//  Leonspok
//
//  Created by Игорь Савельев on 24/06/16.
//  Copyright © 2016 Leonspok. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LPHTTPRequestSerializer : NSObject

+ (NSMutableURLRequest *)requestWithMethod:(NSString *)method url:(NSURL *)url params:(NSDictionary<NSString *, id> *)params;
+ (NSMutableURLRequest *)multipartRequestWithURL:(NSURL *)url params:(NSDictionary<NSString *, id> *)params;

@end
