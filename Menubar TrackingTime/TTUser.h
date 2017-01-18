//
//  TTUser.h
//  Menubar TrackingTime
//
//  Created by Игорь Савельев on 18/01/2017.
//  Copyright © 2017 MusicSense. All rights reserved.
//

#import "TTDataObject.h"

@interface TTUser : TTDataObject<NSCoding>

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *surname;
@property (nonatomic, strong) NSString *email;
@property (nonatomic, strong) NSNumber *accountUID;

@end
