//
//  TrackingTime.h
//  Menubar TrackingTime
//
//  Created by Игорь Савельев on 18/01/2017.
//  Copyright © 2017 MusicSense. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TTUser.h"
#import "TTTask.h"
#import "TTTrackingEvent.h"

@interface TrackingTimeAPI : NSObject

@property (nonatomic, strong, readonly) NSString *authorizationToken;
@property (nonatomic, strong, readonly) NSString *authedUserEmail;
@property (nonatomic, strong, readonly) TTUser *authedUser;

- (void)checkCredentialsCompletion:(void (^)(BOOL success))completion;

- (void)loginWithEmail:(NSString *)email
			  password:(NSString *)password
			completion:(void (^)(BOOL success))completion;

- (void)logout;

- (void)getListOfUsers:(void (^)(NSArray<TTUser *> *users))success
			   failure:(void (^)(NSError *error))failure;

- (void)getListOfTasksOfUser:(TTUser *)user
					 success:(void (^)(NSArray<TTTask *> *tasks))success
					 failure:(void (^)(NSError *error))failure;

- (void)getListOfTasks:(void (^)(NSArray<TTTask *> *tasks))success
			   failure:(void (^)(NSError *error))failure;

- (void)getTrackingTask:(void (^)(TTTask *task, TTTrackingEvent *event))success
				failure:(void (^)(NSError *error))failure;

- (void)createTaskWithName:(NSString *)taskName
				 inProject:(NSNumber *)projectUID
				   success:(void (^)(TTTask *task))success
				   failure:(void (^)(NSError *error))failure;

- (void)startTrackingTask:(TTTask *)task
				  success:(void (^)(TTTrackingEvent *event))success
				  failure:(void (^)(NSError *error))failure;

- (void)stopTrackingTask:(TTTask *)task
				  atTime:(NSDate *)date
				 success:(void (^)(TTTrackingEvent *event))success
				 failure:(void (^)(NSError *error))failure;

- (void)syncTask:(TTTask *)task
	   withEvent:(TTTrackingEvent *)trackingEvent
		 success:(void (^)(TTTrackingEvent *event))success
		 failure:(void (^)(NSError *error))failure;

@end
