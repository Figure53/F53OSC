//
//  F53OSCServer.m
//
//  Created by Sean Dougall on 3/23/11.
//
//  Copyright (c) 2011-2015 Figure 53 LLC, http://figure53.com
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

#if !__has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#import "F53OSCServer.h"
#import "F53OSCFoundationAdditions.h"


@interface F53OSCServer ()

@property (strong) F53OSCSocket *tcpSocket;
@property (strong) F53OSCSocket *udpSocket;
@property (strong) NSMutableDictionary *activeTcpSockets;  // F53OSCSockets keyed by index of when the connection was accepted.
@property (strong) NSMutableDictionary *activeData;        // NSMutableData keyed by index; buffers the incoming data.
@property (strong) NSMutableDictionary *activeState;       // NSMutableDictionary keyed by index; stores state of incoming data.
@property (assign) NSInteger activeIndex;

+ (NSString *) stringWithSpecialRegexCharactersEscaped:(NSString *)string;

@end


@implementation F53OSCServer

///
///  Escape characters that are special in regex (ICU v3) but not special in OSC.
///  Regex docs: http://userguide.icu-project.org/strings/regexp#TOC-Regular-Expression-Metacharacters
///  OSC docs: http://opensoundcontrol.org/spec-1_0
///
+ (NSString *) stringWithSpecialRegexCharactersEscaped:(NSString *)string
{
    string = [string stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"]; // Do this first!
    string = [string stringByReplacingOccurrencesOfString:@"+" withString:@"\\+"];
    string = [string stringByReplacingOccurrencesOfString:@"-" withString:@"\\-"];
    string = [string stringByReplacingOccurrencesOfString:@"(" withString:@"\\("];
    string = [string stringByReplacingOccurrencesOfString:@")" withString:@"\\)"];
    string = [string stringByReplacingOccurrencesOfString:@"^" withString:@"\\^"];
    string = [string stringByReplacingOccurrencesOfString:@"$" withString:@"\\$"];
    string = [string stringByReplacingOccurrencesOfString:@"|" withString:@"\\|"];
    string = [string stringByReplacingOccurrencesOfString:@"." withString:@"\\."];
    return string;
}

+ (NSString *) validCharsForOSCMethod
{
    return @"\"$%&'()+-.0123456789:;<=>@ABCDEFGHIJKLMNOPQRSTUVWXYZ\\^_`abcdefghijklmnopqrstuvwxyz|~!";
}

+ (NSPredicate *) predicateForAttribute:(NSString *)attributeName
                     matchingOSCPattern:(NSString *)pattern
{
    //NSLog( @"pattern   : %@", pattern );

    // Basic validity checks.
    if ( [[pattern componentsSeparatedByString:@"["] count] != [[pattern componentsSeparatedByString:@"]"] count] )
        return nil;
    if ( [[pattern componentsSeparatedByString:@"{"] count] != [[pattern componentsSeparatedByString:@"}"] count] )
        return nil;

    NSString *validOscChars = [F53OSCServer stringWithSpecialRegexCharactersEscaped:[F53OSCServer validCharsForOSCMethod]];
    NSString *wildCard = [NSString stringWithFormat:@"[%@]*", validOscChars];
    NSString *oneChar = [NSString stringWithFormat:@"[%@]{1}?", validOscChars];

    // Escape characters that are special in regex (ICU v3) but not special in OSC.
    pattern = [F53OSCServer stringWithSpecialRegexCharactersEscaped:pattern];
    //NSLog( @"cleaned   : %@", pattern );

    // Replace characters that are special in OSC with their equivalents in regex (ICU v3).
    pattern = [pattern stringByReplacingOccurrencesOfString:@"*" withString:wildCard];
    pattern = [pattern stringByReplacingOccurrencesOfString:@"?" withString:oneChar];
    pattern = [pattern stringByReplacingOccurrencesOfString:@"[!" withString:@"[^"];
    pattern = [pattern stringByReplacingOccurrencesOfString:@"{" withString:@"("];
    pattern = [pattern stringByReplacingOccurrencesOfString:@"}" withString:@")"];
    pattern = [pattern stringByReplacingOccurrencesOfString:@"," withString:@"|"];
    //NSLog( @"translated: %@", pattern );

    // MATCHES:
    // The left hand expression equals the right hand expression
    // using a regex-style comparison according to ICU v3. See:
    // http://icu.sourceforge.net/userguide/regexp.html
    // http://userguide.icu-project.org/strings/regexp#TOC-Regular-Expression-Metacharacters

    return [NSPredicate predicateWithFormat:@"%K MATCHES %@", attributeName, pattern];
}

- (id) init
{
    self = [super init];
    if ( self )
    {
        GCDAsyncSocket *rawTcpSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
        GCDAsyncUdpSocket *rawUdpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];

        self.delegate = nil;
        self.port = 0;
        self.udpReplyPort = 0;
        self.tcpSocket = [F53OSCSocket socketWithTcpSocket:rawTcpSocket];
        self.udpSocket = [F53OSCSocket socketWithUdpSocket:rawUdpSocket];
        self.activeTcpSockets = [NSMutableDictionary dictionaryWithCapacity:1];
        self.activeData = [NSMutableDictionary dictionaryWithCapacity:1];
        self.activeState = [NSMutableDictionary dictionaryWithCapacity:1];
        self.activeIndex = 0;
    }
    return self;
}

- (void) dealloc
{
    [self stopListening];

    self.delegate = nil;
    self.tcpSocket = nil;
    self.udpSocket = nil;
    self.activeTcpSockets = nil;
    self.activeData = nil;
    self.activeState = nil;
}

@synthesize delegate;

@synthesize port;

- (void) setPort:(UInt16)newPort
{
    port = newPort;

    [self.tcpSocket stopListening];
    [self.udpSocket stopListening];
    self.tcpSocket.port = self.port;
    self.udpSocket.port = self.port;
}

@synthesize udpReplyPort;

- (BOOL) startListening
{
    BOOL success;
    success = [self.tcpSocket startListening];
    if ( success )
        success = [self.udpSocket startListening];
    return success;
}

- (void) stopListening
{
    [self.tcpSocket stopListening];
    [self.udpSocket stopListening];
}

#pragma mark - GCDAsyncSocketDelegate

- (dispatch_queue_t) newSocketQueueForConnectionFromAddress:(NSData *)address onSocket:(GCDAsyncSocket *)sock
{
    return NULL;
}

- (void) socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
#if F53_OSC_SERVER_DEBUG
    NSLog( @"server socket %p didAcceptNewSocket %p", sock, newSocket );
#endif

    F53OSCSocket *activeSocket = [F53OSCSocket socketWithTcpSocket:newSocket];
    activeSocket.host = newSocket.connectedHost;
    activeSocket.port = newSocket.connectedPort;

    NSNumber *key = [NSNumber numberWithInteger:self.activeIndex];
    [self.activeTcpSockets setObject:activeSocket forKey:key];
    [self.activeData setObject:[NSMutableData data] forKey:key];
    [self.activeState setObject:[@{ @"socket": activeSocket, @"dangling_ESC": @NO } mutableCopy] forKey:key];

    [newSocket readDataWithTimeout:-1 tag:self.activeIndex];

    self.activeIndex++;
}

- (void) socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port
{
}

- (void) socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
#if F53_OSC_SERVER_DEBUG
    NSLog( @"server socket %p didReadData of length %lu. tag : %lu", sock, [data length], tag );
#endif

    NSMutableData *activeData = [self.activeData objectForKey:[NSNumber numberWithInteger:tag]];
    NSMutableDictionary *activeState = [self.activeState objectForKey:[NSNumber numberWithInteger:tag]];
    if ( activeData && activeState )
    {
        [F53OSCParser translateSlipData:data toData:activeData withState:activeState destination:self.delegate];
        [sock readDataWithTimeout:-1 tag:tag];
    }
}

- (void) socket:(GCDAsyncSocket *)sock didReadPartialDataOfLength:(NSUInteger)partialLength tag:(long)tag
{
#if F53_OSC_SERVER_DEBUG
    NSLog( @"server socket %p didReadPartialDataOfLength %lu. tag: %li", sock, partialLength, tag );
#endif
}

- (void) socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
#if F53_OSC_SERVER_DEBUG
    NSLog( @"server socket %p didWriteDataWithTag: %li", sock, tag );
#endif
}

- (void) socket:(GCDAsyncSocket *)sock didWritePartialDataOfLength:(NSUInteger)partialLength tag:(long)tag
{
#if F53_OSC_SERVER_DEBUG
    NSLog( @"server socket %p didWritePartialDataOfLength %lu", sock, partialLength );
#endif
}

- (NSTimeInterval) socket:(GCDAsyncSocket *)sock shouldTimeoutReadWithTag:(long)tag elapsed:(NSTimeInterval)elapsed bytesDone:(NSUInteger)length
{
    NSLog( @"Warning: F53OSCServer timed out when reading TCP data." );
    return 0;
}

- (NSTimeInterval) socket:(GCDAsyncSocket *)sock shouldTimeoutWriteWithTag:(long)tag elapsed:(NSTimeInterval)elapsed bytesDone:(NSUInteger)length
{
    NSLog( @"Warning: F53OSCServer timed out when writing TCP data." );
    return 0;
}

- (void) socketDidCloseReadStream:(GCDAsyncSocket *)sock
{
#if F53_OSC_SERVER_DEBUG
    NSLog( @"server socket %p didCloseReadStream", sock );
#endif
}

- (void) socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
#if F53_OSC_SERVER_DEBUG
    NSLog( @"server socket %p didDisconnect", sock );
#endif

    id keyOfDyingSocket = nil;
    for ( id key in [self.activeTcpSockets allKeys] )
    {
        F53OSCSocket *socket = [self.activeTcpSockets objectForKey:key];
        if ( socket.tcpSocket == sock )
        {
            keyOfDyingSocket = key;
            break;
        }
    }

    if ( keyOfDyingSocket )
    {
        [self.activeTcpSockets removeObjectForKey:keyOfDyingSocket];
        [self.activeData removeObjectForKey:keyOfDyingSocket];
        [self.activeState removeObjectForKey:keyOfDyingSocket];
    }
    else
    {
        NSLog( @"Error: F53OSCServer couldn't find the F53OSCSocket associated with the disconnecting TCP socket." );
    }
}

- (void) socketDidSecure:(GCDAsyncSocket *)sock
{
}

#pragma mark - GCDAsyncUdpSocketDelegate

- (void) udpSocket:(GCDAsyncUdpSocket *)sock didConnectToAddress:(NSData *)address
{
}

- (void) udpSocket:(GCDAsyncUdpSocket *)sock didNotConnect:(NSError *)error
{
}

- (void) udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag
{
}

- (void) udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error
{
}

- (void) udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext
{
    GCDAsyncUdpSocket *rawReplySocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    F53OSCSocket *replySocket = [F53OSCSocket socketWithUdpSocket:rawReplySocket];
    replySocket.host = [GCDAsyncUdpSocket hostFromAddress:address];
    replySocket.port = self.udpReplyPort;

    [self.udpSocket.stats addBytes:[data length]];

    [F53OSCParser processOscData:data forDestination:self.delegate replyToSocket:replySocket];
}

- (void) udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)error
{
}

@end
