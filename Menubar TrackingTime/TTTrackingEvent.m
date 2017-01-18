//
//  TTTrackingEvent.m
//  Menubar TrackingTime
//
//  Created by Игорь Савельев on 18/01/2017.
//  Copyright © 2017 MusicSense. All rights reserved.
//

#import "TTTrackingEvent.h"

@implementation TTTrackingEvent

- (void)updateWithJSON:(NSDictionary *)json {
	[super updateWithJSON:json];
	if ([[json objectForKey:@"start"] isKindOfClass:NSString.class] &&
		[[json objectForKey:@"timezone"] isKindOfClass:NSString.class]) {
		NSString *dateStr = [json objectForKey:@"start"];
		NSString *timezone = [[json objectForKey:@"timezone"] stringByReplacingOccurrencesOfString:@" " withString:@"+"];
		dateStr = [dateStr stringByAppendingString:timezone];
		
		NSDateFormatter *dateFormatter = [NSDateFormatter new];
		dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss'GMT'XXX";
		self.dateStart = [dateFormatter dateFromString:dateStr];
	}
}

@end
