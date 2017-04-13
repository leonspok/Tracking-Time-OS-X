//
//  TTProject.m
//  Tracking Time
//
//  Created by Игорь Савельев on 13/04/2017.
//  Copyright © 2017 MusicSense. All rights reserved.
//

#import "TTProject.h"

@implementation TTProject

- (void)updateWithJSON:(NSDictionary *)json {
	[super updateWithJSON:json];
	if ([[json objectForKey:@"name"] isKindOfClass:NSString.class]) {
		self.name = [json objectForKey:@"name"];
	}
}

@end
