//
//  F53OSCServer.m
//
//  Created by Sean Dougall on 3/23/11.
//
//  Copyright (c) 2011-2013 Figure 53 LLC, http://figure53.com
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

#import "F53OSCServer.h"
#import "F53OSCFoundationAdditions.h"


@interface F53OSCServer (Private)

+ (NSString *) _stringWithSpecialRegexCharactersEscaped:(NSString *)string;

@end


@implementation F53OSCServer (Private)

///
///  Escape characters that are special in regex (ICU v3) but not special in OSC.
///  Regex docs: http://userguide.icu-project.org/strings/regexp#TOC-Regular-Expression-Metacharacters
///  OSC docs: http://opensoundcontrol.org/spec-1_0
///
+ (NSString *) _stringWithSpecialRegexCharactersEscaped:(NSString *)string
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

@end


@implementation F53OSCServer

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
    
    NSString *validOscChars = [F53OSCServer _stringWithSpecialRegexCharactersEscaped:[F53OSCServer validCharsForOSCMethod]];
    NSString *wildCard = [NSString stringWithFormat:@"[%@]*", validOscChars];
    NSString *oneChar = [NSString stringWithFormat:@"[%@]{1}?", validOscChars];
    
    // Escape characters that are special in regex (ICU v3) but not special in OSC.
    pattern = [F53OSCServer _stringWithSpecialRegexCharactersEscaped:pattern];
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
        GCDAsyncSocket *tcpSocket = [[[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()] autorelease];
        GCDAsyncUdpSocket *udpSocket = [[[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()] autorelease];
        
        _port = 0;
        _udpReplyPort = 0;
        _destination = nil;
        _tcpSocket = [[F53OSCSocket socketWithTcpSocket:tcpSocket] retain];
        _udpSocket = [[F53OSCSocket socketWithUdpSocket:udpSocket] retain];
        _activeTcpSockets = [[NSMutableDictionary dictionaryWithCapacity:1] retain];
        _activeData = [[NSMutableDictionary dictionaryWithCapacity:1] retain];
        _activeIndex = 0;
    }
    return self;
}

- (void) dealloc
{
    [self stopListening];
    
    [_tcpSocket release];
    _tcpSocket = nil;
    
    [_udpSocket release];
    _udpSocket = nil;
    
    [_activeTcpSockets release];
    _activeTcpSockets = nil;
    
    [_activeData release];
    _activeData = nil;
    
    [super dealloc];
}

@synthesize port = _port;

- (void) setPort:(UInt16)port
{
    _port = port;
    
    [_tcpSocket stopListening];
    [_udpSocket stopListening];
    _tcpSocket.port = _port;
    _udpSocket.port = _port;
}

@synthesize destination = _destination;

- (BOOL) startListening
{
    BOOL success;
    success = [_tcpSocket startListening];
    if ( success )
        success = [_udpSocket startListening];
    return success;
}

- (void) stopListening
{
    [_tcpSocket stopListening];
    [_udpSocket stopListening];
}

#pragma mark - GCDAsyncSocketDelegate

- (dispatch_queue_t) newSocketQueueForConnectionFromAddress:(NSData *)address onSocket:(GCDAsyncSocket *)sock
{
    return NULL;
}

- (void) socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    //NSLog( @"server socket %p didAcceptNewSocket %p", sock, newSocket );
    
    F53OSCSocket *activeSocket = [F53OSCSocket socketWithTcpSocket:newSocket];
    activeSocket.host = newSocket.connectedHost;
    activeSocket.port = newSocket.connectedPort;
    
    [_activeTcpSockets setObject:activeSocket forKey:[NSNumber numberWithInteger:_activeIndex]];
    [_activeData setObject:[NSMutableData data] forKey:[NSNumber numberWithInteger:_activeIndex]];
    
    [newSocket readDataWithTimeout:-1 tag:_activeIndex];
    
    _activeIndex++;
}

- (void) socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port
{
}

- (void) socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    //NSLog( @"server socket %p didReadData of length %lu", sock, [data length] );
    
    F53OSCSocket *activeSocket = [_activeTcpSockets objectForKey:[NSNumber numberWithInteger:tag]];
    NSMutableData *activeData = [_activeData objectForKey:[NSNumber numberWithInteger:tag]];
    if ( activeSocket && activeData )
    {
        [activeData appendData:data];
        
        // Incoming OSC messages are expected to be prepended by the length of the message when sent via TCP.
        // Each time we get more data we look to see if we now have a complete message to process.
        
        NSUInteger length = [activeData length];
        if ( length > sizeof( UInt64 ) )
        {
            const char *buffer = [activeData bytes];
            UInt64 dataSize = *((UInt64 *)buffer);
            dataSize = OSSwapBigToHostInt64( dataSize );
            
            if ( length - sizeof( UInt64 ) >= dataSize )
            {
                buffer += sizeof( UInt64 );
                length -= sizeof( UInt64 );
                NSData *oscData = [NSData dataWithBytes:buffer length:dataSize];
                
                buffer += dataSize;
                length -= dataSize;
                NSData *newData = nil;
                if ( length )
                    newData = [NSData dataWithBytes:buffer length:length];
                else
                    newData = [NSData data];
                [activeData setData:newData];
                
                [F53OSCSocket processOscData:oscData forDestination:_destination replyToSocket:activeSocket];
            }
            else
            {
                // TODO: protect against them filling up the buffer with a huge amount of incoming data.
            }
        }
        
        [sock readDataWithTimeout:-1 tag:tag];
    }
}

- (void) socket:(GCDAsyncSocket *)sock didReadPartialDataOfLength:(NSUInteger)partialLength tag:(long)tag
{
    //NSLog( @"server socket %p didReadPartialDataOfLength %lu tag: %li", sock, partialLength, tag );
}

- (void) socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    //NSLog( @"server socket %p didWriteDataWithTag: %li", sock, tag );
}

- (void) socket:(GCDAsyncSocket *)sock didWritePartialDataOfLength:(NSUInteger)partialLength tag:(long)tag
{
    //NSLog( @"server socket %p didWritePartialDataOfLength %lu", sock, partialLength );
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
    //NSLog( @"server socket %p didCloseReadStream", sock );
}

- (void) socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    //NSLog( @"server socket %p didDisconnect", sock );
    
    id keyOfDyingSocket;
    for ( id key in [_activeTcpSockets allKeys] )
    {
        F53OSCSocket *socket = [_activeTcpSockets objectForKey:key];
        if ( socket.tcpSocket == sock )
        {
            keyOfDyingSocket = key;
            break;
        }
    }
    
    if ( keyOfDyingSocket )
    {
        [_activeTcpSockets removeObjectForKey:keyOfDyingSocket];
        [_activeData removeObjectForKey:keyOfDyingSocket];
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
    GCDAsyncUdpSocket *rawReplySocket = [[[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()] autorelease];
    F53OSCSocket *replySocket = [F53OSCSocket socketWithUdpSocket:rawReplySocket];
    replySocket.host = [GCDAsyncUdpSocket hostFromAddress:address];
    replySocket.port = _udpReplyPort;
    
    [F53OSCSocket processOscData:data forDestination:_destination replyToSocket:replySocket];
}

- (void) udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)error
{
}

@end
