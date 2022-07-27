//
//  DemoServer.h
//  F53OSC Monitor
//
//  Created by Adam Bachman on 8/5/15.
//  Copyright (c) 2015-2022 Figure 53. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "F53OSC.h"

@class AppDelegate;

@interface DemoServer : NSObject <F53OSCServerDelegate>

@property (weak) AppDelegate *app;

- (id) initWithPort:(UInt16)port;

- (void) start;
- (void) stop;
- (bool) isActive;

- (NSString *)stats;
- (NSNumber *)bytesPerSecond;

@end
