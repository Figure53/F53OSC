//
//  F53OSCClient.m
//  F53OSC
//
//  Created by Siobhán Dougall on 1/20/11.
//  Copyright (c) 2011-2025 Figure 53 LLC, https://figure53.com
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
#error This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#import "F53OSCClient.h"

#import "F53OSCParser.h"
#import "F53OSCEncryptHandshake.h"


NS_ASSUME_NONNULL_BEGIN

@interface F53OSCClient ()

@property (strong, nullable)    F53OSCSocket *socket;
@property (strong, nullable)    NSMutableData *readData;
@property (strong, nullable)    NSMutableDictionary<NSString *, id> *readState;

- (void) destroySocket;
- (void) createSocket;

@end

@implementation F53OSCClient

+ (BOOL) supportsSecureCoding
{
    return YES;
}

- (instancetype) init
{
    self = [super init];
    if ( self )
    {
        _socketDelegateQueue = dispatch_get_main_queue();
        self.delegate = nil;
        self.interface = nil;
        self.host = @"localhost";
        self.port = 53000; // QLab default listening port
        self.IPv6Enabled = NO;
        self.useTcp = NO;
        self.tcpTimeout = -1;   // no timeout
        self.readChunkSize = 0; // no partial reads
        self.userData = nil;
        self.socket = nil;
        self.readData = [NSMutableData data];
        self.readState = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void) dealloc
{
    _delegate = nil;

    [self destroySocket];
}

- (void) encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.interface forKey:@"interface"];
    [coder encodeObject:self.host forKey:@"host"];
    [coder encodeObject:[NSNumber numberWithUnsignedShort:self.port] forKey:@"port"];
    [coder encodeObject:[NSNumber numberWithBool:self.isIPv6Enabled] forKey:@"IPv6Enabled"];
    [coder encodeObject:[NSNumber numberWithBool:self.useTcp] forKey:@"useTcp"];
    [coder encodeObject:[NSNumber numberWithDouble:self.tcpTimeout] forKey:@"tcpTimeout"];
    [coder encodeObject:[NSNumber numberWithUnsignedInteger:self.readChunkSize] forKey:@"readChunkSize"];
    [coder encodeObject:self.userData forKey:@"userData"];
}

- (nullable instancetype) initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if ( self )
    {
        _socketDelegateQueue = dispatch_get_main_queue();
        self.delegate = nil;
        self.interface = [coder decodeObjectOfClass:[NSString class] forKey:@"interface"];
        self.host = [coder decodeObjectOfClass:[NSString class] forKey:@"host"];
        self.port = [[coder decodeObjectOfClass:[NSNumber class] forKey:@"port"] unsignedShortValue];
        self.IPv6Enabled = [[coder decodeObjectOfClass:[NSNumber class] forKey:@"IPv6Enabled"] boolValue];
        self.useTcp = [[coder decodeObjectOfClass:[NSNumber class] forKey:@"useTcp"] boolValue];
        self.tcpTimeout = [[coder decodeObjectOfClass:[NSNumber class] forKey:@"tcpTimeout"] doubleValue];
        self.readChunkSize = [[coder decodeObjectOfClass:[NSNumber class] forKey:@"readChunkSize"] unsignedIntegerValue];
        self.userData = [coder decodeObjectOfClass:[NSObject class] forKey:@"userData"];
        self.socket = nil;
        self.readData = [NSMutableData data];
        self.readState = [NSMutableDictionary dictionary];
    }
    return self;
}

- (NSString *) description
{
    return [NSString stringWithFormat:@"<F53OSCClient %@:%hu>", self.host, self.port ];
}

- (void) setSocketDelegateQueue:(nullable dispatch_queue_t)queue
{
    BOOL recreateSocket = ( self.socket != nil );
    if ( recreateSocket )
        [self destroySocket];
    
    if ( !queue )
        queue = dispatch_get_main_queue();
    
    @synchronized( self )
    {
        _socketDelegateQueue = queue;
    }
    
    if ( recreateSocket )
        [self createSocket];
}

- (void) destroySocket
{
    self.readState[@"socket"] = nil;
    
    [self.socket disconnect];
    if ( self.useTcp )
        [self.socket.tcpSocket synchronouslySetDelegate:nil delegateQueue:nil];
    else
        [self.socket.udpSocket synchronouslySetDelegate:nil delegateQueue:nil];
    _socket = nil;
}

- (void) createSocket
{
    F53OSCSocket *socket;

    if ( self.useTcp )
    {
        GCDAsyncSocket *tcpSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:self.socketDelegateQueue];
        socket = [F53OSCSocket socketWithTcpSocket:tcpSocket];
        self.readState[@"socket"] = socket;
    }
    else // use UDP
    {
        GCDAsyncUdpSocket *udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:self.socketDelegateQueue];
        socket = [F53OSCSocket socketWithUdpSocket:udpSocket];
    }
    socket.interface = self.interface;
    socket.IPv6Enabled = self.isIPv6Enabled;
    socket.host = self.host;
    socket.port = self.port;

    self.socket = socket;
}

- (void) setInterface:(nullable NSString *)interface
{
    // GCDAsyncSocket interprets "nil" as "allow the OS to decide what interface to use".
    // So here we additionally interpret "" as nil.
    if ( [interface isEqualToString:@""] )
        interface = nil;
    
    _interface = [interface copy];
    self.socket.interface = _interface;
}

- (void) setHost:(nullable NSString *)host
{
    if ( [host isEqualToString:@""] )
        host = nil;
    
    _host = [host copy];
    self.socket.host = self.host;

    _hostIsLocal = ( !_host.length ||
                    [_host isEqualToString:@"localhost"] ||
                    [_host isEqualToString:@"127.0.0.1"] );
}

- (void) setPort:(UInt16)port
{
    _port = port;
    self.socket.port = _port;
}

- (void) setIPv6Enabled:(BOOL)IPv6Enabled
{
    _IPv6Enabled = IPv6Enabled;
    self.socket.IPv6Enabled = _IPv6Enabled;
}

- (void) setUseTcp:(BOOL)flag
{
    if ( _useTcp == flag )
        return;
    
    _useTcp = flag;
    
    [self destroySocket];
}

- (void) setTcpTimeout:(NSTimeInterval)tcpTimeout
{
    if ( tcpTimeout <= 0.0 )
        tcpTimeout = -1.0;

    _tcpTimeout = tcpTimeout;
}

- (void) setUserData:(nullable id)userData
{
    if ( userData == [NSNull null] )
        userData = nil;
    
    _userData = userData;
}

- (NSDictionary<NSString *, id> *) state
{
    return @{
        @"interface": self.interface ? self.interface : @"",
        @"host": self.host ? self.host : @"",
        @"port": @( self.port ),
        @"useTcp": @( self.useTcp ),
        @"tcpTimeout": @( self.tcpTimeout ),
        @"userData": ( self.userData ? self.userData : [NSNull null] )
    };
}

- (void) setState:(NSDictionary<NSString *, id> *)state
{
    self.interface = state[@"interface"];
    self.host = state[@"host"];
    self.port = [state[@"port"] unsignedIntValue];
    self.useTcp = [state[@"useTcp"] boolValue];
    self.tcpTimeout = [state[@"tcpTimeout"] doubleValue];
    self.userData = state[@"userData"];
}

- (NSString *) title
{
    if ( self.isValid )
        return [NSString stringWithFormat:@"%@ : %hu", self.host, self.port ];
    else
        return [NSString stringWithFormat:@"<invalid>" ];
}

- (BOOL) isValid
{
    if ( self.host && self.port )
        return YES;
    else
        return NO;
}

- (BOOL) isConnected
{
    return [self.socket isConnected];
}

- (BOOL) connect
{
    if ( !self.socket )
        [self createSocket]; // should always create a socket
    if ( !self.socket )
        return NO;

    return [self.socket connect];
}

- (BOOL) connectEncryptedWithKeyPair:(NSData *)keyPair
{
    if ( !self.socket )
        [self createSocket]; // should always create a socket
    [self.socket setKeyPair:keyPair];
    if ( !self.socket )
        return NO;

    return [self.socket connect];
}

- (void) disconnect
{
    [self.socket disconnect];
    [self.readData setData:[NSData data]];
    self.readState[@"dangling_ESC"] = @NO;
}

- (void) sendPacket:(F53OSCPacket *)packet
{
    [self connect];
    
#if F53_OSC_CLIENT_DEBUG
    NSLog( @"%@ sending packet: %@", self, packet );
#endif
    
    if ( self.socket )
    {
        [self.socket sendPacket:packet];
    }
    else
    {
        NSLog( @"Error: F53OSCClient could not send data; no socket available." );
    }
}

- (void) handleF53OSCControlMessage:(F53OSCMessage *)message
{
    if ( self.socket.encrypter && [F53OSCEncryptHandshake isEncryptHandshakeMessage:message] )
    {
        F53OSCEncryptHandshake *handshake = [F53OSCEncryptHandshake handshakeWithEncrypter:self.socket.encrypter];
        if ( [handshake processHandshakeMessage:message] )
        {
            if ( handshake.lastProcessedMessage == F53OSCEncryptionHandshakeMessageApprove )
            {
                F53OSCMessage *beginMessage = [handshake beginEncryptionMessage];
                [self sendPacket:beginMessage];
                self.socket.isEncrypting = YES;
                [self tellDelegateDidConnect];
            }
            else
            {
                NSLog(@"Error: received unexpected F53OSC encryption handshake message: %@", message);
            }
        }
    }
    else
    {
        NSLog(@"Error: unknown F53OSC control message received: %@", message);
    }
}

#pragma mark - GCDAsyncSocketDelegate

- (nullable dispatch_queue_t) newSocketQueueForConnectionFromAddress:(NSData *)address onSocket:(GCDAsyncSocket *)sock
{
    return self.socketDelegateQueue;
}

- (void) socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    // Client objects do not accept new incoming connections.
}

- (void) socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port
{
#if F53_OSC_CLIENT_DEBUG
    NSLog( @"client socket %p didConnectToHost %@:%hu", sock, host, port );
#endif

    if ( self.readChunkSize )
        [sock readDataWithTimeout:self.tcpTimeout buffer:nil bufferOffset:0 maxLength:self.readChunkSize tag:0];
    else
        [sock readDataWithTimeout:self.tcpTimeout tag:0];

    if ( self.socket.encrypter )
    {
        F53OSCEncryptHandshake *handshake = [F53OSCEncryptHandshake handshakeWithEncrypter:self.socket.encrypter];
        F53OSCMessage *requestMessage = [handshake requestEncryptionMessage];
        if ( requestMessage )
        {
            [self sendPacket:requestMessage];
            return;
        }
    }

    // else
    [self tellDelegateDidConnect];
}

- (void) tellDelegateDidConnect
{
    if ( [self.delegate respondsToSelector:@selector(clientDidConnect:)] )
    {
        dispatch_block_t block = ^{
            [self.delegate clientDidConnect:self];
        };
        
        if ( [NSThread isMainThread] )
            block();
        else
            dispatch_async( dispatch_get_main_queue(), block );
    }
}

- (void) socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
#if F53_OSC_CLIENT_DEBUG
    NSLog( @"client socket %p didReadData of length %lu. tag : %lu", sock, [data length], tag );
#endif

    [F53OSCParser translateSlipData:data toData:self.readData withState:self.readState destination:self.delegate controlHandler:self];

    if ( self.readChunkSize )
    {
        [self tellDelegateDidRead];
        [sock readDataWithTimeout:self.tcpTimeout buffer:nil bufferOffset:0 maxLength:self.readChunkSize tag:tag];
    }
    else
    {
        [sock readDataWithTimeout:self.tcpTimeout tag:tag];
    }
}

- (void) tellDelegateDidRead
{
    if ( [self.delegate respondsToSelector:@selector(client:didReadData:)] )
    {
        NSUInteger lengthOfCurrentRead = self.readData.length;
        dispatch_block_t block = ^{
            [self.delegate client:self didReadData:lengthOfCurrentRead];
        };
        if ( [NSThread isMainThread] )
            block();
        else
            dispatch_sync( dispatch_get_main_queue(), block ); // synchronous so GUI updates don't lag reality
    }
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
    
    dispatch_block_t block = ^{
        [self.readData setData:[NSData data]];
        self.readState[@"dangling_ESC"] = @NO;
    };
    
    if ( [NSThread isMainThread] )
        block();
    else
        dispatch_async( dispatch_get_main_queue(), block );
}

- (void) socketDidDisconnect:(GCDAsyncSocket *)sock withError:(nullable NSError *)err
{
#if F53_OSC_CLIENT_DEBUG
    NSLog( @"client socket %p didDisconnect", sock );
#endif

    self.socket.isEncrypting = NO;
    
    dispatch_block_t block = ^{
        [self.readData setData:[NSData data]];
        self.readState[@"dangling_ESC"] = @NO;
        
        if ( [self.delegate respondsToSelector:@selector(clientDidDisconnect:)] )
            [self.delegate clientDidDisconnect:self];
    };
    
    if ( [NSThread isMainThread] )
        block();
    else
        dispatch_async( dispatch_get_main_queue(), block );
}

- (void) socketDidSecure:(GCDAsyncSocket *)sock
{
}

#pragma mark - GCDAsyncUdpSocketDelegate

- (void) udpSocket:(GCDAsyncUdpSocket *)sock didConnectToAddress:(NSData *)address
{
}

- (void) udpSocket:(GCDAsyncUdpSocket *)sock didNotConnect:(nullable NSError *)error
{
}

- (void) udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag
{
#if F53_OSC_CLIENT_DEBUG
    NSLog( @"client socket %p didSendDataWithTag: %ld", sock, tag );
#endif
}

- (void) udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(nullable NSError *)error
{
#if F53_OSC_CLIENT_DEBUG
    NSLog( @"client socket %p didNotSendDataWithTag: %ld dueToError: %@", sock, tag, [error localizedDescription] );
#endif
}

- (void) udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(nullable id)filterContext
{
}

- (void) udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(nullable NSError *)error
{
}

@end

NS_ASSUME_NONNULL_END
