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

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.server = [[DemoServer alloc] initWithPort:9999];
    self.server.app = self;
    [self.server start];
    
    _logCount = 0;

    self.timer = [NSTimer timerWithTimeInterval:0.5 target:self selector:@selector( updateDataRateLabel ) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSDefaultRunLoopMode];
}

- (void)log:(NSString *)message
{
    dispatch_async(dispatch_get_main_queue(), ^{
        _logCount++;
        NSString *logString = [NSString stringWithFormat:@"[%@ %07ld] %@\n", [NSDate date], _logCount, message];
        NSDictionary *attrs = @{NSFontAttributeName:[NSFont fontWithName:@"Menlo" size:11]};
        NSAttributedString* outString = [[NSAttributedString alloc] initWithString:logString attributes:attrs];
        
        [[self.logOutput textStorage] appendAttributedString:outString];
        [self.logOutput  scrollRangeToVisible:NSMakeRange([[self.logOutput string] length], 0)];
    });
}

- (void)updateDataRateLabel
{
    [self.dataRateLabel setStringValue:self.server.stats];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    [self.timer invalidate];
}

@end
