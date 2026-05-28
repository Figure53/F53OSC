//
//  F53OSCClient.m
//  F53OSC
//
//  Created by Siobhán Dougall on 1/20/11.
//  Copyright (c) 2011-2026 Figure 53 LLC, https://figure53.com
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

#import "F53OSCSocket.h"
#import "F53OSCParser.h"
#import "F53OSCEncryptHandshake.h"

#if __has_include(<F53OSC/F53OSC-Swift.h>) // F53OSC_BUILT_AS_FRAMEWORK
#import <F53OSC/F53OSC-Swift.h>
#elif SWIFT_PACKAGE
@import F53OSCEncrypt;
#endif


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
        self.connectTimeout = 30.0; // matches Swift OSCClient.Configuration.connectionTimeout default
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
    _socket = nil;
}

- (void) createSocket
{
    F53OSCSocket *socket;

    if ( self.useTcp )
    {
        socket = [F53OSCSocket outboundTcpSocketWithCallbackQueue:self.socketDelegateQueue];
        self.readState[@"socket"] = socket;
    }
    else // use UDP
    {
        socket = [F53OSCSocket outboundUdpSocketWithCallbackQueue:self.socketDelegateQueue];
    }
    socket.delegate = self;
    socket.interface = self.interface;
    socket.IPv6Enabled = self.isIPv6Enabled;
    socket.host = self.host;
    socket.port = self.port;
    socket.connectTimeout = self.connectTimeout;

    self.socket = socket;
}

- (void) setInterface:(nullable NSString *)interface
{
    // F53OSCSocket interprets nil as "allow the OS to decide what interface to use".
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
        [self createSocket];
    if ( !self.socket )
        return NO;

    return [self.socket connect];
}

- (BOOL) connectEncryptedWithKeyPair:(NSData *)keyPair
{
    if ( !self.socket )
        [self createSocket];
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

#pragma mark - F53OSCSocketDelegate

- (void) socketDidConnect:(F53OSCSocket *)socket
{
#if F53_OSC_CLIENT_DEBUG
    NSLog( @"client socket %p socketDidConnect", socket );
#endif

    // if encryption is requested, send the handshake request and defer
    // tellDelegateDidConnect until the handshake completes.
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

- (void) socket:(F53OSCSocket *)socket didReceiveData:(NSData *)data
{
#if F53_OSC_CLIENT_DEBUG
    NSLog( @"client socket %p didReceiveData of length %lu", socket, [data length] );
#endif

    if ( socket.isTcpSocket )
    {
    [F53OSCParser translateSlipData:data toData:self.readData withState:self.readState destination:self.delegate controlHandler:self];
        [self tellDelegateDidReadDataOfLength:self.readData.length];
    }
    else
    {
        // UDP — single datagram, no SLIP framing.
        [F53OSCParser processOscData:data
                      forDestination:self.delegate
                       replyToSocket:socket
                      controlHandler:nil
                        wasEncrypted:NO];
    }
}

- (void) tellDelegateDidReadDataOfLength:(NSUInteger)length
{
    if ( [self.delegate respondsToSelector:@selector(client:didReadData:)] )
    {
        NSUInteger lengthOfCurrentRead = length;
        dispatch_block_t block = ^{
            [self.delegate client:self didReadData:lengthOfCurrentRead];
        };
        if ( [NSThread isMainThread] )
            block();
        else
            dispatch_sync( dispatch_get_main_queue(), block ); // synchronous so GUI updates don't lag reality
    }
}

- (void) socket:(F53OSCSocket *)socket didDisconnectWithError:(nullable NSError *)error
{
#if F53_OSC_CLIENT_DEBUG
    NSLog( @"client socket %p didDisconnectWithError: %@", socket, error );
#endif

    self.socket.isEncrypting = NO;
    
    dispatch_block_t block = ^{
        [self.readData setData:[NSData data]];
        self.readState[@"dangling_ESC"] = @NO;
        [self tellDelegateDidDisconnect];
    };
    
    if ( [NSThread isMainThread] )
        block();
    else
        dispatch_async( dispatch_get_main_queue(), block );
}

- (void) tellDelegateDidDisconnect
{
        if ( [self.delegate respondsToSelector:@selector(clientDidDisconnect:)] )
            [self.delegate clientDidDisconnect:self];
}

@end

NS_ASSUME_NONNULL_END
