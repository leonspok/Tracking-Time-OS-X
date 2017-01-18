//
//  TTTimeManager.h
//  Menubar TrackingTime
//
//  Created by Игорь Савельев on 18/01/2017.
//  Copyright © 2017 MusicSense. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TrackingTimeAPI.h"

@interface TTTimeManager : NSObject

@property (nonatomic, strong, readonly) TrackingTimeAPI *api;
@property (nonatomic, getter=isReady, readonly) BOOL ready;
@property (nonatomic, getter=isLoading, readonly) BOOL loading;

@property (nonatomic, readonly) TTTrackingEvent *currentTrackingEvent;
@property (nonatomic, readonly) TTTask *currentTrackingTask;

@property (nonatomic, readonly) NSArray<TTTask *> *alltasks;

+ (instancetype)sharedInstance;

- (void)loadAllDataCompletion:(void (^)(BOOL success))completion;

- (void)loadCurrentTrackingInfoCompletion:(void (^)())completion;

- (void)createTaskWithName:(NSString *)taskName
				 inProject:(NSNumber *)projectUID
				   success:(void (^)(TTTask *task))success
				   failure:(void (^)(NSError *error))failure;

- (void)startTracking:(TTTask *)task
			  success:(void (^)())success
			  failure:(void (^)(NSError *error))failure;

- (void)stopTrackingSuccess:(void (^)())success
					failure:(void (^)(NSError *error))failure;

@end
