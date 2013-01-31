//
//  F53OSCSocket.m
//
//  Created by Christopher Ashworth on 1/28/13.
//
//  Copyright (c) 2013 Figure 53 LLC, http://figure53.com
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

#define TIMEOUT 3

#import "F53OSCSocket.h"
#import "F53OSCPacket.h"
#import "F53OSCMessage.h"
#import "F53OSCFoundationAdditions.h"


@interface F53OSCSocket (Private)

+ (void) _processMessageData:(NSData *)data forDestination:(id <F53OSCServerPacketDestination, NSObject>)destination replyToSocket:(F53OSCSocket *)socket;
+ (void) _processBundleData:(NSData *)data forDestination:(id <F53OSCServerPacketDestination, NSObject>)destination replyToSocket:(F53OSCSocket *)socket;

@end

@implementation F53OSCSocket (private)

+ (void) _processMessageData:(NSData *)data forDestination:(id <F53OSCServerPacketDestination, NSObject>)destination replyToSocket:(F53OSCSocket *)socket;
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
    
    [destination takeMessage:[F53OSCMessage messageWithAddressPattern:addressPattern arguments:args replySocket:socket]];
}

+ (void) _processBundleData:(NSData *)data forDestination:(id <F53OSCServerPacketDestination, NSObject>)destination replyToSocket:(F53OSCSocket *)socket;
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
                    [self _processMessageData:[NSData dataWithBytesNoCopy:(void *)buffer length:elementLength freeWhenDone:NO]
                               forDestination:destination
                                replyToSocket:socket];
                }
                else if ( buffer[0] == '#' ) // OSC bundle
                {
                    [self _processBundleData:[NSData dataWithBytesNoCopy:(void *)buffer length:elementLength freeWhenDone:NO]
                              forDestination:destination
                               replyToSocket:socket];
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


#pragma mark -

@implementation F53OSCSocket

+ (F53OSCSocket *) socketWithTcpSocket:(GCDAsyncSocket *)socket
{
    return [[[F53OSCSocket alloc] initWithTcpSocket:socket] autorelease];
}

+ (F53OSCSocket *) socketWithUdpSocket:(GCDAsyncUdpSocket *)socket
{
    return [[[F53OSCSocket alloc] initWithUdpSocket:socket] autorelease];
}

+ (void) processOscData:(NSData *)data forDestination:(id <F53OSCServerPacketDestination, NSObject>)destination replyToSocket:(F53OSCSocket *)socket
{
    if ( data == nil )
        return;
    
    NSUInteger length = [data length];
    if ( length == 0 )
        return;
    
    const char *buffer = [data bytes];
    
    if ( buffer[0] == '/' ) // OSC message
    {
        [self _processMessageData:data forDestination:destination replyToSocket:socket];
    }
    else if ( buffer[0] == '#' ) // OSC bundle
    {
        [self _processBundleData:data forDestination:destination replyToSocket:socket];
    }
    else
    {
        NSLog( @"Error: Unrecognized OSC message of length %lu.", length );
    }
}

- (id) initWithTcpSocket:(GCDAsyncSocket *)socket;
{
    self = [super init];
    if ( self )
    {
        _tcpSocket = [socket retain];
        _udpSocket = nil;
        _host = @"localhost";
        _port = 0;
    }
    return self;
}

- (id) initWithUdpSocket:(GCDAsyncUdpSocket *)socket
{
    self = [super init];
    if ( self )
    {
        _tcpSocket = nil;
        _udpSocket = [socket retain];
        _host = @"localhost";
        _port = 0;
    }
    return self;
}

- (void) dealloc
{
    [_tcpSocket setDelegate:nil];
    [_tcpSocket disconnect];
    [_tcpSocket release];
    _tcpSocket = nil;
    
    [_udpSocket setDelegate:nil];
    [_udpSocket release];
    _udpSocket = nil;
    
    [_host release];
    _host = nil;
    
    [super dealloc];
}

- (NSString *) description
{
    if ( self.isTcpSocket )
        return [NSString stringWithFormat:@"[TCP socket %@:%u isConnected = %i]", _host, _port, self.isConnected ];
    else
        return [NSString stringWithFormat:@"[UDP socket %@:%u]", _host, _port ];
}

- (GCDAsyncSocket *) tcpSocket
{
    return _tcpSocket;
}

- (GCDAsyncUdpSocket *) udpSocket
{
    return _udpSocket;
}

- (BOOL) isTcpSocket
{
    return ( _tcpSocket != nil );
}

- (BOOL) isUdpSocket
{
    return ( _udpSocket != nil );
}

@synthesize host = _host;

@synthesize port = _port;

- (BOOL) startListening
{
    if ( _tcpSocket )
        return [_tcpSocket acceptOnPort:_port error:nil];
    
    if ( _udpSocket )
    {
        if ( [_udpSocket bindToPort:_port error:nil] )
            return [_udpSocket beginReceiving:nil];
        else
            return NO;
    }
    
    return NO;
}

- (void) stopListening
{
    if ( _tcpSocket )
        [_tcpSocket disconnectAfterWriting];
    
    if ( _udpSocket )
        [_udpSocket close];
}

- (BOOL) connect
{
    if ( _tcpSocket )
    {
        if ( _host && _port )
            return [_tcpSocket connectToHost:_host onPort:_port error:nil];
        else
            return NO;
    }
    
    if ( _udpSocket )
        return YES;
    
    return NO;
}

- (void) disconnect
{
    [_tcpSocket disconnect];
}

- (BOOL) isConnected
{
    if ( _tcpSocket )
        return [_tcpSocket isConnected];
    
    if ( _udpSocket )
        return YES;
    
    return NO;
}

- (void) sendPacket:(F53OSCPacket *)packet
{
    //NSLog( @"%@ sending packet: %@", _tcpSocket, self, packet );
    
    NSData *data = [packet packetData];

    if ( _tcpSocket )
    {
        // Prepend the message with the length of the data.
        UInt64 length = [data length];
        NSMutableData *newData = [NSMutableData dataWithCapacity:length];
        length = OSSwapHostToBigInt64( length );
        [newData appendBytes:&length length:sizeof( UInt64 )];
        [newData appendData:data];
        data = [NSData dataWithData:newData];
        
        [_tcpSocket readDataWithTimeout:-1 tag:0];
        [_tcpSocket writeData:data withTimeout:TIMEOUT tag:0];
    }
    else if ( _udpSocket )
    {
        [_udpSocket sendData:data toHost:_host port:_port withTimeout:TIMEOUT tag:0];
    }
}

@end
