//
//  NSOrderedSet+Utilities.m
//  Leonspok
//
//  Created by Игорь Савельев on 06/04/16.
//  Copyright © 2016 Leonspok. All rights reserved.
//

#import "NSOrderedSet+Utilities.h"

@implementation NSOrderedSet (Utilities)

- (NSOrderedSet *)mapWithBlock:(id (^)(id))mapBlock {
    NSMutableOrderedSet *newSet = [NSMutableOrderedSet orderedSet];
    for (id obj in self) {
        id newObj;
        if (mapBlock) {
            newObj = mapBlock(obj);
        }
        if (newObj) {
            [newSet addObject:newObj];
        }
    }
    return [NSOrderedSet orderedSetWithOrderedSet:newSet];
}

- (NSOrderedSet *)filterWithBlock:(BOOL (^)(id))filterBlock {
    NSMutableOrderedSet *newSet = [NSMutableOrderedSet orderedSet];
    for (id obj in self) {
        if (filterBlock && filterBlock(obj)) {
            [newSet addObject:obj];
        }
    }
    return [NSOrderedSet orderedSetWithOrderedSet:newSet];
}

@end
