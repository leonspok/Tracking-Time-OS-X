//
//  NSOrderedSet+Utilities.h
//  Leonspok
//
//  Created by Игорь Савельев on 06/04/16.
//  Copyright © 2016 Leonspok. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSOrderedSet (Utilities)

- (NSOrderedSet *)mapWithBlock:(id (^)(id))mapBlock;
- (NSOrderedSet *)filterWithBlock:(BOOL (^)(id))filterBlock;

@end
