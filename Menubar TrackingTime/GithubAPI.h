//
//  GithubAPI.h
//  Tracking Time
//
//  Created by Игорь Савельев on 06/06/2017.
//  Copyright © 2017 MusicSense. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GithubAPI : NSObject

- (void)getLatestVersionSuccess:(void (^)(NSString *version, NSURL *url, NSURL *downloadURL))success
						failure:(void (^)(NSError *error))failure;

@end
