//
//  AppDelegate.m
//  F53OSC Monitor
//
//  Created by Adam Bachman on 8/5/15.
//  Copyright (c) 2015-2025 Figure 53. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "AppDelegate.h"


NS_ASSUME_NONNULL_BEGIN

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@property (strong) NSTimer *timer;
@property (strong) DemoServer *server;
@property (assign) long logCount;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    UInt16 port = 9999;
    self.server = [[DemoServer alloc] initWithPort:port];
    self.server.app = self;
    [self.server start];
    
    self.logCount = 0;

    // update data rate
    self.timer = [NSTimer timerWithTimeInterval:1.0 target:self selector:@selector( updateDataRateLabel ) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSDefaultRunLoopMode];
}

- (void)log:(NSString *)message
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.logCount++;
        NSString *logString = [NSString stringWithFormat:@"[%@ %07ld] %@\n", [NSDate date], self.logCount, message];
        NSDictionary<NSAttributedStringKey, id> *attrs = @{NSFontAttributeName:[NSFont fontWithName:@"Menlo" size:11]};
        NSAttributedString* outString = [[NSAttributedString alloc] initWithString:logString attributes:attrs];
        [[self.logOutput textStorage] appendAttributedString:outString];
        [self.logOutput scrollRangeToVisible:NSMakeRange([[self.logOutput string] length], 0)];
    });
}

- (void)updateDataRateLabel
{
    [self.dataRateLabel setStringValue:self.server.stats];
    [self.chart addDataPoint:self.server.bytesPerSecond];
}

- (IBAction)toggleServerActive:(id)sender
{
    if ( self.server.isActive )
    {
        [self.server stop];
        if ( !self.server.isActive )
            [self log:@"server has been stopped"];

        [self.connectionToggle setTitle:@"Connect"];
    }
    else
    {
        [self.server start];
        if ( self.server.isActive )
            [self log:@"server has been started"];

        [self.connectionToggle setTitle:@"Disconnect"];
    }
}

- (IBAction)clearConsole:(id)sender
{
    [self.logOutput setSelectedRange:NSMakeRange(0, self.logOutput.textStorage.length)];
    [self.logOutput setEditable:YES];
    [self.logOutput delete:nil];
    [self.logOutput setEditable:NO];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    [self.timer invalidate];
}

@end

NS_ASSUME_NONNULL_END
