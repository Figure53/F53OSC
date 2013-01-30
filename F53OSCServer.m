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
- (void) _receivedOSCData:(NSData *)data replyToSocket:(F53OSCSocket *)socket;
- (void) _receivedMessageData:(NSData *)data replyToSocket:(F53OSCSocket *)socket;
- (void) _receivedBundleData:(NSData *)data replyToSocket:(F53OSCSocket *)socket;

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

- (void) _receivedOSCData:(NSData *)data replyToSocket:(F53OSCSocket *)socket
{
    if ( data == nil )
        return;
    
    NSUInteger length = [data length];
    if ( length == 0 )
        return;
    
    const char *buffer = [data bytes];
    
    if ( buffer[0] == '/' ) // OSC message
    {
        [self _receivedMessageData:data replyToSocket:socket];
    }
    else if ( buffer[0] == '#' ) // OSC bundle
    {
        [self _receivedBundleData:data replyToSocket:socket];
    }
    else
    {
        NSLog( @"Error: Unrecognized OSC message of length %lu.", length );
    }
}

- (void) _receivedMessageData:(NSData *)data replyToSocket:(F53OSCSocket *)socket;
{
    NSUInteger length = [data length];
    const char *buffer = [data bytes];
    
    NSUInteger lengthOfRemainingBuffer = length;
    NSUInteger dataLength = 0;
    NSString *addressPattern = [NSString stringWithOSCStringBytes:buffer maxLength:lengthOfRemainingBuffer length:&dataLength];
    if ( addressPattern == nil || dataLength == 0 || dataLength > length )
    {
        NSLog( @"Error: Unable to parse OSC method address." );
        return;
    }
    
    buffer += dataLength;
    lengthOfRemainingBuffer -= dataLength;
    
    NSMutableArray *args = [NSMutableArray array];
    BOOL hasArguments = (lengthOfRemainingBuffer > 0);
    if ( hasArguments && buffer[0] == ',' )
    {
        NSString *typeTag = [NSString stringWithOSCStringBytes:buffer maxLength:lengthOfRemainingBuffer length:&dataLength];
        if ( typeTag == nil )
        {
            NSLog( @"Error: Unable to parse type tag for OSC method %@", addressPattern );
            return;
        }
        buffer += dataLength;
        lengthOfRemainingBuffer -= dataLength;
        
        NSInteger numArgs = [typeTag length] - 1;
        if ( numArgs > 0 )
        {
            for ( int i = 1; i < numArgs + 1; i++ )
            {
                NSString *stringArg = nil;
                NSData *dataArg = nil;
                NSNumber *numberArg = nil;
                
                char type = [typeTag characterAtIndex:i]; // (index starts at 1 because first char is ",")
                switch ( type )
                {
                    case 's':
                        stringArg = [NSString stringWithOSCStringBytes:buffer maxLength:lengthOfRemainingBuffer length:&dataLength];
                        if ( stringArg )
                        {
                            [args addObject:stringArg];
                            buffer += dataLength;
                            lengthOfRemainingBuffer -= dataLength;
                        }
                        else
                        {
                            NSLog( @"Error: Unable to parse string argument for OSC method %@", addressPattern );
                            return;
                        }
                        break;
                    case 'b':
                        dataArg = [NSData dataWithOSCBlobBytes:buffer maxLength:lengthOfRemainingBuffer length:&dataLength];
                        if ( dataArg )
                        {
                            [args addObject:dataArg];
                            buffer += dataLength + 4;
                            lengthOfRemainingBuffer -= (dataLength + 4);
                        }
                        else
                        {
                            NSLog( @"Error: Unable to parse blob argument for OSC method %@", addressPattern );
                            return;
                        }
                        break;
                    case 'i':
                        numberArg = [NSNumber numberWithOSCIntBytes:buffer maxLength:lengthOfRemainingBuffer];
                        if ( numberArg )
                        {
                            [args addObject:numberArg];
                            buffer += 4;
                            lengthOfRemainingBuffer -= 4;
                        }
                        else
                        {
                            NSLog( @"Error: Unable to parse int argument for OSC method %@", addressPattern );
                            return;
                        }
                        break;
                    case 'f':
                        numberArg = [NSNumber numberWithOSCFloatBytes:buffer maxLength:lengthOfRemainingBuffer];
                        if ( numberArg )
                        {
                            [args addObject:numberArg];
                            buffer += 4;
                            lengthOfRemainingBuffer -= 4;
                        }
                        else
                        {
                            NSLog( @"Error: Unable to parse float argument for OSC method %@", addressPattern );
                            return;
                        }
                        break;
                    default:
                        NSLog( @"Error: Unrecognized type '%c' found in type tag for OSC method %@", type, addressPattern );
                        return;
                }
            }
        }
    }
    
    [_destination takeMessage:[F53OSCMessage messageWithAddressPattern:addressPattern arguments:args replySocket:socket]];
}

- (void) _receivedBundleData:(NSData *)data replyToSocket:(F53OSCSocket *)socket;
{
    NSUInteger length = [data length];
    const char *buffer = [data bytes];
    
    NSUInteger lengthOfRemainingBuffer = length;
    NSUInteger dataLength = 0;
    NSString *bundlePrefix = [NSString stringWithOSCStringBytes:buffer maxLength:lengthOfRemainingBuffer length:&dataLength];
    if ( bundlePrefix == nil || dataLength == 0 || dataLength > length )
    {
        NSLog( @"Error: Unable to parse OSC bundle prefix." );
        return;
    }
    
    if ( [bundlePrefix isEqualToString:@"#bundle"] )
    {
        buffer += dataLength;
        lengthOfRemainingBuffer -= dataLength;
        
        if ( lengthOfRemainingBuffer > 8 )
        {
            //F53OSCTimeTag *timetag = [F53OSCTimeTag timeTagWithOSCTimeBytes:buffer];
            buffer += 8; // We're not currently using the time tag so we just skip it.
            lengthOfRemainingBuffer -= 8;
            
            while ( lengthOfRemainingBuffer > sizeof( UInt32 ) )
            {
                UInt32 elementLength = *((UInt32 *)buffer);
                elementLength = OSSwapBigToHostInt32( elementLength );
                buffer += sizeof( UInt32 );
                lengthOfRemainingBuffer -= sizeof( UInt32 );
                
                if ( elementLength > lengthOfRemainingBuffer )
                {
                    NSLog( @"Error: A message in the OSC bundle claimed to be larger than the bundle itself." );
                    return;
                }
                
                if ( buffer[0] == '/' ) // OSC message
                {
                    [self _receivedMessageData:[NSData dataWithBytesNoCopy:(void *)buffer length:elementLength freeWhenDone:NO] replyToSocket:socket];
                }
                else if ( buffer[0] == '#' ) // OSC bundle
                {
                    [self _receivedBundleData:[NSData dataWithBytesNoCopy:(void *)buffer length:elementLength freeWhenDone:NO] replyToSocket:socket];
                }
                else
                {
                    NSLog( @"Error: Bundle contained unrecognized OSC message of length %u.", elementLength );
                    return;
                }
                
                buffer += elementLength;
                lengthOfRemainingBuffer -= elementLength;
            }
        }
        else
        {
            NSLog( @"Warning: Received an empty OSC bundle message." );
        }
    }
    else
    {
        NSLog( @"Error: Received an invalid OSC bundle message." );
    }
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
    
    [_destination release];
    _destination = nil;
    
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
                
                [self _receivedOSCData:oscData replyToSocket:activeSocket];
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
    NSLog( @"server socket %p didCloseReadStream", sock );
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
    [self _receivedOSCData:data replyToSocket:replySocket];
}

- (void) udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)error
{
}

@end
