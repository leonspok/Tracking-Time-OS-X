//
//  AppDelegate.m
//  Menubar TrackingTime
//
//  Created by Игорь Савельев on 18/01/2017.
//  Copyright © 2017 MusicSense. All rights reserved.
//

#import "AppDelegate.h"
#import "TTTimeManager.h"

@interface AppDelegate () <NSMenuDelegate, NSUserNotificationCenterDelegate>

@property (strong, nonatomic) NSStatusItem *statusItem;

@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSMenu *menu;
@property (weak) IBOutlet NSView *loginView;
@property (weak) IBOutlet NSTextField *emailTextField;
@property (weak) IBOutlet NSSecureTextField *passwordTextField;
@property (weak) IBOutlet NSTextField *taskNameTextField;

@property (nonatomic, weak) NSMenuItem *trackingInfoItem;
@property (nonatomic, strong) NSTimer *trackingInfoTimer;
@property (nonatomic, strong) NSTimer *reloadInfoTimer;
@property (nonatomic, strong) NSTimer *reloadTrackingInfoTimer;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	self.menu.delegate = self;
	
	self.trackingInfoTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(setTrackingInfo) userInfo:nil repeats:YES];
	[[NSRunLoop mainRunLoop] addTimer:self.trackingInfoTimer forMode:NSEventTrackingRunLoopMode];
	self.reloadInfoTimer = [NSTimer scheduledTimerWithTimeInterval:3*60.0f target:self selector:@selector(reloadInfoTimer) userInfo:nil repeats:YES];
	self.reloadTrackingInfoTimer = [NSTimer scheduledTimerWithTimeInterval:10.0f target:self selector:@selector(reloadCurrentTrackingTask) userInfo:nil repeats:YES];
	[[NSRunLoop mainRunLoop] addTimer:self.reloadTrackingInfoTimer forMode:NSEventTrackingRunLoopMode];
	
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

- (void)applicationWillTerminate:(NSNotification *)aNotification {
	[[TTTimeManager sharedInstance] stopTrackingSuccess:nil failure:nil];
}

#pragma mark Info

- (void)reloadCurrentTrackingTask {
	BOOL wasTracking = [TTTimeManager sharedInstance].currentTrackingEvent != nil;
	NSString *wasTrackingTask = [TTTimeManager sharedInstance].currentTrackingTask.name;
	[[TTTimeManager sharedInstance] loadCurrentTrackingInfoCompletion:^{
		dispatch_async(dispatch_get_main_queue(), ^{
			if (!wasTracking && [TTTimeManager sharedInstance].currentTrackingEvent) {
				NSUserNotification *notification = [[NSUserNotification alloc] init];
				notification.title = [TTTimeManager sharedInstance].currentTrackingTask.name;
				notification.informativeText = @"Started tracking";
				[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
			} else if (wasTracking && [TTTimeManager sharedInstance].currentTrackingEvent == nil) {
				NSUserNotification *notification = [[NSUserNotification alloc] init];
				notification.title = wasTrackingTask;
				notification.informativeText = @"Stopped tracking";
				[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
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
					[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
				} else if (wasTracking && [TTTimeManager sharedInstance].currentTrackingEvent == nil) {
					NSUserNotification *notification = [[NSUserNotification alloc] init];
					notification.title = wasTrackingTask;
					notification.informativeText = @"Stopped tracking";
					[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
				}
			});
		}
	}];
}

- (void)setTrackingInfo {
	if ([TTTimeManager sharedInstance].currentTrackingEvent) {
		NSInteger seconds = round([[NSDate date] timeIntervalSinceDate:[TTTimeManager sharedInstance].currentTrackingEvent.dateStart]);
		self.trackingInfoItem.title = [NSString stringWithFormat:@"%02d:%02d:%02d", (int)seconds/3600, (int)(seconds%3600)/60, (int)seconds%60];
		NSImage *menuBarLogo = [NSImage imageNamed:@"stopIcon"];
		[menuBarLogo setTemplate:YES];
		self.statusItem.image = menuBarLogo;
	} else {
		self.trackingInfoItem.title = @"No tracking";
		NSImage *menuBarLogo = [NSImage imageNamed:@"startIcon"];
		[menuBarLogo setTemplate:YES];
		self.statusItem.image = menuBarLogo;
	}
}

#pragma mark Actions

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
					[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
				});
				[[TTTimeManager sharedInstance] loadAllDataCompletion:^(BOOL success) {
					if (success) {
						dispatch_async(dispatch_get_main_queue(), ^{
							NSUserNotification *notification = [[NSUserNotification alloc] init];
							notification.title = @"TrackingTime is ready";
							[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
						});
					} 
				}];
			} else {
				dispatch_async(dispatch_get_main_queue(), ^{
					NSUserNotification *notification = [[NSUserNotification alloc] init];
					notification.title = @"Log in failed";
					[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
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
			[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
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
			[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
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
	
	NSNumber *projectUID = sender.representedObject;
	if ([projectUID isEqual:@(INT_MAX)]) {
		projectUID = nil;
	}
	
	NSModalResponse button = [alert runModal];
	if (button == NSAlertFirstButtonReturn) {
		[[TTTimeManager sharedInstance] createTaskWithName:self.taskNameTextField.stringValue inProject:projectUID success:^(TTTask *task) {
			[[TTTimeManager sharedInstance] startTracking:task success:^{
				dispatch_async(dispatch_get_main_queue(), ^{
					NSUserNotification *notification = [[NSUserNotification alloc] init];
					notification.informativeText = @"Started tracking";
					notification.title = task.name;
					[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
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
				[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
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
						[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
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
	} else {
		if ([[TTTimeManager sharedInstance].api authedUser] == nil) {
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
			return;
		}
		
		NSMenuItem *item = [NSMenuItem new];
		item.enabled = NO;
		[self.menu addItem:item];
		self.trackingInfoItem = item;
		
		[self setTrackingInfo];
		
		if ([TTTimeManager sharedInstance].currentTrackingEvent) {
			NSMenuItem *taskItem = [NSMenuItem new];
			taskItem.enabled = NO;
			taskItem.title = [NSString stringWithFormat:@"%@ | %@", [TTTimeManager sharedInstance].currentTrackingTask.name, [TTTimeManager sharedInstance].currentTrackingTask.projectName];
			[self.menu addItem:taskItem];
			
			NSMenuItem *stopItem = [NSMenuItem new];
			stopItem.title = @"Stop tracking";
			stopItem.enabled = YES;
			stopItem.target = self;
			stopItem.action = @selector(stopTracking:);
			[self.menu addItem:stopItem];
		}
		
		[self.menu addItem:[NSMenuItem separatorItem]];
		
		NSMutableDictionary<NSNumber *, NSMutableArray *> *sortedTasks = [NSMutableDictionary dictionary];
		NSMutableArray *tasks = [[TTTimeManager sharedInstance].alltasks copy];
		for (TTTask *task in tasks) {
			NSNumber *key = task.projectUID? : @(INT_MAX);
			NSMutableArray *projectTasks = [sortedTasks objectForKey:key];
			if (!projectTasks) {
				projectTasks = [NSMutableArray array];
				[sortedTasks setObject:projectTasks forKey:key];
			}
			[projectTasks addObject:task];
		}
		
		NSArray<NSNumber *> *projects = [sortedTasks.allKeys sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
			return [obj2 compare:obj1];
		}];
		for (NSNumber *project in projects) {
			NSMutableArray *projectTasks = [sortedTasks objectForKey:project];
			[projectTasks sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"uid" ascending:NO]]];
			
			NSMenuItem *projectItem = [NSMenuItem new];
			projectItem.enabled = YES;
			projectItem.title = [projectTasks.firstObject projectName];
			if ([project isEqual:@(INT_MAX)]) {
				projectItem.title = @"No project";
			}
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
