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


@implementation F53OSCSocket

+ (F53OSCSocket *) socketWithTcpSocket:(GCDAsyncSocket *)socket
{
    return [[[F53OSCSocket alloc] initWithTcpSocket:socket] autorelease];
}

+ (F53OSCSocket *) socketWithUdpSocket:(GCDAsyncUdpSocket *)socket
{
    return [[[F53OSCSocket alloc] initWithUdpSocket:socket] autorelease];
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
        
        [_tcpSocket writeData:data withTimeout:TIMEOUT tag:[data length]];
    }
    else if ( _udpSocket )
    {
        [_udpSocket sendData:data toHost:_host port:_port withTimeout:TIMEOUT tag:0];
    }
}

@end
