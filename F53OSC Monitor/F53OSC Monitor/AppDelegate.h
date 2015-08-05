//
//  AppDelegate.h
//  F53OSC Monitor
//
//  Created by Adam Bachman on 8/5/15.
//  Copyright (c) 2015 Figure 53. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "F53OSC.h"
#import "DemoServer.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (strong) IBOutlet NSTextView *logOutput;

@property (strong) DemoServer *server;

- (void)log:(NSString *)message;

@end

