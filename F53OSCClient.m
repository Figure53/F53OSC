//
//  F53OSCClient.m
//
//  Created by Sean Dougall on 1/20/11.
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

#import "F53OSCClient.h"
#import "F53OSCParser.h"


@interface F53OSCClient (Private)

- (void) _destroySocket;
- (void) _createSocket;

@end


@implementation F53OSCClient (Private)

- (void) _destroySocket
{
    [_readState removeObjectForKey:@"socket"];
    
    [_socket disconnect];
    [_socket autorelease];
    _socket = nil;
}

- (void) _createSocket
{
    if ( _useTcp )
    {
        GCDAsyncSocket *tcpSocket = [[[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()] autorelease];
        _socket = [[F53OSCSocket socketWithTcpSocket:tcpSocket] retain];
        if ( _socket )
            [_readState setObject:_socket forKey:@"socket"];
    }
    else
    {
        GCDAsyncUdpSocket *udpSocket = [[[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()] autorelease];
        _socket = [[F53OSCSocket socketWithUdpSocket:udpSocket] retain];
    }
    _socket.host = self.host;
    _socket.port = self.port;
}

@end


@implementation F53OSCClient

- (id) init
{
    self = [super init];
    if ( self )
    {
        _delegate = nil;
        _host = @"localhost";
        _port = 53000;         // QLab is 53000, Stagetracker is 57115.
        _useTcp = NO;
        _userData = nil;
        _socket = nil;
        _readData = [[NSMutableData data] retain];
        _readState = [[NSMutableDictionary dictionary] retain];
    }
    return self;
}

- (void) dealloc
{
    [_host release];
    _host = nil;
    
    [_userData release];
    _userData = nil;
    
    [self _destroySocket];
    
    [_readData release];
    _readData = nil;
    
    [_readState release];
    _readState = nil;
    
    [super dealloc];
}

- (void) encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_host forKey:@"host"];
    [coder encodeObject:[NSNumber numberWithUnsignedShort:_port] forKey:@"port"];
    [coder encodeObject:[NSNumber numberWithBool:_useTcp] forKey:@"useTcp"];
    [coder encodeObject:_userData forKey:@"userData"];
}

- (id) initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if ( self )
    {
        _delegate = nil;
        _host = [[coder decodeObjectForKey:@"host"] retain];
        _port = [[coder decodeObjectForKey:@"port"] unsignedShortValue];
        _useTcp = [[coder decodeObjectForKey:@"useTcp"] boolValue];
        _userData = [[coder decodeObjectForKey:@"userData"] retain];
        _socket = nil;
        _readData = [[NSMutableData data] retain];
        _readState = [[NSMutableDictionary dictionary] retain];
    }
    return self;
}

@synthesize delegate = _delegate;

@synthesize host = _host;

- (void) setHost:(NSString *)host
{
    [_host autorelease];
    _host = [host copy];
    _socket.host = _host;
}

@synthesize port = _port;

- (void) setPort:(UInt16)port
{
    _port = port;
    _socket.port = _port;
}

@synthesize useTcp = _useTcp;

- (void) setUseTcp:(BOOL)useTcp
{
    if ( _useTcp == useTcp )
        return;
    
    _useTcp = useTcp;
    
    [self _destroySocket];
}

@synthesize userData = _userData;

- (NSString *) title
{
    if ( _host && _port )
        return [NSString stringWithFormat:@"%@ : %u", _host, _port ];
    else
        return [NSString stringWithFormat:@"<invalid>" ];
}

- (BOOL) connect
{
    if ( !_socket )
        [self _createSocket];
    if ( _socket )
        return [_socket connect];
    return NO;
}

- (void) disconnect
{
    [_socket disconnect];
    [_readData setData:[NSData data]];
    [_readState setObject:@NO forKey:@"dangling_ESC"];
}

- (void) sendPacket:(F53OSCPacket *)packet
{
    if ( !_socket )
        [self connect];
    
    if ( _socket )
    {
        if ( _socket.isTcpSocket )
            [_socket.tcpSocket readDataWithTimeout:-1 tag:0]; // Listen for a potential response.
        [_socket sendPacket:packet];
    }
    else
    {
        NSLog( @"Error: F53OSCClient could not send data; no socket available." );
    }
}

#pragma mark - GCDAsyncSocketDelegate

- (dispatch_queue_t) newSocketQueueForConnectionFromAddress:(NSData *)address onSocket:(GCDAsyncSocket *)sock
{
    return NULL;
}

- (void) socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    // Client objects do not accept new incoming connections.
}

- (void) socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port
{
#if F53_OSC_CLIENT_DEBUG
    NSLog( @"client socket %p didConnectToHost %@:%u", sock, host, port );
#endif
}

- (void) socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
#if F53_OSC_CLIENT_DEBUG
    NSLog( @"client socket %p didReadData of length %lu. tag : %lu", sock, [data length], tag );
#endif
    
    [F53OSCParser translateSlipData:data toData:_readData withState:_readState destination:_delegate];
    [sock readDataWithTimeout:-1 tag:tag];
}

- (void) socket:(GCDAsyncSocket *)sock didReadPartialDataOfLength:(NSUInteger)partialLength tag:(long)tag
{
#if F53_OSC_CLIENT_DEBUG
    NSLog( @"client socket %p didReadPartialDataOfLength %lu. tag: %li", sock, partialLength, tag );
#endif
}

- (void) socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
#if F53_OSC_CLIENT_DEBUG
    NSLog( @"client socket %p didWriteDataWithTag %li", sock, tag );
#endif
}

- (void) socket:(GCDAsyncSocket *)sock didWritePartialDataOfLength:(NSUInteger)partialLength tag:(long)tag
{
#if F53_OSC_CLIENT_DEBUG
    NSLog( @"server socket %p didWritePartialDataOfLength %lu. tag: %li", sock, partialLength, tag );
#endif
}

- (NSTimeInterval) socket:(GCDAsyncSocket *)sock shouldTimeoutReadWithTag:(long)tag elapsed:(NSTimeInterval)elapsed bytesDone:(NSUInteger)length
{
    NSLog( @"Warning: F53OSCClient timed out when reading data." );
    return 0;
}

- (NSTimeInterval) socket:(GCDAsyncSocket *)sock shouldTimeoutWriteWithTag:(long)tag elapsed:(NSTimeInterval)elapsed bytesDone:(NSUInteger)length
{
    NSLog( @"Warning: F53OSCClient timed out when sending data." );
    return 0;
}

- (void) socketDidCloseReadStream:(GCDAsyncSocket *)sock
{
#if F53_OSC_CLIENT_DEBUG
    NSLog( @"client socket %p didCloseReadStream", sock );
#endif
    
    [_readData setData:[NSData data]];
    [_readState setObject:@NO forKey:@"dangling_ESC"];
}

- (void) socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
#if F53_OSC_CLIENT_DEBUG
    NSLog( @"client socket %p didDisconnect", sock );
#endif
    
    [_readData setData:[NSData data]];
    [_readState setObject:@NO forKey:@"dangling_ESC"];
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
}

- (void) udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)error
{
}

@end
