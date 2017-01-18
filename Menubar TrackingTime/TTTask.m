//
//  TTTask.m
//  Menubar TrackingTime
//
//  Created by Игорь Савельев on 18/01/2017.
//  Copyright © 2017 MusicSense. All rights reserved.
//

#import "TTTask.h"

@implementation TTTask

- (void)updateWithJSON:(NSDictionary *)json {
	[super updateWithJSON:json];
	if ([[json objectForKey:@"name"] isKindOfClass:NSString.class]) {
		self.name = [json objectForKey:@"name"];
	}
	if ([[json objectForKey:@"project"] isKindOfClass:NSString.class]) {
		self.projectName = [json objectForKey:@"project"];
	} else {
		self.projectName = @"<null>";
	}
	if ([[json objectForKey:@"project_id"] isKindOfClass:NSNumber.class]) {
		self.projectUID = [json objectForKey:@"project_id"];
	}
}

@end
