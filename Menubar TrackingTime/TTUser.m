//
//  TTUser.m
//  Menubar TrackingTime
//
//  Created by Игорь Савельев on 18/01/2017.
//  Copyright © 2017 MusicSense. All rights reserved.
//

#import "TTUser.h"

@implementation TTUser

- (void)updateWithJSON:(NSDictionary *)json {
	[super updateWithJSON:json];
	if ([[json objectForKey:@"name"] isKindOfClass:NSString.class]) {
		self.name = [json objectForKey:@"name"];
	}
	if ([[json objectForKey:@"surname"] isKindOfClass:NSString.class]) {
		self.surname = [json objectForKey:@"surname"];
	}
	if ([[json objectForKey:@"email"] isKindOfClass:NSString.class]) {
		self.email = [json objectForKey:@"email"];
	}
	if ([[json objectForKey:@"account_id"] isKindOfClass:NSNumber.class]) {
		self.accountUID = [json objectForKey:@"account_id"];
	}
}

@end
