//
//  GithubAPI.m
//  Tracking Time
//
//  Created by Игорь Савельев on 06/06/2017.
//  Copyright © 2017 MusicSense. All rights reserved.
//

#import "GithubAPI.h"
#import "LPHTTPRequestSerializer.h"

@implementation GithubAPI

- (void)getLatestVersionSuccess:(void (^)(NSString *version, NSURL *url, NSURL *downloadURL))success
						failure:(void (^)(NSError *error))failure {
	NSURLRequest *request = [LPHTTPRequestSerializer requestWithMethod:@"GET" url:[NSURL URLWithString:@"https://api.github.com/repos/leonspok/Tracking-Time-OS-X/releases/latest"] params:nil];
	[[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error) {
			if (failure) {
				failure(error);
			}
		} else {
			NSError *jsonError;
			NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&jsonError];
			if (jsonError) {
				if (failure) {
					failure(jsonError);
				}
			} else {
				NSString *version = [[json objectForKey:@"tag_name"] stringByReplacingOccurrencesOfString:@"v" withString:@""];
				NSURL *url = [NSURL URLWithString:[json objectForKey:@"url"]];
				NSURL *downloadURL = [NSURL URLWithString:[[[json objectForKey:@"assets"] firstObject] objectForKey:@"browser_download_url"]];
				if (success) {
					success(version, url, downloadURL);
				}
			}
		}
	}] resume];
}

@end
