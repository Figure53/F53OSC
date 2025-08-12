//
//  DemoServer.m
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
#import "DemoServer.h"


NS_ASSUME_NONNULL_BEGIN

@interface DemoServer ()

@property (strong) NSByteCountFormatter *formatter;
@property (strong) F53OSCServer *server;
@property (assign) UInt16 listeningPort;
@property (assign) bool isActive;

@end

@implementation DemoServer

- (id)initWithPort:(UInt16)port
{
    self = [super init];
    if ( self )
    {
        self.formatter = [[NSByteCountFormatter alloc] init];
        self.formatter.allowsNonnumericFormatting = NO;

        self.server = [F53OSCServer new];
        self.server.delegate = self;
        
        self.listeningPort = port;
        self.server.port = self.listeningPort;
    }
    return self;
}

- (void)start
{
    NSLog( @"starting F53OSC Monitor" );
    NSString *errorString = nil;

    if ( ![self.server startListening] )
    {
        NSLog( @"Error: F53OSC Monitor was unable to start listening on port %hu.", self.server.port );
        errorString = [NSString stringWithFormat:@"F53OSC Monitor was unable to start listening for OSC messages on port %hu.", self.server.port ];
    }
    else
    {
        [self.app log:[NSString stringWithFormat:@"F53OSC Monitor is listening for OSC messages on port %hu", self.server.port]];
        self.isActive = YES;
    }

    if ( errorString )
    {
        [self.app log:errorString];
    }
}

- (void)stop
{
    [self.server stopListening];
    self.isActive = NO;
}

- (NSString *)stats
{
    return [NSString stringWithFormat:@"%@ / %@ per second",
            [self.formatter stringFromByteCount:self.server.udpSocket.stats.totalBytes],
            [self.formatter stringFromByteCount:self.server.udpSocket.stats.bytesPerSecond]];
}

- (NSNumber *)bytesPerSecond
{
    return @(self.server.udpSocket.stats.bytesPerSecond);
}


#pragma mark - F53OSCServerDelegate / F53OSCPacketDestination

///
///  Note: F53OSC reserves the right to send messages off the main thread.
///
- (void)takeMessage:(nullable F53OSCMessage *)message
{
    // handle all messages synchronously
    [self performSelectorOnMainThread:@selector(processMessage:) withObject:message waitUntilDone:NO];
}

- (void)processMessage:(F53OSCMessage *)message
{
    // log all received messages
    // build log string
    NSString *argsString = @"";
    if ([message.arguments count] > 0)
        argsString = [NSString stringWithFormat:@"(%@)",[message.arguments componentsJoinedByString:@", "]];
    NSString *logString = [NSString stringWithFormat:@"/%@ %@", [message.addressParts componentsJoinedByString:@"/"], argsString] ;

    [self.app log:logString];
}

@end

NS_ASSUME_NONNULL_END
