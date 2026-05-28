//
//  F53OSCSocket.h
//  F53OSC
//
//  Created by Christopher Ashworth on 1/28/13.
//  Copyright (c) 2013-2026 Figure 53 LLC, https://figure53.com
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

#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN

#define F53_OSC_SOCKET_DEBUG 0

@class F53OSCPacket;
@class F53OSCEncrypt;
@class F53OSCSocket;
@protocol F53OSCSocketDelegate;

typedef NS_ENUM( NSInteger, F53TCPDataFraming ) {
    F53TCPDataFramingNone = -1,
    F53TCPDataFramingSLIP = 0, // Default, OSC 1.1
};

//
//  F53OSCStats tracks socket behavior over time.
//

@interface F53OSCStats : NSObject

- (double) totalBytes;
- (double) bytesPerSecond;       // as calculated over the last second
- (void) addBytes:(double)bytes;

@end


//
//  F53OSCSocketDelegate is the internal callback surface used by F53OSCClient
//  and F53OSCServer to receive events from F53OSCSocket, which wraps the
//  underlying Network.framework handles. All callbacks fire on the socket's
//  callbackQueue.
//

@protocol F53OSCSocketDelegate <NSObject>
@optional

// outbound connection became ready
- (void) socketDidConnect:(F53OSCSocket *)socket;

// a chunk of raw bytes arrived on a TCP connection, or a complete UDP datagram arrived
- (void) socket:(F53OSCSocket *)socket didReceiveData:(NSData *)data;

// connection ended (graceful close, reset, or local cancel)
- (void) socket:(F53OSCSocket *)socket didDisconnectWithError:(nullable NSError *)error;

// a listener accepted a new connection. The new socket is already configured with the
// listener's callbackQueue but has no delegate yet — caller is responsible for assigning
// a delegate before returning
- (void) socket:(F53OSCSocket *)socket didAcceptConnection:(F53OSCSocket *)connection;

@end


//
//  An F53OSCSocket object wraps either a single Network.framework nw_connection_t
//  (for outbound client TCP/UDP, or an accepted inbound TCP/UDP flow) or an
//  nw_listener_t (for TCP/UDP listeners). The two roles are mutually exclusive
//  on any given instance.
//

@interface F53OSCSocket : NSObject

// outbound client constructors
+ (instancetype) outboundTcpSocketWithCallbackQueue:(nullable dispatch_queue_t)queue;
+ (instancetype) outboundUdpSocketWithCallbackQueue:(nullable dispatch_queue_t)queue;

// listener constructors. Server uses these to bind a listening port
+ (instancetype) tcpListenerWithCallbackQueue:(nullable dispatch_queue_t)queue;
+ (instancetype) udpListenerWithCallbackQueue:(nullable dispatch_queue_t)queue;

@property (nonatomic, weak, nullable)           id<F53OSCSocketDelegate> delegate;
@property (nonatomic, strong, readonly)         dispatch_queue_t callbackQueue;

@property (nonatomic, readonly) BOOL isTcpSocket;
@property (nonatomic, readonly) BOOL isUdpSocket;
@property (nonatomic, assign) F53TCPDataFraming tcpDataFraming; // Default SLIP

@property (nonatomic, copy, nullable) NSString *interface;      // Default nil, aka default interface
@property (nonatomic, copy, nullable) NSString *host;           // Default "localhost"
@property (nonatomic, assign) UInt16 port;                      // Default 0
@property (nonatomic, getter=isIPv6Enabled) BOOL IPv6Enabled;

@property (nonatomic, readonly) BOOL hostIsLocal;

// Seconds the TCP connect attempt is allowed to sit in nw_connection_state_waiting
// before we cancel it and deliver a disconnect. Default 30.0, set to 0 to disable
// (lets nw_connection retry indefinitely). UDP ignores this — there's no handshake.
// Matches Swift's OSCClient.Configuration.connectionTimeout.
@property (nonatomic, assign)                   NSTimeInterval connectTimeout;

@property (strong, readonly, nullable) F53OSCStats *stats;

// updated on every receive. Nil until first data arrives. Used by F53OSCServer to sweep idle UDP flows
@property (atomic, strong, readonly, nullable)  NSDate *lastActivityDate;

@property (strong, nullable) F53OSCEncrypt *encrypter;
@property (assign) BOOL isEncrypting;

- (BOOL) startListening;
- (BOOL) startListening:(out NSError **)outError;
- (void) stopListening;

- (BOOL) connect;       // when using TCP, returns NO if already connected
- (void) disconnect;
- (BOOL) isConnected;

- (void) sendPacket:(F53OSCPacket *)packet;

- (void) setKeyPair:(NSData *)keyPair;

@end


@interface F53OSCSocket (DisallowedInits)
- (instancetype)init __attribute__((unavailable("Use one of the +outbound... or +...Listener... factories instead.")));
@end

NS_ASSUME_NONNULL_END
