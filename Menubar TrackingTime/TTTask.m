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
	TTProject *project = nil;
	if ([[json objectForKey:@"project_id"] isKindOfClass:NSNumber.class]) {
		project = [TTProject new];
		project.uid = [json objectForKey:@"project_id"];
	}
	if ([[json objectForKey:@"project"] isKindOfClass:NSString.class]) {
		project.name = [json objectForKey:@"project"];
	}
	self.project = project;
}

@end
