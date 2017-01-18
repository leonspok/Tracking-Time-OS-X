//
//  TTDataObject.m
//  Menubar TrackingTime
//
//  Created by Игорь Савельев on 18/01/2017.
//  Copyright © 2017 MusicSense. All rights reserved.
//

#import "TTDataObject.h"
#import "NSArray+Utilities.h"

@implementation TTDataObject

- (id)initWithJSON:(NSDictionary *)json {
	self = [self init];
	if (self) {
		[self updateWithJSON:json];
	}
	return self;
}

+ (NSArray *)createObjectsFromJSON:(NSArray *)jsonObjects {
	return [jsonObjects mapWithBlock:^id(id obj) {
		return [[self.class alloc] initWithJSON:obj];
	}];
}

- (void)updateWithJSON:(NSDictionary *)json {
	if ([[json objectForKey:@"id"] isKindOfClass:NSNumber.class]) {
		self.uid = [json objectForKey:@"id"];
	}
}

- (BOOL)isEqual:(id)object {
	if (!object) {
		return NO;
	}
	if ([object isKindOfClass:self.class]) {
		TTDataObject *other = (TTDataObject *)object;
		return [other.uid isEqual:self.uid];
	}
	return NO;
}

- (NSUInteger)hash {
	return self.uid.hash;
}

@end
