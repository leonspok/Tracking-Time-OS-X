//
//  TrackingTime.m
//  Menubar TrackingTime
//
//  Created by Игорь Савельев on 18/01/2017.
//  Copyright © 2017 MusicSense. All rights reserved.
//

#import "TrackingTimeAPI.h"
#import "LPHTTPRequestSerializer.h"
#import "NSArray+Utilities.h"

static NSString *const kBaseURL = @"https://app.trackingtime.co/api/v3";

static NSString *const kAuthTokenUserDefaultsKey = @"auth_token";
static NSString *const kAuthedUserEmailUserDefaultsKey = @"authed_user_email";

@interface TrackingTimeAPI()
@property (nonatomic, strong, readwrite) NSString *authorizationToken;
@property (nonatomic, strong, readwrite) NSString *authedUserEmail;
@property (nonatomic, strong, readwrite) TTUser *authedUser;
@end

@implementation TrackingTimeAPI

- (void)setAuthorizationToken:(NSString *)authorizationToken {
	if (authorizationToken.length != 0) {
		[[NSUserDefaults standardUserDefaults] setObject:authorizationToken forKey:kAuthTokenUserDefaultsKey];
	} else {
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:kAuthTokenUserDefaultsKey];
	}
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)authorizationToken {
	NSString *token = [[NSUserDefaults standardUserDefaults] objectForKey:kAuthTokenUserDefaultsKey];
	return token;
}

- (void)setAuthedUserEmail:(NSString *)authedUserEmail {
	if (authedUserEmail.length != 0) {
		[[NSUserDefaults standardUserDefaults] setObject:authedUserEmail forKey:kAuthedUserEmailUserDefaultsKey];
	} else {
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:kAuthedUserEmailUserDefaultsKey];
	}
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)authedUserEmail {
	return [[NSUserDefaults standardUserDefaults] objectForKey:kAuthedUserEmailUserDefaultsKey];
}

- (NSMutableURLRequest *)requestWithMethod:(NSString *)method url:(NSURL *)url params:(NSDictionary<NSString *, id> *)params {
	NSMutableURLRequest *request = [LPHTTPRequestSerializer requestWithMethod:method url:url params:params];
	if (self.authorizationToken) {
		[request setValue:[NSString stringWithFormat:@"Basic %@", self.authorizationToken] forHTTPHeaderField:@"Authorization"];
	}
	return request;
}

- (void)checkCredentialsCompletion:(void (^)(BOOL success))completion {
	if (!self.authorizationToken) {
		if (completion) {
			completion(NO);
		}
		return;
	}
	
	[self getListOfUsers:^(NSArray<TTUser *> *users) {
		NSArray *filtered = [users filterWithBlock:^BOOL(TTUser *obj) {
			return [obj.email isEqual:self.authedUserEmail];
		}];
		if (filtered.count > 0) {
			self.authedUser = [filtered firstObject];
			if (completion) {
				completion(YES);
			}
		} else {
			self.authedUser = nil;
			self.authedUserEmail = nil;
			self.authorizationToken = nil;
			if (completion) {
				completion(NO);
			}
		}
	} failure:^(NSError *error) {
		if (completion) {
			completion(NO);
		}
	}];
}

- (void)loginWithEmail:(NSString *)email
			  password:(NSString *)password
			completion:(void (^)(BOOL success))completion {
	
	if (email.length == 0 && password.length == 0) {
		if (completion) {
			completion(NO);
		}
		return;
	}
	
	NSString *authString = [NSString stringWithFormat:@"%@:%@", email, password];
	self.authorizationToken = [[authString dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
	self.authedUserEmail = email;
	
	[self getListOfUsers:^(NSArray<TTUser *> *users) {
		NSArray *filtered = [users filterWithBlock:^BOOL(TTUser *obj) {
			return [obj.email isEqual:self.authedUserEmail];
		}];
		if (filtered.count > 0) {
			self.authedUser = [filtered firstObject];
			if (completion) {
				completion(YES);
			}
		} else {
			self.authedUser = nil;
			self.authedUserEmail = nil;
			self.authorizationToken = nil;
			if (completion) {
				completion(NO);
			}
		}
	} failure:^(NSError *error) {
		self.authedUserEmail = nil;
		self.authorizationToken = nil;
		if (completion) {
			completion(NO);
		}
	}];
}

- (void)logout {
	self.authedUserEmail = nil;
	self.authorizationToken = nil;
	self.authedUser = nil;
}

- (void)getTotalTimeForToday:(void (^)(NSTimeInterval total))success
					 failure:(void (^)(NSError *error))failure {
	NSMutableURLRequest *request = [self requestWithMethod:@"GET" url:[NSURL URLWithString:[NSString stringWithFormat:@"%@/dashboard/team_hours", kBaseURL]] params:@{@"filter": @"TODAY"}];
	[[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error) {
			if (failure) {
				failure(error);
			}
		} else {
			NSError *jsonError;
			NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&jsonError];
			if (jsonError) {
				if (failure) {
					failure(jsonError);
				}
			} else {
				if ([[json objectForKey:@"response"] isKindOfClass:NSDictionary.class]) {
					NSDictionary *response = [json objectForKey:@"response"];
					if (![[response objectForKey:@"status"] isEqual:@200]) {
						if (failure) {
							failure([NSError errorWithDomain:NSStringFromClass(self.class) code:[[response objectForKey:@"status"] integerValue] userInfo:response]);
						}
						return;
					}
					
					NSDictionary *userJSON = [[[[json objectForKey:@"data"] objectForKey:@"users"] filterWithBlock:^BOOL(NSDictionary *obj) {
						return [[obj objectForKey:@"id"] isEqual:self.authedUser.uid];
					}] firstObject];
					if (success) {
						success([[userJSON objectForKey:@"worked_hours"] doubleValue]*3600);
					}
				}
			}
		}
	}] resume];
}

- (void)getListOfUsers:(void (^)(NSArray<TTUser *> *users))success
			   failure:(void (^)(NSError *error))failure {
	
	NSMutableURLRequest *request = [self requestWithMethod:@"GET" url:[NSURL URLWithString:[NSString stringWithFormat:@"%@/users", kBaseURL]] params:nil];
	
	[[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error) {
			if (failure) {
				failure(error);
			}
		} else {
			NSError *jsonError;
			NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&jsonError];
			if (jsonError) {
				if (failure) {
					failure(jsonError);
				}
			} else {
				if ([[json objectForKey:@"response"] isKindOfClass:NSDictionary.class]) {
					NSDictionary *response = [json objectForKey:@"response"];
					if (![[response objectForKey:@"status"] isEqual:@200]) {
						if (failure) {
							failure([NSError errorWithDomain:NSStringFromClass(self.class) code:[[response objectForKey:@"status"] integerValue] userInfo:response]);
						}
						return;
					}
					
					if (success) {
						success([TTUser createObjectsFromJSON:[json objectForKey:@"data"]]);
					}
				}
			}
		}
	}] resume];
}

- (void)getListOfProjects:(void (^)(NSArray<TTProject *> *projects))success
				  failure:(void (^)(NSError *error))failure {
	NSMutableURLRequest *request = [self requestWithMethod:@"GET" url:[NSURL URLWithString:[NSString stringWithFormat:@"%@/projects", kBaseURL]] params:nil];
	
	[[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error) {
			if (failure) {
				failure(error);
			}
		} else {
			NSError *jsonError;
			NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&jsonError];
			if (jsonError) {
				if (failure) {
					failure(jsonError);
				}
			} else {
				if ([[json objectForKey:@"response"] isKindOfClass:NSDictionary.class]) {
					NSDictionary *response = [json objectForKey:@"response"];
					if (![[response objectForKey:@"status"] isEqual:@200]) {
						if (failure) {
							failure([NSError errorWithDomain:NSStringFromClass(self.class) code:[[response objectForKey:@"status"] integerValue] userInfo:response]);
						}
						return;
					}
					
					if (success) {
						success([TTProject createObjectsFromJSON:[json objectForKey:@"data"]]);
					}
				}
			}
		}
	}] resume];
}

- (void)getListOfTasksOfUser:(TTUser *)user
					 success:(void (^)(NSArray<TTTask *> *tasks))success
					 failure:(void (^)(NSError *error))failure {
	if (!user.uid) {
		if (failure) {
			failure([NSError errorWithDomain:NSStringFromClass(self.class) code:2 userInfo:@{@"message": @"no user id"}]);
		}
		return;
	}
	
	NSMutableURLRequest *request = [self requestWithMethod:@"GET" url:[NSURL URLWithString:[NSString stringWithFormat:@"%@/users/%@/tasks", kBaseURL, [user.uid stringValue]]] params:@{@"filter": @"ACTIVE"}];
	
	[[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error) {
			if (failure) {
				failure(error);
			}
		} else {
			NSError *jsonError;
			NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&jsonError];
			if (jsonError) {
				if (failure) {
					failure(jsonError);
				}
			} else {
				if ([[json objectForKey:@"response"] isKindOfClass:NSDictionary.class]) {
					NSDictionary *response = [json objectForKey:@"response"];
					if (![[response objectForKey:@"status"] isEqual:@200]) {
						if (failure) {
							failure([NSError errorWithDomain:NSStringFromClass(self.class) code:[[response objectForKey:@"status"] integerValue] userInfo:response]);
						}
						return;
					}
					
					NSArray<NSDictionary *> *projects = [[json objectForKey:@"data"] objectForKey:@"projects"];
					NSMutableArray *tasks = [NSMutableArray array];
					for (NSDictionary *project in projects) {
						if ([[project objectForKey:@"tasks"] isKindOfClass:NSArray.class]) {
							[tasks addObjectsFromArray:[TTTask createObjectsFromJSON:[project objectForKey:@"tasks"]]];
						}
					}
					
					if (success) {
						success(tasks);
					}
				}
			}
		}
	}] resume];
}

- (void)getListOfTasks:(void (^)(NSArray<TTTask *> *tasks))success
			   failure:(void (^)(NSError *error))failure {
	
	NSMutableURLRequest *request = [self requestWithMethod:@"GET" url:[NSURL URLWithString:[NSString stringWithFormat:@"%@/tasks", kBaseURL]] params:@{@"filter": @"ACTIVE"}];
	
	[[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error) {
			if (failure) {
				failure(error);
			}
		} else {
			NSError *jsonError;
			NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&jsonError];
			if (jsonError) {
				if (failure) {
					failure(jsonError);
				}
			} else {
				if ([[json objectForKey:@"response"] isKindOfClass:NSDictionary.class]) {
					NSDictionary *response = [json objectForKey:@"response"];
					if (![[response objectForKey:@"status"] isEqual:@200]) {
						if (failure) {
							failure([NSError errorWithDomain:NSStringFromClass(self.class) code:[[response objectForKey:@"status"] integerValue] userInfo:response]);
						}
						return;
					}
					
					if (success) {
						success([TTTask createObjectsFromJSON:[json objectForKey:@"data"]]);
					}
				}
			}
		}
	}] resume];
}

- (void)getTrackingTask:(void (^)(TTTask *task, TTTrackingEvent *event))success
				failure:(void (^)(NSError *error))failure {
	
	if (!self.authedUser) {
		if (failure) {
			failure([NSError errorWithDomain:NSStringFromClass(self.class) code:1 userInfo:@{@"message": @"no authed user"}]);
		}
		return;
	}
	
	NSMutableURLRequest *request = [self requestWithMethod:@"GET" url:[NSURL URLWithString:[NSString stringWithFormat:@"%@/users/%@/tasks", kBaseURL, [self.authedUser.uid stringValue]]] params:@{@"filter": @"TRACKING"}];
					 
	
	[[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error) {
			if (failure) {
				failure(error);
			}
		} else {
			NSError *jsonError;
			NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&jsonError];
			if (jsonError) {
				if (failure) {
					failure(jsonError);
				}
			} else {
				if ([[json objectForKey:@"response"] isKindOfClass:NSDictionary.class]) {
					NSDictionary *response = [json objectForKey:@"response"];
					if (![[response objectForKey:@"status"] isEqual:@200]) {
						if (failure) {
							failure([NSError errorWithDomain:NSStringFromClass(self.class) code:[[response objectForKey:@"status"] integerValue] userInfo:response]);
						}
						return;
					}
					
					if ([[json objectForKey:@"data"] isKindOfClass:NSDictionary.class]) {
						NSDictionary *data = [json objectForKey:@"data"];
						if ([[data objectForKey:@"projects"] isKindOfClass:NSArray.class]) {
							NSArray *projects = [data objectForKey:@"projects"];
							if (projects.count > 0) {
								NSDictionary *project = nil;;
								for (NSDictionary *p in projects) {
									if ([[p objectForKey:@"tasks"] isKindOfClass:NSArray.class] && [[p objectForKey:@"tasks"] count] > 0) {
										project = p;
										break;
									}
								}
								if (project) {
									NSArray *tasks = [project objectForKey:@"tasks"];
									if (tasks.count > 0) {
										NSDictionary *taskDict = [tasks firstObject];
										TTTask *task = [[TTTask alloc] initWithJSON:taskDict];
										if ([[taskDict objectForKey:@"tracking_event"] isKindOfClass:NSDictionary.class]) {
											TTTrackingEvent *event = [[TTTrackingEvent alloc] initWithJSON:[taskDict objectForKey:@"tracking_event"]];
											if (success) {
												success(task, event);
											}
											return;
										}
									}
								}
							}
						}
					}
					
					if (success) {
						success(nil, nil);
					}
				}
			}
		}
	}] resume];
}

- (void)createTaskWithName:(NSString *)taskName
				 inProject:(NSNumber *)projectUID
				   success:(void (^)(TTTask *task))success
				   failure:(void (^)(NSError *error))failure {
	if (!taskName) {
		if (failure) {
			failure([NSError errorWithDomain:NSStringFromClass(self.class) code:1 userInfo:@{@"message": @"no task name"}]);
		}
		return;
	} else if (!self.authedUser.accountUID) {
		if (failure) {
			failure([NSError errorWithDomain:NSStringFromClass(self.class) code:1 userInfo:@{@"message": @"no account uid"}]);
		}
		return;
	}
	
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@/tasks/add", kBaseURL, self.authedUser.accountUID]];
	
	NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:@{@"name": taskName,
																				  @"user_id": self.authedUser.uid}];
	if (projectUID) {
		[params setObject:projectUID forKey:@"project_id"];
	}
	
	NSURLRequest *request = [self requestWithMethod:@"GET" url:url params:params];
	
	[[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error) {
			if (failure) {
				failure(error);
			}
		} else {
			NSError *jsonError;
			NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&jsonError];
			if (jsonError) {
				if (failure) {
					failure(jsonError);
				}
			} else {
				if ([[json objectForKey:@"response"] isKindOfClass:NSDictionary.class]) {
					NSDictionary *response = [json objectForKey:@"response"];
					if (![[response objectForKey:@"status"] isEqual:@200]) {
						if (failure) {
							failure([NSError errorWithDomain:NSStringFromClass(self.class) code:[[response objectForKey:@"status"] integerValue] userInfo:response]);
						}
						return;
					}
					
					if (success) {
						success([[TTTask alloc] initWithJSON:[json objectForKey:@"data"]]);
					}
				}
			}
		}
	}] resume];
}

- (void)closeTask:(TTTask *)task
		  success:(void (^)())success
		  failure:(void (^)(NSError *error))failure {
	if (!task.uid) {
		if (failure) {
			failure([NSError errorWithDomain:NSStringFromClass(self.class) code:1 userInfo:@{@"message": @"no task"}]);
		}
		return;
	}
	
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/tasks/close/%@", kBaseURL, [task.uid stringValue]]];
	
	NSURLRequest *request = [self requestWithMethod:@"GET" url:url params:nil];
	[[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error) {
			if (failure) {
				failure(error);
			}
		} else {
			NSError *jsonError;
			NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&jsonError];
			if (jsonError) {
				if (failure) {
					failure(jsonError);
				}
			} else {
				if ([[json objectForKey:@"response"] isKindOfClass:NSDictionary.class]) {
					NSDictionary *response = [json objectForKey:@"response"];
					if (![[response objectForKey:@"status"] isEqual:@200]) {
						if (failure) {
							failure([NSError errorWithDomain:NSStringFromClass(self.class) code:[[response objectForKey:@"status"] integerValue] userInfo:response]);
						}
						return;
					}
					
					if (success) {
						success();
					}
				}
			}
		}
	}] resume];
}

- (void)renameTask:(TTTask *)task
				to:(NSString *)newName
		   success:(void (^)())success
		   failure:(void (^)(NSError *error))failure {
	if (!task.uid) {
		if (failure) {
			failure([NSError errorWithDomain:NSStringFromClass(self.class) code:1 userInfo:@{@"message": @"no task"}]);
		}
		return;
	}
	
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/tasks/update/%@", kBaseURL, [task.uid stringValue]]];
	
	NSDictionary *params = @{@"id": task.uid,
							 @"name": newName};
	
	NSURLRequest *request = [self requestWithMethod:@"GET" url:url params:params];
	[[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error) {
			if (failure) {
				failure(error);
			}
		} else {
			NSError *jsonError;
			NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&jsonError];
			if (jsonError) {
				if (failure) {
					failure(jsonError);
				}
			} else {
				if ([[json objectForKey:@"response"] isKindOfClass:NSDictionary.class]) {
					NSDictionary *response = [json objectForKey:@"response"];
					if (![[response objectForKey:@"status"] isEqual:@200]) {
						if (failure) {
							failure([NSError errorWithDomain:NSStringFromClass(self.class) code:[[response objectForKey:@"status"] integerValue] userInfo:response]);
						}
						return;
					}
					task.name = newName;
					if (success) {
						success();
					}
				}
			}
		}
	}] resume];
}

- (void)deleteTask:(TTTask *)task
		   success:(void (^)())success
		   failure:(void (^)(NSError *error))failure {
	if (!task.uid) {
		if (failure) {
			failure([NSError errorWithDomain:NSStringFromClass(self.class) code:1 userInfo:@{@"message": @"no task"}]);
		}
		return;
	}
	
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/tasks/delete/%@", kBaseURL, [task.uid stringValue]]];
	
	NSURLRequest *request = [self requestWithMethod:@"GET" url:url params:nil];
	[[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error) {
			if (failure) {
				failure(error);
			}
		} else {
			NSError *jsonError;
			NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&jsonError];
			if (jsonError) {
				if (failure) {
					failure(jsonError);
				}
			} else {
				if ([[json objectForKey:@"response"] isKindOfClass:NSDictionary.class]) {
					NSDictionary *response = [json objectForKey:@"response"];
					if (![[response objectForKey:@"status"] isEqual:@200]) {
						if (failure) {
							failure([NSError errorWithDomain:NSStringFromClass(self.class) code:[[response objectForKey:@"status"] integerValue] userInfo:response]);
						}
						return;
					}
					
					if (success) {
						success();
					}
				}
			}
		}
	}] resume];
}

- (void)startTrackingTask:(TTTask *)task
				  success:(void (^)(TTTrackingEvent *event))success
				  failure:(void (^)(NSError *error))failure {
	
	if (!task.uid) {
		if (failure) {
			failure([NSError errorWithDomain:NSStringFromClass(self.class) code:1 userInfo:@{@"message": @"no task"}]);
		}
		return;
	}
	
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/tasks/track/%@", kBaseURL, [task.uid stringValue]]];
	
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
	
	NSString *date = [dateFormatter stringFromDate:[NSDate date]];
	dateFormatter.dateFormat = @"XXX";
	NSString *timezone = [[NSString stringWithFormat:@"GMT%@", [dateFormatter stringFromDate:[NSDate date]]] stringByReplacingOccurrencesOfString:@"+" withString:@" "];
	
	NSDictionary *params = @{@"date": date,
							 @"timezone": timezone,
							 @"stop_running_task": @YES};
	
	NSURLRequest *request = [self requestWithMethod:@"GET" url:url params:params];
	
	[[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error) {
			if (failure) {
				failure(error);
			}
		} else {
			NSError *jsonError;
			NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&jsonError];
			if (jsonError) {
				if (failure) {
					failure(jsonError);
				}
			} else {
				if ([[json objectForKey:@"response"] isKindOfClass:NSDictionary.class]) {
					NSDictionary *response = [json objectForKey:@"response"];
					if (![[response objectForKey:@"status"] isEqual:@200]) {
						if (failure) {
							failure([NSError errorWithDomain:NSStringFromClass(self.class) code:[[response objectForKey:@"status"] integerValue] userInfo:response]);
						}
						return;
					}
					
					if (success) {
						success([[TTTrackingEvent alloc] initWithJSON:[json objectForKey:@"data"]]);
					}
				}
			}
		}
	}] resume];
}

- (void)stopTrackingTask:(TTTask *)task
				  atTime:(NSDate *)stopDate
				 success:(void (^)(TTTrackingEvent *event))success
				 failure:(void (^)(NSError *error))failure {
	if (!task.uid) {
		if (failure) {
			failure([NSError errorWithDomain:NSStringFromClass(self.class) code:1 userInfo:@{@"message": @"no task"}]);
		}
		return;
	}
	
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/tasks/stop/%@", kBaseURL, [task.uid stringValue]]];
	
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
	NSString *date = [dateFormatter stringFromDate:stopDate];
	
	dateFormatter.dateFormat = @"XXX";
	NSString *timezone = [[NSString stringWithFormat:@"GMT%@", [dateFormatter stringFromDate:stopDate]] stringByReplacingOccurrencesOfString:@"+" withString:@" "];
	
	NSDictionary *params = @{@"date": date,
							 @"timezone": timezone};
	
	NSURLRequest *request = [self requestWithMethod:@"GET" url:url params:params];
	
	[[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error) {
			if (failure) {
				failure(error);
			}
		} else {
			NSError *jsonError;
			NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&jsonError];
			if (jsonError) {
				if (failure) {
					failure(jsonError);
				}
			} else {
				if ([[json objectForKey:@"response"] isKindOfClass:NSDictionary.class]) {
					NSDictionary *response = [json objectForKey:@"response"];
					if (![[response objectForKey:@"status"] isEqual:@200]) {
						if (failure) {
							failure([NSError errorWithDomain:NSStringFromClass(self.class) code:[[response objectForKey:@"status"] integerValue] userInfo:response]);
						}
						return;
					}
					
					if (success) {
						success([[TTTrackingEvent alloc] initWithJSON:[json objectForKey:@"data"]]);
					}
				}
			}
		}
	}] resume];
}

- (void)syncTask:(TTTask *)task
	   withEvent:(TTTrackingEvent *)trackingEvent
		 success:(void (^)(TTTrackingEvent *event))success
		 failure:(void (^)(NSError *error))failure {
	if (!task.uid || !trackingEvent.uid) {
		if (failure) {
			failure([NSError errorWithDomain:NSStringFromClass(self.class) code:1 userInfo:@{@"message": @"no task or tracking event"}]);
		}
		return;
	}
	
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/tasks/sync/%@", kBaseURL, [task.uid stringValue]]];
	
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
	
	NSString *date = [dateFormatter stringFromDate:[NSDate date]];
	dateFormatter.dateFormat = @"XXX";
	NSString *timezone = [[NSString stringWithFormat:@"GMT%@", [dateFormatter stringFromDate:[NSDate date]]] stringByReplacingOccurrencesOfString:@"+" withString:@" "];
	
	NSDictionary *params = @{@"date": date,
							 @"timezone": timezone,
							 @"event_id": trackingEvent.uid};
	
	NSURLRequest *request = [self requestWithMethod:@"GET" url:url params:params];
	
	[[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error) {
			if (failure) {
				failure(error);
			}
		} else {
			NSError *jsonError;
			NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&jsonError];
			if (jsonError) {
				if (failure) {
					failure(jsonError);
				}
			} else {
				if ([[json objectForKey:@"response"] isKindOfClass:NSDictionary.class]) {
					NSDictionary *response = [json objectForKey:@"response"];
					if (![[response objectForKey:@"status"] isEqual:@200]) {
						if (failure) {
							failure([NSError errorWithDomain:NSStringFromClass(self.class) code:[[response objectForKey:@"status"] integerValue] userInfo:response]);
						}
						return;
					}
					
					if (success) {
						success([[TTTrackingEvent alloc] initWithJSON:[json objectForKey:@"data"]]);
					}
				}
			}
		}
	}] resume];
}

@end
