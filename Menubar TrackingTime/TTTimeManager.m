//
//  TTTimeManager.m
//  Menubar TrackingTime
//
//  Created by Игорь Савельев on 18/01/2017.
//  Copyright © 2017 MusicSense. All rights reserved.
//

#import "TTTimeManager.h"

@interface TTTimeManager()
@property (nonatomic, strong, readwrite) TrackingTimeAPI *api;
@property (nonatomic, getter=isReady, readwrite) BOOL ready;
@property (nonatomic, getter=isLoading, readwrite) BOOL loading;
@property (nonatomic, strong, readwrite) NSDate *lastSyncTimerDate;

@property (nonatomic, readwrite) TTTrackingEvent *currentTrackingEvent;
@property (nonatomic, readwrite) TTTask *currentTrackingTask;

@property (nonatomic, readwrite) NSArray<TTTask *> *alltasks;
@property (nonatomic, readwrite) NSArray<TTProject *> *allProjects;
@property (nonatomic, readwrite) NSTimeInterval totalTimeToday;

@property (nonatomic, strong) NSTimer *syncTimer;

@end

@implementation TTTimeManager

+ (instancetype)sharedInstance {
	static TTTimeManager *__sharedInstance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		__sharedInstance = [[TTTimeManager alloc] init];
	});
	return __sharedInstance;
}

- (id)init {
	self = [super init];
	if (self) {
		self.ready = NO;
		self.api = [[TrackingTimeAPI alloc] init];
	}
	return self;
}

- (void)loadAllDataCompletion:(void (^)(BOOL success))completion {
	self.ready = NO;
	self.loading = YES;
	[self.api checkCredentialsCompletion:^(BOOL success) {
		if (!success) {
			self.currentTrackingEvent = nil;
			self.currentTrackingTask = nil;
			self.lastSyncTimerDate = nil;
			self.ready = YES;
			self.loading = NO;
			if (completion) {
				completion(YES);
			}
		} else {
			NSMutableArray<NSNumber *> *loadedStates = [NSMutableArray arrayWithObjects:@0, @0, @0, @0, nil];
			
			void (^callCompletionIfNeeded)() = ^{
				BOOL success = YES;
				for (NSNumber *state in loadedStates) {
					if ([state integerValue] == 0) {
						return;
					}
					success *= ([state integerValue] == 1);
				}
				self.ready = YES;
				self.loading = NO;
				if (completion) {
					completion(success);
				}
			};
			
			[self.api getListOfTasksOfUser:self.api.authedUser success:^(NSArray<TTTask *> *tasks) {
				self.alltasks = tasks;
				loadedStates[0] = @1;
				callCompletionIfNeeded();
			} failure:^(NSError *error) {
				loadedStates[0] = @(-1);
				callCompletionIfNeeded();
			}];
			
			[self.api getTrackingTask:^(TTTask *task, TTTrackingEvent *event) {
				self.currentTrackingEvent = event;
				self.currentTrackingTask = task;
				loadedStates[1] = @1;
				callCompletionIfNeeded();
			} failure:^(NSError *error) {
				loadedStates[1] = @(-1);
				callCompletionIfNeeded();
			}];
			
			[self.api getListOfProjects:^(NSArray<TTProject *> *projects) {
				self.allProjects = projects;
				loadedStates[2] = @1;
				callCompletionIfNeeded();
			} failure:^(NSError *error) {
				loadedStates[2] = @(-1);
				callCompletionIfNeeded();
			}];
			
			[self.api getTotalTimeForToday:^(NSTimeInterval total) {
				self.totalTimeToday = total;
				loadedStates[3] = @1;
				callCompletionIfNeeded();
			} failure:^(NSError *error) {
				loadedStates[3] = @(-1);
				callCompletionIfNeeded();
			}];
		}
	}];
}

- (void)loadCurrentTrackingInfoCompletion:(void (^)())completion {
	NSMutableArray<NSNumber *> *loadedStates = [NSMutableArray arrayWithObjects:@0, @0, nil];
	void (^callCompletionIfNeeded)() = ^{
		for (NSNumber *state in loadedStates) {
			if ([state integerValue] == 0) {
				return;
			}
		}
		if (completion) {
			completion();
		}
	};
	
	[self.api getTrackingTask:^(TTTask *task, TTTrackingEvent *event) {
		self.currentTrackingEvent = event;
		self.currentTrackingTask = task;
		loadedStates[0] = @1;
		callCompletionIfNeeded();
	} failure:^(NSError *error) {
		loadedStates[0] = @(-1);
		callCompletionIfNeeded();
	}];
	
	[self.api getTotalTimeForToday:^(NSTimeInterval total) {
		self.totalTimeToday = total;
		loadedStates[1] = @1;
		callCompletionIfNeeded();
	} failure:^(NSError *error) {
		loadedStates[1] = @(-1);
		callCompletionIfNeeded();
	}];
}

- (void)createTaskWithName:(NSString *)taskName
				 inProject:(NSNumber *)projectUID
				   success:(void (^)(TTTask *task))success
				   failure:(void (^)(NSError *error))failure {
	[self.api createTaskWithName:taskName inProject:projectUID success:^(TTTask *task) {
		if (task) {
			self.alltasks = [self.alltasks arrayByAddingObject:task];
		}
		if (success) {
			success(task);
		}
	} failure:failure];
}

- (void)startTracking:(TTTask *)task
			  success:(void (^)())success
			  failure:(void (^)(NSError *error))failure {
	[self.api startTrackingTask:task success:^(TTTrackingEvent *event) {
		self.currentTrackingTask = task;
		self.currentTrackingEvent = event;
		self.lastSyncTimerDate = [NSDate date];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			if (self.syncTimer) {
				[self.syncTimer invalidate];
				self.syncTimer = nil;
			}
			self.syncTimer = [NSTimer scheduledTimerWithTimeInterval:60 target:self selector:@selector(syncWithServer) userInfo:nil repeats:YES];
		});
		
		if (success) {
			success();
		}
	} failure:failure];
}

- (void)syncWithServer {
	if (self.currentTrackingTask && self.currentTrackingEvent) {
		[self.api syncTask:self.currentTrackingTask withEvent:self.currentTrackingEvent success:^(TTTrackingEvent *event) {
			self.currentTrackingEvent = event;
			self.lastSyncTimerDate = [NSDate date];
		} failure:nil];
	}
}

- (void)closeTask:(TTTask *)task
		  success:(void (^)())success
		  failure:(void (^)(NSError *error))failure {
	[self.api closeTask:task success:^{
		if ([task isEqual:self.currentTrackingTask]) {
			self.currentTrackingTask = nil;
			self.currentTrackingEvent = nil;
			self.lastSyncTimerDate = nil;
		}
		dispatch_async(dispatch_get_main_queue(), ^{
			if (self.syncTimer) {
				[self.syncTimer invalidate];
				self.syncTimer = nil;
			}
		});
		NSMutableArray<TTTask *> *tasks = [self.alltasks mutableCopy];
		[tasks removeObject:task];
		self.alltasks = tasks;
		if (success) {
			success();
		}
	} failure:failure];
}

- (void)renameTask:(TTTask *)task
				to:(NSString *)newName
		   success:(void (^)())success
		   failure:(void (^)(NSError *error))failure {
	[self.api renameTask:task to:newName success:success failure:failure];
}

- (void)deleteTask:(TTTask *)task
		   success:(void (^)())success
		   failure:(void (^)(NSError *error))failure {
	[self.api deleteTask:task success:^{
		if ([task isEqual:self.currentTrackingTask]) {
			self.currentTrackingTask = nil;
			self.currentTrackingEvent = nil;
			self.lastSyncTimerDate = nil;
		}
		dispatch_async(dispatch_get_main_queue(), ^{
			if (self.syncTimer) {
				[self.syncTimer invalidate];
				self.syncTimer = nil;
			}
		});
		NSMutableArray<TTTask *> *tasks = [self.alltasks mutableCopy];
		[tasks removeObject:task];
		self.alltasks = tasks;
		if (success) {
			success();
		}
	} failure:failure];
}

- (void)stopTrackingAtTime:(NSDate *)time
				   success:(void (^)())success
				   failure:(void (^)(NSError *error))failure {
	if (!self.currentTrackingTask) {
		if (success) {
			success();
		}
	}
	[self.api stopTrackingTask:self.currentTrackingTask atTime:time success:^(TTTrackingEvent *event) {
		self.currentTrackingTask = nil;
		self.currentTrackingEvent = nil;
		self.lastSyncTimerDate = nil;
		dispatch_async(dispatch_get_main_queue(), ^{
			if (self.syncTimer) {
				[self.syncTimer invalidate];
				self.syncTimer = nil;
			}
		});
		if (success) {
			success();
		}
	} failure:failure];
}

- (void)stopTrackingSuccess:(void (^)())success
					failure:(void (^)(NSError *error))failure {
	[self stopTrackingAtTime:[NSDate date] success:success failure:failure];
}

@end
