//
//  AppDelegate.m
//  Menubar TrackingTime
//
//  Created by Игорь Савельев on 18/01/2017.
//  Copyright © 2017 MusicSense. All rights reserved.
//

#import "AppDelegate.h"
#import "TTTimeManager.h"
#import "NSArray+Utilities.h"
#import "GithubAPI.h"

@interface AppDelegate () <NSMenuDelegate, NSUserNotificationCenterDelegate>

@property (nonatomic, strong) GithubAPI *githubAPI;

@property (strong, nonatomic) NSStatusItem *statusItem;
@property (weak) IBOutlet NSMenu *dummyEditMenu;

@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSMenu *menu;
@property (weak) IBOutlet NSView *loginView;
@property (weak) IBOutlet NSTextField *emailTextField;
@property (weak) IBOutlet NSSecureTextField *passwordTextField;
@property (weak) IBOutlet NSTextField *taskNameTextField;

@property (nonatomic, weak) NSMenuItem *trackingInfoItem;
@property (nonatomic, weak) NSMenuItem *totalInfoItem;
@property (nonatomic, strong) NSTimer *trackingInfoTimer;
@property (nonatomic, strong) NSTimer *reloadInfoTimer;
@property (nonatomic, strong) NSTimer *reloadTrackingInfoTimer;

@property (nonatomic) BOOL sleeping;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	self.menu.delegate = self;
	self.sleeping = NO;
	[NSApp setMainMenu:self.dummyEditMenu];
	
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
														   selector:@selector(applicationDidWakeUp)
															   name:NSWorkspaceDidWakeNotification object:nil];
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
														   selector:@selector(applicationWillSleep)
															   name:NSWorkspaceWillSleepNotification object:nil];
	
	self.githubAPI = [GithubAPI new];
	
	self.trackingInfoTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(setTrackingInfo) userInfo:nil repeats:YES];
	[[NSRunLoop mainRunLoop] addTimer:self.trackingInfoTimer forMode:NSEventTrackingRunLoopMode];
	self.reloadInfoTimer = [NSTimer scheduledTimerWithTimeInterval:3*60.0f target:self selector:@selector(reloadInfo) userInfo:nil repeats:YES];
	[[NSRunLoop mainRunLoop] addTimer:self.reloadInfoTimer forMode:NSEventTrackingRunLoopMode];
	self.reloadTrackingInfoTimer = [NSTimer scheduledTimerWithTimeInterval:10.0f target:self selector:@selector(reloadCurrentTrackingTask) userInfo:nil repeats:YES];
	[[NSRunLoop mainRunLoop] addTimer:self.reloadTrackingInfoTimer forMode:NSEventTrackingRunLoopMode];
	
	[self checkVersion];
	
	[[TTTimeManager sharedInstance] loadAllDataCompletion:^(BOOL success) {
		dispatch_async(dispatch_get_main_queue(), ^{
			self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
			self.statusItem.title = @"";
			NSImage *menuBarLogo = [NSImage imageNamed:@"startIcon"];
			[menuBarLogo setTemplate:YES];
			self.statusItem.image = menuBarLogo;
			self.statusItem.toolTip = @"TrackingTime";
			self.statusItem.menu = self.menu;
		});
	}];
}

- (void)applicationDidWakeUp {
	self.sleeping = NO;
	[self stopTrackingIfNeeded];
}

- (void)applicationWillSleep {
	self.sleeping = YES;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
	[[TTTimeManager sharedInstance] stopTrackingSuccess:nil failure:nil];
}

#pragma mark Info

- (void)checkVersion {
	[self.githubAPI getLatestVersionSuccess:^(NSString *version, NSURL *url, NSURL *downloadURL) {
		NSString *currentVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
		if ([version compare:currentVersion options:NSNumericSearch] == NSOrderedDescending) {
			dispatch_async(dispatch_get_main_queue(), ^{
				NSAlert *alert = [NSAlert new];
				[alert setMessageText:@"New version is available"];
				[alert setInformativeText:[NSString stringWithFormat:@"Your version is %@. Now latest version is %@.", currentVersion, version]];
				[alert addButtonWithTitle:@"Download"];
				[alert addButtonWithTitle:@"Open on GitHub"];
				[alert addButtonWithTitle:@"Cancel"];
				[alert setAlertStyle:NSAlertStyleWarning];
				NSInteger response = [alert runModal];
				switch (response) {
					case 1000:
						[[NSWorkspace sharedWorkspace] openURL:downloadURL];
						break;
					case 1001:
						[[NSWorkspace sharedWorkspace] openURL:url];
						break;
					default:
						break;
				}
			});
		}
	} failure:nil];
}

- (void)reloadCurrentTrackingTask {
	BOOL wasTracking = [TTTimeManager sharedInstance].currentTrackingEvent != nil;
	NSString *wasTrackingTask = [TTTimeManager sharedInstance].currentTrackingTask.name;
	[[TTTimeManager sharedInstance] loadCurrentTrackingInfoCompletion:^{
		dispatch_async(dispatch_get_main_queue(), ^{
			if (!wasTracking && [TTTimeManager sharedInstance].currentTrackingEvent) {
				NSUserNotification *notification = [[NSUserNotification alloc] init];
				notification.title = [TTTimeManager sharedInstance].currentTrackingTask.name;
				notification.informativeText = @"Started tracking";
				[self postNotification:notification];
			} else if (wasTracking && [TTTimeManager sharedInstance].currentTrackingEvent == nil) {
				NSUserNotification *notification = [[NSUserNotification alloc] init];
				notification.title = wasTrackingTask;
				notification.informativeText = @"Stopped tracking";
				[self postNotification:notification];
			}
		});
	}];
}

- (void)reloadInfo {
	BOOL wasTracking = [TTTimeManager sharedInstance].currentTrackingEvent != nil;
	NSString *wasTrackingTask = [TTTimeManager sharedInstance].currentTrackingTask.name;
	[[TTTimeManager sharedInstance] loadAllDataCompletion:^(BOOL success) {
		if (success) {
			dispatch_async(dispatch_get_main_queue(), ^{
				if (!wasTracking && [TTTimeManager sharedInstance].currentTrackingEvent) {
					NSUserNotification *notification = [[NSUserNotification alloc] init];
					notification.title = [TTTimeManager sharedInstance].currentTrackingTask.name;
					notification.informativeText = @"Started tracking";
					[self postNotification:notification];
				} else if (wasTracking && [TTTimeManager sharedInstance].currentTrackingEvent == nil) {
					NSUserNotification *notification = [[NSUserNotification alloc] init];
					notification.title = wasTrackingTask;
					notification.informativeText = @"Stopped tracking";
					[self postNotification:notification];
				}
			});
		}
	}];
}

- (void)setTrackingInfo {
	[self stopTrackingIfNeeded];
	if ([TTTimeManager sharedInstance].currentTrackingEvent) {
		NSInteger currentTrackingSeconds = round([[NSDate date] timeIntervalSinceDate:[TTTimeManager sharedInstance].currentTrackingEvent.dateStart]);
		NSInteger taskTotalSeconds = round([TTTimeManager sharedInstance].currentTrackingTask.total);
		self.trackingInfoItem.title = [NSString stringWithFormat:@"Time: %02d:%02d:%02d (total %02d:%02d)", (int)currentTrackingSeconds/3600, (int)(currentTrackingSeconds%3600)/60, (int)currentTrackingSeconds%60, (int)taskTotalSeconds/3600, (int)(taskTotalSeconds%3600)/60];
		NSInteger totalTodaySeconds = round([TTTimeManager sharedInstance].totalTimeToday);
		self.totalInfoItem.title = [NSString stringWithFormat:@"Today: %02d:%02d", (int)totalTodaySeconds/3600, (int)(totalTodaySeconds%3600)/60];
		
		NSImage *menuBarLogo = [NSImage imageNamed:@"stopIcon"];
		[menuBarLogo setTemplate:YES];
		self.statusItem.image = menuBarLogo;
		if (currentTrackingSeconds < 60) {
			self.statusItem.title = [NSString stringWithFormat:@"%lds", (long)currentTrackingSeconds];
		} else if (currentTrackingSeconds < 3600) {
			self.statusItem.title = [NSString stringWithFormat:@"%ldm", (long)currentTrackingSeconds/60];
		} else {
			self.statusItem.title = [NSString stringWithFormat:@"%ldh%ldm", (long)currentTrackingSeconds/3600, (long)(currentTrackingSeconds%3600)/60];
		}
	} else {
		self.trackingInfoItem.title = @"No tracking";
		NSInteger totalTodaySeconds = round([TTTimeManager sharedInstance].totalTimeToday);
		self.totalInfoItem.title = [NSString stringWithFormat:@"%02d:%02d:%02d", (int)totalTodaySeconds/3600, (int)(totalTodaySeconds%3600)/60, (int)totalTodaySeconds%60];
		
		NSImage *menuBarLogo = [NSImage imageNamed:@"startIcon"];
		[menuBarLogo setTemplate:YES];
		self.statusItem.image = menuBarLogo;
		self.statusItem.title = nil;
	}
}

- (void)stopTrackingIfNeeded {
	NSDate *lastSyncDate = [TTTimeManager sharedInstance].lastSyncTimerDate;
	NSString *wasTrackingTask = [TTTimeManager sharedInstance].currentTrackingTask.name;
	if (wasTrackingTask && lastSyncDate && [[NSDate date] timeIntervalSinceDate:lastSyncDate] >= 3600) {
		NSLog(@"Stopping: %@", lastSyncDate);
		[[TTTimeManager sharedInstance] stopTrackingAtTime:lastSyncDate success:^{
			dispatch_async(dispatch_get_main_queue(), ^{
				[self setTrackingInfo];
				NSUserNotification *notification = [[NSUserNotification alloc] init];
				notification.title = wasTrackingTask;
				notification.informativeText = @"Tracking stopped";
				[self postNotification:notification];
			});
		} failure:^(NSError *error) {
			NSLog(@"%@", error);
		}];
	}
}

#pragma mark Actions

- (void)postNotification:(NSUserNotification *)notification {
	if (!self.sleeping) {
		[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
	}
}

- (IBAction)logIn:(id)sender {
	NSAlert *alert = [[NSAlert alloc] init];
	alert.alertStyle = NSAlertStyleInformational;
	[alert setMessageText:@"Log in"];
	[alert setInformativeText:@"Please enter email and password for your TrackingTime account"];
	[alert addButtonWithTitle:@"Log in"];
	[alert addButtonWithTitle:@"Cancel"];
	[alert setAccessoryView:self.loginView];
	self.emailTextField.stringValue = @"";
	self.passwordTextField.stringValue = @"";
	NSInteger button = [alert runModal];
	if (button == NSAlertFirstButtonReturn) {
		[[TTTimeManager sharedInstance].api loginWithEmail:self.emailTextField.stringValue password:self.passwordTextField.stringValue completion:^(BOOL success) {
			if (success) {
				dispatch_async(dispatch_get_main_queue(), ^{
					NSUserNotification *notification = [[NSUserNotification alloc] init];
					notification.title = @"You are logged in";
					notification.informativeText = [NSString stringWithFormat:@"%@ %@", [TTTimeManager sharedInstance].api.authedUser.name, [TTTimeManager sharedInstance].api.authedUser.surname];
					[self postNotification:notification];
				});
				[[TTTimeManager sharedInstance] loadAllDataCompletion:^(BOOL success) {
					if (success) {
						dispatch_async(dispatch_get_main_queue(), ^{
							NSUserNotification *notification = [[NSUserNotification alloc] init];
							notification.title = @"TrackingTime is ready";
							[self postNotification:notification];
						});
					} 
				}];
			} else {
				dispatch_async(dispatch_get_main_queue(), ^{
					NSUserNotification *notification = [[NSUserNotification alloc] init];
					notification.title = @"Log in failed";
					[self postNotification:notification];
				});
			}
		}];
	}
}

- (IBAction)logOut:(id)sender {
	[[TTTimeManager sharedInstance] stopTrackingSuccess:^{
		[[TTTimeManager sharedInstance].api logout];
	} failure:^(NSError *error) {
		[[TTTimeManager sharedInstance].api logout];
	}];
}

- (IBAction)stopTracking:(id)sender {
	NSString *wasTrackingTask = [TTTimeManager sharedInstance].currentTrackingTask.name;
	[[TTTimeManager sharedInstance] stopTrackingSuccess:^{
		dispatch_async(dispatch_get_main_queue(), ^{
			[self setTrackingInfo];
			NSUserNotification *notification = [[NSUserNotification alloc] init];
			notification.title = wasTrackingTask;
			notification.informativeText = @"Tracking stopped";
			[self postNotification:notification];
		});
	} failure:^(NSError *error) {
		dispatch_async(dispatch_get_main_queue(), ^{
			[self setTrackingInfo];
			NSAlert *alert = [[NSAlert alloc] init];
			alert.alertStyle = NSAlertStyleWarning;
			[alert setMessageText:@"Error"];
			[alert setInformativeText:@"Can't stop tracking"];
			[alert addButtonWithTitle:@"Try again"];
			[alert addButtonWithTitle:@"Cancel"];
			if ([alert runModal] == NSAlertFirstButtonReturn) {
				[self stopTracking:sender];
			}
		});
	}];
}

- (IBAction)startTracking:(NSMenuItem *)sender {
	TTTask *task = sender.representedObject;
	[[TTTimeManager sharedInstance] startTracking:task success:^{
		dispatch_async(dispatch_get_main_queue(), ^{
			NSUserNotification *notification = [[NSUserNotification alloc] init];
			notification.informativeText = @"Started tracking";
			notification.title = task.name;
			[self postNotification:notification];
		});
	} failure:^(NSError *error) {
		dispatch_async(dispatch_get_main_queue(), ^{
			NSAlert *alert = [[NSAlert alloc] init];
			alert.alertStyle = NSAlertStyleWarning;
			[alert setMessageText:@"Error"];
			[alert setInformativeText:@"Can't start tracking"];
			[alert addButtonWithTitle:@"Try again"];
			[alert addButtonWithTitle:@"Cancel"];
			if ([alert runModal] == 0) {
				[self startTracking:sender];
			}
		});
	}];
}

- (IBAction)createNewTask:(NSMenuItem *)sender {
	NSAlert *alert = [[NSAlert alloc] init];
	alert.alertStyle = NSAlertStyleInformational;
	[alert setMessageText:@"Create task"];
	[alert setInformativeText:@"Enter name for new task:"];
	self.taskNameTextField.stringValue = @"";
	[alert setAccessoryView:self.taskNameTextField];
	[alert addButtonWithTitle:@"Create and start"];
	[alert addButtonWithTitle:@"Only create"];
	[alert addButtonWithTitle:@"Cancel"];
	
	TTProject *project = sender.representedObject;
	NSNumber *projectUID = nil;
	if (![project.uid isEqual:@(INT_MAX)]) {
		projectUID = project.uid;
	}
	
	NSModalResponse button = [alert runModal];
	if (button == NSAlertFirstButtonReturn) {
		[[TTTimeManager sharedInstance] createTaskWithName:self.taskNameTextField.stringValue inProject:projectUID success:^(TTTask *task) {
			[[TTTimeManager sharedInstance] startTracking:task success:^{
				dispatch_async(dispatch_get_main_queue(), ^{
					NSUserNotification *notification = [[NSUserNotification alloc] init];
					notification.informativeText = @"Started tracking";
					notification.title = task.name;
					[self postNotification:notification];
				});
			} failure:^(NSError *error) {
				dispatch_async(dispatch_get_main_queue(), ^{
					NSAlert *alert = [[NSAlert alloc] init];
					alert.alertStyle = NSAlertStyleWarning;
					[alert setMessageText:@"Error"];
					[alert setInformativeText:@"Can't start tracking"];
					[alert addButtonWithTitle:@"OK"];
					[alert runModal];
				});
			}];
		} failure:^(NSError *error) {
			dispatch_async(dispatch_get_main_queue(), ^{
				NSAlert *alert = [[NSAlert alloc] init];
				alert.alertStyle = NSAlertStyleWarning;
				[alert setMessageText:@"Error"];
				[alert setInformativeText:@"Can't create task"];
				[alert addButtonWithTitle:@"OK"];
				[alert runModal];
			});
		}];
	} else if (button == NSAlertSecondButtonReturn) {
		[[TTTimeManager sharedInstance] createTaskWithName:self.taskNameTextField.stringValue inProject:projectUID success:^(TTTask *task) {
			dispatch_async(dispatch_get_main_queue(), ^{
				NSUserNotification *notification = [[NSUserNotification alloc] init];
				notification.informativeText = @"Task created";
				notification.title = task.name;
				[self postNotification:notification];
			});
		} failure:^(NSError *error) {
			dispatch_async(dispatch_get_main_queue(), ^{
				NSAlert *alert = [[NSAlert alloc] init];
				alert.alertStyle = NSAlertStyleWarning;
				[alert setMessageText:@"Error"];
				[alert setInformativeText:@"Can't create task"];
				[alert addButtonWithTitle:@"OK"];
				[alert runModal];
			});
		}];
	}
}

- (IBAction)quit:(id)sender {
	[[TTTimeManager sharedInstance] stopTrackingSuccess:^{
		[NSApp terminate:nil];
	} failure:^(NSError *error) {
		[NSApp terminate:nil];
	}];
}

#pragma mark NSMenuDelegate

- (void)menuNeedsUpdate:(NSMenu *)menu {
	[self.menu removeAllItems];
	[self.menu setAutoenablesItems:NO];
	
	if (![[TTTimeManager sharedInstance] isReady]) {
		if (![[TTTimeManager sharedInstance] isLoading]) {
			NSMenuItem *item = [NSMenuItem new];
			item.title = @"Not ready yet...";
			item.enabled = NO;
			[self.menu addItem:item];
			[[TTTimeManager sharedInstance] loadAllDataCompletion:^(BOOL success) {
				if (success) {
					dispatch_async(dispatch_get_main_queue(), ^{
						NSUserNotification *notification = [[NSUserNotification alloc] init];
						notification.title = @"TrackingTime is ready";
						notification.informativeText = @"You can start tracking your tasks";
						[self postNotification:notification];
					});
				}
			}];
		} else {
			NSMenuItem *item = [NSMenuItem new];
			item.title = @"Loading...";
			item.enabled = NO;
			[self.menu addItem:item];
		}
		
		[self.menu addItem:[NSMenuItem separatorItem]];
	} else if ([[TTTimeManager sharedInstance].api authedUser] == nil) {
		NSMenuItem *item = [NSMenuItem new];
		item.title = @"You are not logged in";
		item.enabled = NO;
		[self.menu addItem:item];
		
		NSMenuItem *logInItem = [NSMenuItem new];
		logInItem.title = @"Log in";
		logInItem.enabled = YES;
		logInItem.target = self;
		logInItem.action = @selector(logIn:);
		[self.menu addItem:logInItem];
	} else {
		NSMenuItem *item = [NSMenuItem new];
		item.enabled = NO;
		[self.menu addItem:item];
		self.trackingInfoItem = item;
		
		if ([TTTimeManager sharedInstance].currentTrackingEvent) {
			NSMenuItem *taskTitleItem = [NSMenuItem new];
			taskTitleItem.enabled = NO;
			taskTitleItem.title = [NSString stringWithFormat:@"Task: %@", [TTTimeManager sharedInstance].currentTrackingTask.name];
			[self.menu addItem:taskTitleItem];
			
			NSMenuItem *projectTitleItem = [NSMenuItem new];
			projectTitleItem.enabled = NO;
			projectTitleItem.title = [NSString stringWithFormat:@"Project: %@", [TTTimeManager sharedInstance].currentTrackingTask.project.name];
			[self.menu addItem:projectTitleItem];
			
			NSMenuItem *stopItem = [NSMenuItem new];
			stopItem.title = @"Stop tracking";
			stopItem.enabled = YES;
			stopItem.target = self;
			stopItem.action = @selector(stopTracking:);
			[self.menu addItem:stopItem];
		}
		[self.menu addItem:[NSMenuItem separatorItem]];
		
		NSMenuItem *totalItem = [NSMenuItem new];
		totalItem.enabled = NO;
		[self.menu addItem:totalItem];
		self.totalInfoItem = totalItem;
		
		[self setTrackingInfo];
		
		[self.menu addItem:[NSMenuItem separatorItem]];
		
		NSArray<NSNumber *> *projectIds = [[[NSArray arrayWithObject:@(INT_MAX)] arrayByAddingObjectsFromArray:[[TTTimeManager sharedInstance].allProjects mapWithBlock:^id(TTProject *obj) {
			return obj.uid;
		}]] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"self" ascending:NO]]];
		
		NSMutableDictionary<NSNumber *, NSMutableArray<TTTask *> *> *sortedTasks = [NSMutableDictionary dictionary];
		NSMutableArray *tasks = [[TTTimeManager sharedInstance].alltasks copy];
		for (TTTask *task in tasks) {
			NSNumber *key = task.project.uid? : @(INT_MAX);
			NSMutableArray *projectTasks = [sortedTasks objectForKey:key];
			if (!projectTasks) {
				projectTasks = [NSMutableArray array];
				[sortedTasks setObject:projectTasks forKey:key];
			}
			[projectTasks addObject:task];
		}
		
		NSArray *allProjects = [[TTTimeManager sharedInstance].allProjects copy];
		for (NSNumber *projectId in projectIds) {
			NSMutableArray<TTTask *> *projectTasks = [sortedTasks objectForKey:projectId]? : [NSMutableArray array];
			[projectTasks sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"uid" ascending:NO]]];
			
			TTProject *project = nil;
			for (TTProject *pr in allProjects) {
				if ([pr.uid isEqual:projectId]) {
					project = pr;
					break;
				}
			}
			if ([projectId isEqual:@(INT_MAX)]) {
				project = [TTProject new];
				project.uid = projectId;
				project.name = @"No project";
			}
			
			NSMenuItem *projectItem = [NSMenuItem new];
			projectItem.enabled = YES;
			projectItem.title = project.name;
			NSMenu *menu = [[NSMenu alloc] init];
			menu.autoenablesItems = YES;
			projectItem.submenu = menu;
			[self.menu addItem:projectItem];
			
			for (TTTask *task in projectTasks) {
				NSMenuItem *taskItem = [NSMenuItem new];
				taskItem.title = task.name;
				taskItem.representedObject = task;
				taskItem.target = self;
				taskItem.action = @selector(startTracking:);
				[projectItem.submenu addItem:taskItem];
			}
			
			[projectItem.submenu addItem:[NSMenuItem separatorItem]];
			
			NSMenuItem *createItem = [NSMenuItem new];
			createItem.title = @"＋ Create new task";
			createItem.target = self;
			createItem.action = @selector(createNewTask:);
			createItem.representedObject = project;
			[projectItem.submenu addItem:createItem];
		}
		
		[self.menu addItem:[NSMenuItem separatorItem]];
		
		NSMenuItem *logoutItem = [NSMenuItem new];
		logoutItem.title = @"Log out";
		logoutItem.enabled = YES;
		logoutItem.target = self;
		logoutItem.action = @selector(logOut:);
		[self.menu addItem:logoutItem];
	}
	
	NSMenuItem *quit = [NSMenuItem new];
	quit.title = @"Quit";
	quit.enabled = YES;
	quit.target = self;
	quit.action = @selector(quit:);
	[self.menu addItem:quit];
}

- (void)menuWillOpen:(NSMenu *)menu {
	[self.menu update];
}

@end
