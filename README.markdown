# F53OSC

Hey neat, it's a nice open source OSC library for Objective-C.

From your friends at [Figure 53](http://figure53.com).

For convenience, we've included a few public domain source files from [CocoaAsyncSocket](https://github.com/robbiehanson/CocoaAsyncSocket).  But appropriate thanks, kudos, and curiosity about that code should be directed to [the source](https://github.com/robbiehanson/CocoaAsyncSocket).

## Usage Notes

- GCDAsyncSocket.m and GCDAsyncUDPSocket.m both require ARC
- All other files are not ARC-compatible
- You need to link against Security.framework and CFNetwork.framework

Example:

`DemoServer.h`

```objc
@interface DemoServer : NSObject <F53OSCPacketDestination>

- (id) init;
- (void) start;
- (void) stop;

@end
```

`DemoServer.m`

```objc
#import "DemoServer.h"

@implementation DemoServer

- (id)init {
    self = [super init];

    self.server = [F53OSCServer new];
    self.server.delegate = self;
    self.server.port = [[NSNumber numberWithInt:9999] intValue];

    return self;
}

- (void)start {
    NSLog( @"starting OSC server" );
    NSString *errorString = nil;
    _isActive = NO;

    if ( ![self.server startListening] )
    {
        NSLog(@"Error: DemoServer was unable to start listening on port %u.", self.server.port);
        errorString = [NSString stringWithFormat:@"DemoServer was unable to start listening for OSC messages on port %u.", self.server.port ];
    }
    else
    {
        [self.app log:[NSString stringWithFormat:@"DemoServer is listening on port %u", self.server.port]];
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
}

#pragma mark - Message Handling

///
///  Note: F53OSC reserves the right to send messages off the main thread.
///
- (void)takeMessage:(F53OSCMessage *)message {
    [self performSelectorOnMainThread:@selector( _processMessage: ) withObject:message waitUntilDone:NO];
}

- (void)_processMessage:(F53OSCMessage *)message {
    // build log string and simply log message
    NSString *argsString = @"";
    if ([message.arguments count] > 0)
        argsString = [NSString stringWithFormat:@"(%@)",[message.arguments componentsJoinedByString:@", "]];
    NSString *logString = [NSString stringWithFormat:@"/%@ %@", [message.addressParts componentsJoinedByString:@"/"], argsString] ;

    NSLog(logString);
}

@end
```

`AppDelegate.m`

```objc
#import "AppDelegate.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    F53OSCServer *server = [[DemoServer alloc] init];
    [server start];
}
```



