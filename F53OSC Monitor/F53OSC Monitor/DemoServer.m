//
//  DemoServer.m
//  F53OSC Monitor
//
//  Created by Adam Bachman on 8/5/15.
//  Copyright (c) 2015 Figure 53. All rights reserved.
//

#import "AppDelegate.h"
#import "DemoServer.h"

@interface DemoServer () {
    BOOL _isActive;
    NSByteCountFormatter *_formatter;
}

@property (strong) F53OSCServer *server;

@end

@implementation DemoServer

- (void) _attachServer
{
    self.server = [F53OSCServer new];
    self.server.delegate = self;
}

- (id)initWithPort:(UInt16)port
{
    self = [super init];

    _formatter = [[NSByteCountFormatter alloc] init];
    _formatter.allowsNonnumericFormatting = NO;

    self.listeningPort = port;

    [self _attachServer];
    self.server.port = self.listeningPort;

    return self;
}

- (void)start {
    NSLog( @"starting OSC server" );
    NSString *errorString = nil;
    _isActive = NO;

    if ( ![self.server startListening] )
    {
        NSLog( @"Error: DemoServer was unable to start listening on port %u.", self.server.port );
        errorString = [NSString stringWithFormat:@"DemoServer was unable to start listening for OSC messages on port %u.", self.server.port ];
    }
    else
    {
        [self.app log:[NSString stringWithFormat:@"OSC server is listening on port %u", self.server.port]];
        _isActive = YES;
    }

    if ( errorString )
    {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert setMessageText:@"Unable to initialize OSC"];
        [alert setInformativeText:errorString];
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
    }
}

- (void)stop {
    [self.server stopListening];
    _isActive = NO;
}

- (NSString *)stats {
    return [NSString stringWithFormat:@"%@ / %@ per second",
            [_formatter stringFromByteCount:self.server.udpSocket.stats.bytes],
            [_formatter stringFromByteCount:self.server.udpSocket.stats.bytesPerSecond]];
}

#pragma mark - Message Handling

///
///  Note: F53OSC reserves the right to send messages off the main thread.
///
- (void)takeMessage:(F53OSCMessage *)message {
    // log received message
    [self performSelectorOnMainThread:@selector( _processMessage: ) withObject:message waitUntilDone:NO];
}

- (void)_processMessage:(F53OSCMessage *)message {
    // build log string
    NSString *argsString = @"";
    if ([message.arguments count] > 0)
        argsString = [NSString stringWithFormat:@"(%@)",[message.arguments componentsJoinedByString:@", "]];
    NSString *logString = [NSString stringWithFormat:@"/%@ %@", [message.addressParts componentsJoinedByString:@"/"], argsString] ;

    [self.app log:logString];
}

@end
