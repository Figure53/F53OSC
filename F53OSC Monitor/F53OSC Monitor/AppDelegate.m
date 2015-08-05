//
//  AppDelegate.m
//  F53OSC Monitor
//
//  Created by Adam Bachman on 8/5/15.
//  Copyright (c) 2015 Figure 53. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate () {
    long _logCount;
}

@property (weak) IBOutlet NSWindow *window;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    UInt16 _port = [[NSNumber numberWithInt:9999] intValue];
    self.server = [[DemoServer alloc] initWithPort:_port];
    self.server.app = self;
    [self.server start];
    
    _logCount = 0;
}

- (void)log:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        _logCount++;
        NSString *logString = [NSString stringWithFormat:@"[%@ %07ld] %@\n", [NSDate new], _logCount, message];
        NSDictionary *attrs = @{NSFontAttributeName:[NSFont fontWithName:@"Menlo" size:11]};
        NSAttributedString* outString = [[NSAttributedString alloc] initWithString:logString attributes:attrs];
        
        [[self.logOutput textStorage] appendAttributedString:outString];
        [self.logOutput  scrollRangeToVisible:NSMakeRange([[self.logOutput string] length], 0)];
    });
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@end
