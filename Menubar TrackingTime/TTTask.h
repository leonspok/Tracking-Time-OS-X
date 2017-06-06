//
//  TTTask.h
//  Menubar TrackingTime
//
//  Created by Игорь Савельев on 18/01/2017.
//  Copyright © 2017 MusicSense. All rights reserved.
//

#import "TTDataObject.h"
#import "TTProject.h"

@interface TTTask : TTDataObject

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) TTProject *project;
@property (nonatomic) NSTimeInterval total;

@end
