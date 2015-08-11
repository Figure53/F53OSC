//
//  DemoServer.m
//  F53OSC Monitor
//
//  Created by Adam Bachman on 8/5/15.
//  Copyright (c) 2015 Figure 53. All rights reserved.
//

#import "AppDelegate.h"
#import "DemoServer.h"

@interface DemoServer ()

@property (strong) NSByteCountFormatter *formatter;
@property (strong) F53OSCServer *server;
@property (assign) UInt16 listeningPort;

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
        NSLog( @"Error: F53OSC Monitor was unable to start listening on port %u.", self.server.port );
        errorString = [NSString stringWithFormat:@"F53OSC Monitor was unable to start listening for OSC messages on port %u.", self.server.port ];
    }
    else
    {
        [self.app log:[NSString stringWithFormat:@"F53OSC Monitor is listening for OSC messages on port %u", self.server.port]];
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

- (void)stop
{
    [self.server stopListening];
}

- (NSString *)stats
{
    return [NSString stringWithFormat:@"%@ / %@ per second",
            [self.formatter stringFromByteCount:self.server.udpSocket.stats.totalBytes],
            [self.formatter stringFromByteCount:self.server.udpSocket.stats.bytesPerSecond]];
}

#pragma mark - Message Handling

///
///  Note: F53OSC reserves the right to send messages off the main thread.
///
- (void)takeMessage:(F53OSCMessage *)message
{
    // log received message
    [self performSelectorOnMainThread:@selector( _processMessage: ) withObject:message waitUntilDone:NO];
}

- (void)_processMessage:(F53OSCMessage *)message
{
    // build log string
    NSString *argsString = @"";
    if ([message.arguments count] > 0)
        argsString = [NSString stringWithFormat:@"(%@)",[message.arguments componentsJoinedByString:@", "]];
    NSString *logString = [NSString stringWithFormat:@"/%@ %@", [message.addressParts componentsJoinedByString:@"/"], argsString] ;

    [self.app log:logString];
}

@end
