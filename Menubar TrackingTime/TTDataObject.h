//
//  TTDataObject.h
//  Menubar TrackingTime
//
//  Created by Игорь Савельев on 18/01/2017.
//  Copyright © 2017 MusicSense. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LPJSONConvertable.h"

@interface TTDataObject : NSObject<LPJSONConvertable>

@property (nonatomic, strong) NSNumber *uid;

@end
