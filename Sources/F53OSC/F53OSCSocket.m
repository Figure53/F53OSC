//
//  F53OSCSocket.m
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

#if !__has_feature(objc_arc)
#error This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#import <Network/Network.h>
#import <Foundation/Foundation.h>
#import <mach/mach_time.h>
#import <stdatomic.h>

#import "F53OSCSocket.h"

#if __has_include(<F53OSC/F53OSC-Swift.h>) // F53OSC_BUILT_AS_FRAMEWORK
#import <F53OSC/F53OSC-Swift.h>
#elif SWIFT_PACKAGE // Swift Package Manager
@import F53OSCEncrypt;
#endif
#import "F53OSCPacket.h"
#import "F53OSCParser.h"


NS_ASSUME_NONNULL_BEGIN

#define END             0300    /* indicates end of packet */
#define ESC             0333    /* indicates byte stuffing */
#define ESC_END         0334    /* ESC ESC_END means END data byte */
#define ESC_ESC         0335    /* ESC ESC_ESC means ESC data byte */

// maximum number of times to retry startListening after EADDRINUSE
#define F53OSC_LISTEN_RETRY_MAX    3
// backoff base interval in seconds
#define F53OSC_LISTEN_RETRY_DELAY  0.1

// Default for the per-instance connectTimeout property. Listener-ready
// timeout stays as a file-scope constant — no caller has needed to tune it.
#define F53OSC_CONNECT_TIMEOUT_SEC   30.0
#define F53OSC_LISTEN_READY_TIMEOUT_SEC  10.0


#pragma mark - F53OSCSocketRole

typedef NS_ENUM( NSInteger, F53OSCSocketRole ) {
    F53OSCSocketRoleTCPClient   = 0,
    F53OSCSocketRoleUDPClient   = 1,
    F53OSCSocketRoleTCPListener = 2,
    F53OSCSocketRoleUDPListener = 3,
    F53OSCSocketRoleTCPAccepted = 4,
    F53OSCSocketRoleUDPAccepted = 5,
};


#pragma mark - F53OSCStats

@interface F53OSCStats ()
{
    _Atomic(double) _atomicTotalBytes;
    _Atomic(double) _atomicCurrentBytes;
}

@property (strong) NSDate *currentTime;
@property (strong) dispatch_queue_t timerQueue;
@property (assign) bool stopCounting;

@property (assign) double bytesPerSecond;

@end

@implementation F53OSCStats

- (instancetype) init
{
    self = [super init];
    if ( self )
    {
        atomic_init( &_atomicTotalBytes, 0.0 );
        atomic_init( &_atomicCurrentBytes, 0.0 );
        self.bytesPerSecond = 0;
        self.currentTime = [NSDate date];

        self.stopCounting = NO;
        self.timerQueue = dispatch_queue_create( "com.figure53.F53OSCStats", NULL );
        // keep timer on background thread
        dispatch_async( self.timerQueue, ^{
            [self countBytes];
        } );
    }
    return self;
}

- (double) totalBytes
{
    return atomic_load_explicit( &_atomicTotalBytes, memory_order_relaxed );
}

- (void) countBytes
    {
        NSDate *checkTime = [NSDate date];
        if ( [checkTime timeIntervalSince1970] - [self.currentTime timeIntervalSince1970] >= 1.0 )
        {
        double current = atomic_exchange_explicit( &_atomicCurrentBytes, 0.0, memory_order_relaxed );
        self.bytesPerSecond = current;
        self.currentTime = checkTime;
#if F53_OSC_SOCKET_DEBUG
        NSLog( @"[F53OSCStats] UDP Bytes: %f per second, %f total", current, [self totalBytes] );
#endif
        }

        if ( !self.stopCounting )
        {
            // trigger again after delay
        int64_t delay = (int64_t)( 0.2 * NSEC_PER_SEC );
        dispatch_after( dispatch_time( DISPATCH_TIME_NOW, delay ), self.timerQueue, ^{
                [self countBytes];
        } );
    }
}

- (void) addBytes:(double)bytes
{
    // lock-free atomic fetch-add for double; CAS loop is the portable form since
    // atomic fetch-add is not defined for floating-point by C11
    double expected = atomic_load_explicit( &_atomicTotalBytes, memory_order_relaxed );
    while ( !atomic_compare_exchange_weak_explicit( &_atomicTotalBytes, &expected, expected + bytes,
                                                    memory_order_relaxed, memory_order_relaxed ) )
        ; // retry on contention

    expected = atomic_load_explicit( &_atomicCurrentBytes, memory_order_relaxed );
    while ( !atomic_compare_exchange_weak_explicit( &_atomicCurrentBytes, &expected, expected + bytes,
                                                    memory_order_relaxed, memory_order_relaxed ) )
        ;
}

- (void) completeCurrentInterval
    {
    double current = atomic_exchange_explicit( &_atomicCurrentBytes, 0.0, memory_order_relaxed );
    self.bytesPerSecond = current;
    self.currentTime = [NSDate date];
}

- (void) stop
{
    self.stopCounting = YES;
}

@end


#pragma mark - F53OSCSocket (private class extension)

@interface F53OSCSocket ()

// role assigned at init time; immutable after creation
@property (nonatomic, assign)           F53OSCSocketRole role;

// Network.framework objects — only one of these is live per instance
@property (nonatomic, assign, nullable) nw_connection_t connection; // TCPClient, UDPClient, TCPAccepted, UDPAccepted
@property (nonatomic, assign, nullable) nw_listener_t   listener;   // TCPListener, UDPListener

// last observed connection state (used for isConnected on TCP clients)
@property (nonatomic, assign)           nw_connection_state_t lastConnectionState;

// mutable backing store for the publicly readonly stats property
@property (strong, readwrite, nullable) F53OSCStats *stats;

// private serial queue: all nw_*_set_queue calls use this; delegate calls dispatch to _callbackQueue
@property (nonatomic, strong, readonly) dispatch_queue_t internalQueue;

// designated init (all factory methods funnel here)
- (instancetype) initWithRole:(F53OSCSocketRole)role callbackQueue:(nullable dispatch_queue_t)queue NS_DESIGNATED_INITIALIZER;

// arm receive loop on an established nw_connection_t
- (void) armReceiveOnConnection:(nw_connection_t)conn;

// deliver disconnect event to delegate; nilarg error = graceful close
- (void) deliverDisconnectWithNWError:(nullable nw_error_t)nwError;

@end


#pragma mark - Helper functions

// returns YES if host is a loopback address (guards against requiring interface on loopback)
static BOOL hostIsLoopback( NSString * _Nullable host )
{
    if ( !host || host.length == 0 )
        return NO;
    if ( [host isEqualToString:@"localhost"] )
        return YES;
    if ( [host isEqualToString:@"127.0.0.1"] )
        return YES;
    if ( [host hasPrefix:@"127."] )
        return YES;
    if ( [host isEqualToString:@"::1"] )
        return YES;
    return NO;
}

// convert nw_error_t (may be nil for graceful close) to NSError
static NSError * _Nullable nwErrorToNSError( nw_error_t _Nullable nwError )
{
    if ( !nwError )
        return nil;
    CFErrorRef cfError = nw_error_copy_cf_error( nwError );
    if ( !cfError )
        return nil;
    NSError *error = CFBridgingRelease( cfError );
    return error;
}

// build nw_parameters_t for TCP (no TLS)
static nw_parameters_t makeTCPParameters( void )
{
    nw_parameters_t params = nw_parameters_create_secure_tcp(
        NW_PARAMETERS_DISABLE_PROTOCOL, // no TLS
        NW_PARAMETERS_DEFAULT_CONFIGURATION
    );
    return params;
}

// build nw_parameters_t for UDP (no DTLS)
static nw_parameters_t makeUDPParameters( void )
{
    nw_parameters_t params = nw_parameters_create_secure_udp(
        NW_PARAMETERS_DISABLE_PROTOCOL, // no DTLS
        NW_PARAMETERS_DEFAULT_CONFIGURATION
    );
    return params;
}

// resolve an interface name (e.g. "en0") to an nw_interface_t via a one-shot
// nw_path_monitor_t lookup. returns nil if the name doesn't match any current
// interface or if the monitor doesn't fire within a short deadline.
// synchronous — blocks the calling thread up to ~1s waiting for first path update.
static nw_interface_t _Nullable lookupInterfaceNamed( NSString *name )
{
    if ( !name.length )
        return nil;

    nw_path_monitor_t monitor = nw_path_monitor_create();
    dispatch_queue_t monitorQueue = dispatch_queue_create( "com.figure53.F53OSCSocket.iface-lookup",
                                                           DISPATCH_QUEUE_SERIAL );
    nw_path_monitor_set_queue( monitor, monitorQueue );

    dispatch_semaphore_t sema = dispatch_semaphore_create( 0 );
    __block nw_interface_t found = nil;
    nw_path_monitor_set_update_handler( monitor, ^( nw_path_t path ) {
        nw_path_enumerate_interfaces( path, ^bool( nw_interface_t iface ) {
            const char *ifaceName = nw_interface_get_name( iface );
            if ( ifaceName && strcmp( ifaceName, [name UTF8String] ) == 0 )
            {
                found = iface;
                return false; // stop enumeration
            }
            return true; // continue
        } );
        dispatch_semaphore_signal( sema );
    } );
    nw_path_monitor_start( monitor );

    // 1s deadline; if no path update fires we give up
    dispatch_semaphore_wait( sema, dispatch_time( DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC ) );
    nw_path_monitor_cancel( monitor );
    return found;
}

// apply IPv6Enabled preference to an existing parameters object.
// IPv6Enabled = NO means IPv4-only (legacy setPreferIPv4). IPv6Enabled = YES means
// dual-stack (legacy setIPVersionNeutral); leave nw_ip_options at its default rather
// than forcing nw_ip_version_6, which would block v4 destinations like 127.0.0.1.
static void applyIPVersionToParams( nw_parameters_t params, BOOL IPv6Enabled, BOOL isListener )
{
    if ( IPv6Enabled )
        return; // dual-stack default

    nw_protocol_stack_t stack = nw_parameters_copy_default_protocol_stack( params );
    nw_protocol_options_t ipOptions = nw_protocol_stack_copy_internet_protocol( stack );
    nw_ip_options_set_version( ipOptions, nw_ip_version_4 );

    if ( !isListener )
    {
        // force the local bind onto the v4 stack so DNS doesn't hand us back an AAAA
        nw_endpoint_t localEp = nw_endpoint_create_host( "0.0.0.0", "0" );
        nw_parameters_set_local_endpoint( params, localEp );
    }
}


#pragma mark - F53OSCSocket

@implementation F53OSCSocket
{
    // Lock-free atomic mach-tick timestamp updated on every receive. The
    // public -secondsSinceLastActivity getter subtracts this from
    // mach_continuous_time() and converts the tick delta to seconds via the
    // process timebase. 0 means "no activity yet" and the getter reports -1.0
    // in that case. mach_continuous_time is monotonic and counts through
    // system sleep, which is what we want for idle-flow tracking.
    _Atomic(uint64_t) _atomicLastActivityTicks;

    // Credit-based flow control for outbound nw_connection_send calls. The
    // semaphore is seeded to the per-transport depth (UDP=1, TCP=16). Each send
    // takes a permit, each completion handler returns one. Prevents the caller
    // from outpacing what NW.framework and the kernel can accept, which on UDP
    // otherwise overflows net.inet.udp.recvspace silently.
    dispatch_semaphore_t _sendPipelineSemaphore;
}

#pragma mark - Factory methods

+ (instancetype) outboundTcpSocketWithCallbackQueue:(nullable dispatch_queue_t)queue
{
    return [[F53OSCSocket alloc] initWithRole:F53OSCSocketRoleTCPClient callbackQueue:queue];
}

+ (instancetype) outboundUdpSocketWithCallbackQueue:(nullable dispatch_queue_t)queue
{
    return [[F53OSCSocket alloc] initWithRole:F53OSCSocketRoleUDPClient callbackQueue:queue];
}

+ (instancetype) tcpListenerWithCallbackQueue:(nullable dispatch_queue_t)queue
{
    return [[F53OSCSocket alloc] initWithRole:F53OSCSocketRoleTCPListener callbackQueue:queue];
}

+ (instancetype) udpListenerWithCallbackQueue:(nullable dispatch_queue_t)queue
{
    return [[F53OSCSocket alloc] initWithRole:F53OSCSocketRoleUDPListener callbackQueue:queue];
}

+ (instancetype) socketWrappingAcceptedConnection:(nw_connection_t)connection
                                            isTcp:(BOOL)isTcp
                                             host:(NSString *)host
                                             port:(UInt16)port
                                    callbackQueue:(dispatch_queue_t)queue
{
    F53OSCSocketRole role = isTcp ? F53OSCSocketRoleTCPAccepted : F53OSCSocketRoleUDPAccepted;
    F53OSCSocket *socket = [[F53OSCSocket alloc] initWithRole:role callbackQueue:queue];
    socket.connection = connection;
    socket.host = host;
    socket.port = port;
    return socket;
}


#pragma mark - Designated initializer

- (instancetype) initWithRole:(F53OSCSocketRole)role callbackQueue:(nullable dispatch_queue_t)queue
{
    self = [super init];
    if ( self )
    {
        _role = role;
        _callbackQueue = queue ? queue : dispatch_get_main_queue();
        _internalQueue = dispatch_queue_create( "com.figure53.F53OSCSocket.internal", DISPATCH_QUEUE_SERIAL );
        _interface = nil;
        _host = @"localhost";
        _port = 0;
        _IPv6Enabled = NO;
        _hostIsLocal = YES; // "localhost" is the default
        _tcpDataFraming = F53TCPDataFramingSLIP;
        _encrypter = nil;
        _isEncrypting = NO;
        _stats = nil;
        _connection = nil;
        _listener = nil;
        _lastConnectionState = nw_connection_state_invalid;
        _connectTimeout = F53OSC_CONNECT_TIMEOUT_SEC;
        atomic_init( &_atomicLastActivityTicks, 0 );

        // UDP gets one in-flight send because the kernel recvbuf is small and
        // drops overflow without notice. `contentProcessed` fires when the kernel
        // accepts the bytes, not when the receiver consumes them, so raising the
        // depth lets the sender outrun the receiver's drain rate and overflow
        // the recvbuf. On some machines, depth 2 currently works while depth 3
        // races ahead and drops packets. 1 is the only value we can guarantee.
        //
        // TCP gets a deeper pipeline because the kernel sendbuf is much larger
        // and TCP handles retransmission: large enough to keep the wire fed across
        // completion-callback round trips, small enough to bound runaway producer
        // queueing. Anywhere from ~4 to ~64 would behave similarly.
        NSInteger depth = ( role == F53OSCSocketRoleUDPClient ||
                            role == F53OSCSocketRoleUDPAccepted ) ? 1 : 16;
        _sendPipelineSemaphore = dispatch_semaphore_create( depth );
    }
    return self;
}

// Converts a mach-tick delta to seconds via the process timebase. Timebase is
// constant for the life of the process so we fetch it once.
static NSTimeInterval secondsFromMachTickDelta( uint64_t deltaTicks )
{
    static mach_timebase_info_data_t timebase;
    static dispatch_once_t once;
    dispatch_once( &once, ^{
        mach_timebase_info( &timebase );
    });
    
    // 1 tick = numer/denom nanoseconds. Then divide by NSEC_PER_SEC for seconds.
    // (We multiply first then divide to preserve higher floating point precision.)
    return ( (NSTimeInterval)deltaTicks * (NSTimeInterval)timebase.numer )
         / ( (NSTimeInterval)timebase.denom * (NSTimeInterval)NSEC_PER_SEC );
}

- (NSTimeInterval) secondsSinceLastActivity
{
    uint64_t t = atomic_load_explicit( &_atomicLastActivityTicks, memory_order_relaxed );
    if ( t == 0 )
        return -1.0;

    return secondsFromMachTickDelta( mach_continuous_time() - t );
}

// satisfy the unavailable designated init declared in the header
- (instancetype) init
{
    // Unreachable in practice; the unavailable annotation prevents direct calls.
    return [self initWithRole:F53OSCSocketRoleTCPClient callbackQueue:nil];
}
        

#pragma mark - dealloc

- (void) dealloc
{
    // cancel network objects; do NOT call delegate methods from dealloc
    if ( _connection )
    {
        nw_connection_cancel( _connection );
        _connection = nil;
    }
    if ( _listener )
    {
        nw_listener_cancel( _listener );
        _listener = nil;
    }
    if ( _stats )
    {
        [_stats stop];
        _stats = nil;
    }
}


#pragma mark - description

- (NSString *) description
{
    NSString *proto = self.isTcpSocket ? @"TCP" : @"UDP";
    // TCP carries an isConnected suffix; UDP is connectionless so it doesn't.
    if ( self.isTcpSocket )
        return [NSString stringWithFormat:@"<F53OSCSocket TCP %@:%hu isConnected = %i>",
                self.host, self.port, self.isConnected];
    return [NSString stringWithFormat:@"<F53OSCSocket %@ %@:%hu>",
            proto, self.host, self.port];
}


#pragma mark - Properties

- (BOOL) isTcpSocket
{
    return ( _role == F53OSCSocketRoleTCPClient ||
             _role == F53OSCSocketRoleTCPListener ||
             _role == F53OSCSocketRoleTCPAccepted );
}

- (BOOL) isUdpSocket
{
    return ( _role == F53OSCSocketRoleUDPClient ||
             _role == F53OSCSocketRoleUDPListener ||
             _role == F53OSCSocketRoleUDPAccepted );
}

- (void) setHost:(nullable NSString *)host
{
    BOOL changed = !( (_host == nil && host == nil) ||
                      (_host != nil && host != nil && [_host isEqualToString:host]) );
    if ( !changed )
        return;
        
    _host = [host copy];
        _hostIsLocal = ( !_host.length ||
                        [_host isEqualToString:@"localhost"] ||
                        [_host isEqualToString:@"127.0.0.1"] );

    // invalidate a live UDPClient connection so the next sendPacket: re-creates it to the new destination
    if ( _role == F53OSCSocketRoleUDPClient && _connection != NULL )
    {
        nw_connection_cancel( _connection );
        _connection = NULL;
    }
}

- (void) setPort:(UInt16)port
{
    if ( _port == port )
        return;
    _port = port;

    // invalidate a live UDPClient connection so the next sendPacket: re-creates it to the new port
    if ( _role == F53OSCSocketRoleUDPClient && _connection != NULL )
    {
        nw_connection_cancel( _connection );
        _connection = NULL;
    }
}

- (void) setInterface:(nullable NSString *)interface
{
    BOOL changed = !( (_interface == nil && interface == nil) ||
                      (_interface != nil && interface != nil && [_interface isEqualToString:interface]) );
    if ( !changed )
        return;

    _interface = [interface copy];

    // invalidate a live UDPClient connection so the next sendPacket: re-creates it on the new interface
    if ( _role == F53OSCSocketRoleUDPClient && _connection != NULL )
    {
        nw_connection_cancel( _connection );
        _connection = NULL;
    }
}

- (void) setIPv6Enabled:(BOOL)IPv6Enabled
{
    // The IPv6 preference is applied when we create the nw_connection_t / nw_listener_t
    // at connect / startListening time. Storing it here is sufficient; any live connection
    // would need to be recreated to reflect the change (matching legacy behavior).
    _IPv6Enabled = IPv6Enabled;
}
    

#pragma mark - Key pair / encryption

- (void) setKeyPair:(NSData *)keyPair
{
    self.encrypter = [[F53OSCEncrypt alloc] initWithKeyPairData:keyPair];
}


#pragma mark - Listening (TCPListener / UDPListener roles only)

- (BOOL) startListening
{
    return [self startListening:nil];
}

- (BOOL) startListening:(out NSError **)outError
{
    if ( _role != F53OSCSocketRoleTCPListener && _role != F53OSCSocketRoleUDPListener )
    {
        if ( outError != NULL )
            *outError = [NSError errorWithDomain:@"F53OSCSocketErrorDomain"
                                            code:-1
                                        userInfo:@{ NSLocalizedDescriptionKey : @"startListening is only valid for listener sockets." }];
        return NO;
    }

    // cancel any existing listener before re-binding
    if ( _listener )
    {
        nw_listener_cancel( _listener );
        _listener = nil;
    }

    BOOL isTcp = ( _role == F53OSCSocketRoleTCPListener );
    nw_parameters_t params = isTcp ? makeTCPParameters() : makeUDPParameters();
    nw_parameters_set_reuse_local_address( params, true );
    applyIPVersionToParams( params, _IPv6Enabled, YES );

    // bind to a specific interface by name if requested.
    // listeners have no destination host so there is no loopback carve-out needed here.
    if ( _interface.length )
        {
        nw_interface_t iface = lookupInterfaceNamed( _interface );
        if ( iface )
            nw_parameters_require_interface( params, iface );
        else
        {
            NSLog( @"Warning: %@ interface '%@' not found; cannot bind listener", self, _interface );
            if ( outError != NULL )
                *outError = [NSError errorWithDomain:@"F53OSCSocketErrorDomain"
                                               code:-3
                                           userInfo:@{ NSLocalizedDescriptionKey :
                                                       [NSString stringWithFormat:@"Interface '%@' not found.", _interface] }];
            return NO;
        }
    }

    NSString *portStr = ( _port > 0 ) ? [NSString stringWithFormat:@"%hu", _port] : @"0";

    // retry loop to handle EADDRINUSE (port not yet released by kernel)
    __block BOOL success = NO;
    __block NSError *listenError = nil;
    NSTimeInterval delay = F53OSC_LISTEN_RETRY_DELAY;

    for ( int attempt = 0; attempt <= F53OSC_LISTEN_RETRY_MAX; attempt++ )
    {
        if ( attempt > 0 )
        {
#if F53_OSC_SOCKET_DEBUG
            NSLog( @"[F53OSCSocket] startListening retry %d after EADDRINUSE", attempt );
#endif
            [NSThread sleepForTimeInterval:delay];
            delay *= 2.0; // exponential back-off
        }

        nw_listener_t newListener = nw_listener_create_with_port( [portStr UTF8String], params );
        if ( !newListener )
        {
            listenError = [NSError errorWithDomain:@"F53OSCSocketErrorDomain"
                                             code:-2
                                         userInfo:@{ NSLocalizedDescriptionKey : @"nw_listener_create_with_port returned nil." }];
            break;
        }

        // _internalQueue is the private serial queue for all nw_* callbacks.
        // _callbackQueue (caller-supplied) receives only delegate method invocations.
        nw_listener_set_queue( newListener, _internalQueue );

        // set up accept handler before starting
        F53OSCSocket * __weak weakSelf = self;
        nw_listener_set_new_connection_handler( newListener, ^( nw_connection_t inboundConn ) {
            F53OSCSocket *strongSelf = weakSelf;
            if ( !strongSelf )
                return;

            // determine remote host/port from the endpoint
            nw_endpoint_t remoteEp = nw_connection_copy_endpoint( inboundConn );
            NSString *remoteHost = @"";
            UInt16 remotePort = 0;
            if ( remoteEp )
            {
                const char *hostCStr = nw_endpoint_get_hostname( remoteEp );
                if ( hostCStr )
                    remoteHost = [NSString stringWithUTF8String:hostCStr];
                remotePort = nw_endpoint_get_port( remoteEp );
            }

#if F53_OSC_SOCKET_DEBUG
            NSLog( @"[F53OSCSocket] listener accepted connection from %@:%hu", remoteHost, remotePort );
#endif

            F53OSCSocket *accepted = [F53OSCSocket socketWrappingAcceptedConnection:inboundConn
                                                                              isTcp:isTcp
                                                                               host:remoteHost
                                                                               port:remotePort
                                                                      callbackQueue:strongSelf.callbackQueue];
            // arm receive loop; the delegate will be assigned by whoever receives didAcceptConnection:
            nw_connection_set_queue( inboundConn, accepted.internalQueue );
            nw_connection_start( inboundConn );
            [accepted armReceiveOnConnection:inboundConn];

            // hop to _callbackQueue so the delegate call lands on the queue the caller expects
            dispatch_async( strongSelf.callbackQueue, ^{
                if ( [strongSelf.delegate respondsToSelector:@selector(socket:didAcceptConnection:)] )
                    [strongSelf.delegate socket:strongSelf didAcceptConnection:accepted];
            });
        } );

        // wait for listener to become ready
        dispatch_semaphore_t sema = dispatch_semaphore_create( 0 );
        __block BOOL listenerReady = NO;
        __block int32_t errorCode = 0;

        nw_listener_set_state_changed_handler( newListener, ^( nw_listener_state_t state, nw_error_t _Nullable err ) {
#if F53_OSC_SOCKET_DEBUG
            NSLog( @"[F53OSCSocket] listener state changed: %d err=%@", (int)state, nwErrorToNSError(err) );
#endif
            if ( state == nw_listener_state_ready )
            {
                listenerReady = YES;
                dispatch_semaphore_signal( sema );
            }
            else if ( state == nw_listener_state_failed || state == nw_listener_state_cancelled )
            {
                if ( err )
                {
                    nw_error_domain_t domain = nw_error_get_error_domain( err );
                    errorCode = nw_error_get_error_code( err );
                    // log the domain for debugging
                    (void)domain;
                }
                dispatch_semaphore_signal( sema );
            }
        } );

        nw_listener_start( newListener );
        dispatch_time_t deadline = dispatch_time( DISPATCH_TIME_NOW,
                                                  (int64_t)(F53OSC_LISTEN_READY_TIMEOUT_SEC * NSEC_PER_SEC) );
        if ( dispatch_semaphore_wait( sema, deadline ) != 0 )
        {
            NSLog( @"Error: %@ listener did not reach ready state within %.1fs",
                   self, F53OSC_LISTEN_READY_TIMEOUT_SEC );
            nw_listener_cancel( newListener );
        }

        if ( listenerReady )
        {
            _listener = newListener;
            success = YES;

            // If the caller requested port 0 (kernel-assigned), write back the
            // actual port so callers can discover it via the port property.
            // Harmless when the caller specified a fixed port.
            _port = nw_listener_get_port( newListener );

            // create stats object for UDP listeners
            if ( _role == F53OSCSocketRoleUDPListener && !_stats )
                _stats = [[F53OSCStats alloc] init];

            break;
        }
        else
        {
            nw_listener_cancel( newListener );

            // POSIX domain EADDRINUSE → retry
            if ( errorCode == EADDRINUSE )
                continue;

            // other errors: stop retrying
            listenError = [NSError errorWithDomain:NSPOSIXErrorDomain
                                             code:errorCode
                                         userInfo:@{ NSLocalizedDescriptionKey :
                                                     [NSString stringWithFormat:@"nw_listener failed with code %d", errorCode] }];
            break;
        }
    }

    if ( !success && outError != NULL )
        *outError = listenError;

    return success;
}

- (void) stopListening
{
    if ( _listener )
    {
        nw_listener_cancel( _listener );
        _listener = nil;
    }

    if ( _stats )
    {
        [_stats stop];
        _stats = nil;
    }
}


#pragma mark - Connection (client roles)

- (BOOL) connect
{
    if ( _role == F53OSCSocketRoleTCPListener || _role == F53OSCSocketRoleUDPListener )
        return NO;

    if ( _role == F53OSCSocketRoleTCPClient )
    {
        if ( _lastConnectionState == nw_connection_state_ready )
        {
#if F53_OSC_SOCKET_DEBUG
            NSLog( @"[F53OSCSocket] TCP connect: already connected" );
#endif
            return NO; // already connected (matches legacy behavior: returns NO when already in ready state)
        }

        if ( !_host || !_port )
            return NO;

        // cancel any old connection before creating a new one
        if ( _connection )
        {
            nw_connection_cancel( _connection );
            _connection = nil;
        }

        nw_parameters_t params = makeTCPParameters();
        applyIPVersionToParams( params, _IPv6Enabled, NO );

        // bind to a specific interface by name, with loopback carve-out: setting
        // requiredInterface against a loopback host produces no path, leaving the
        // nw_connection stuck in .waiting forever. hostIsLoopback() gates the call.
        if ( _interface.length && !hostIsLoopback( _host ) )
        {
            nw_interface_t iface = lookupInterfaceNamed( _interface );
            if ( iface )
                nw_parameters_require_interface( params, iface );
        else
            {
                NSLog( @"Warning: %@ interface '%@' not found; ignoring", self, _interface );
            return NO;
    }
        }

        NSString *portStr = [NSString stringWithFormat:@"%hu", _port];
        nw_endpoint_t endpoint = nw_endpoint_create_host( [_host UTF8String], [portStr UTF8String] );
        nw_connection_t newConn = nw_connection_create( endpoint, params );
        if ( !newConn )
            return NO;

        _connection = newConn;
        nw_connection_set_queue( newConn, _internalQueue );

        // Non-blocking connect, matching legacy GCDAsyncSocket -connectToHost:onPort:
        // semantics: a YES return means "the syscall to start connecting succeeded",
        // not "the connection is ready." Callers wait for -socketDidConnect: via the
        // F53OSCSocketDelegate. Blocking the calling thread here would deadlock when
        // a server on the same thread (e.g. main with default queues in tests) needs
        // to run its accept handler to complete the handshake.
        F53OSCSocket * __weak weakSelf = self;
        nw_connection_set_state_changed_handler( newConn, ^( nw_connection_state_t state, nw_error_t _Nullable err ) {
            F53OSCSocket *strongSelf = weakSelf;
            if ( !strongSelf )
                return;

#if F53_OSC_SOCKET_DEBUG
            NSLog( @"[F53OSCSocket] TCP client state: %d err=%@", (int)state, nwErrorToNSError(err) );
#endif

            strongSelf.lastConnectionState = state;

            if ( state == nw_connection_state_ready )
            {
                [strongSelf armReceiveOnConnection:newConn];
                dispatch_async( strongSelf->_callbackQueue, ^{
                    if ( [strongSelf.delegate respondsToSelector:@selector(socketDidConnect:)] )
                        [strongSelf.delegate socketDidConnect:strongSelf];
                });
            }
            else if ( state == nw_connection_state_failed || state == nw_connection_state_cancelled )
            {
                [strongSelf deliverDisconnectWithNWError:err];
            }
            // nw_connection_state_waiting: no-op; the connection is still trying.
        } );

        nw_connection_start( newConn );

        // Async watchdog: if the connection hasn't reached .ready by connectTimeout,
        // cancel it. The state handler then fires .cancelled and we deliver disconnect.
        // nw_connection_state_waiting can otherwise persist indefinitely with no
        // failure callback.
        NSTimeInterval timeout = _connectTimeout;
        if ( timeout > 0 )
        {
            nw_connection_t watchedConn = newConn;
            dispatch_after( dispatch_time( DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC) ),
                            _internalQueue, ^{
                F53OSCSocket *strongSelf = weakSelf;
                if ( !strongSelf )
                    return;
                // Only cancel if we never reached .ready and the connection is still ours.
                if ( strongSelf->_connection == watchedConn
                     && strongSelf->_lastConnectionState != nw_connection_state_ready
                     && strongSelf->_lastConnectionState != nw_connection_state_cancelled
                     && strongSelf->_lastConnectionState != nw_connection_state_failed )
                {
                    NSLog( @"Error: %@ TCP connect timed out after %.1fs; cancelling",
                           strongSelf, timeout );
                    nw_connection_cancel( watchedConn );
                }
            });
        }
        return YES;
    }

    if ( _role == F53OSCSocketRoleUDPClient )
    {
        // UDP "connect" is best-effort: start the connection and return YES
        // (legacy code did not block waiting for UDP to become ready)
        if ( _connection )
            return YES; // already started

        if ( !_host || !_port )
            return NO;

        nw_parameters_t params = makeUDPParameters();
        applyIPVersionToParams( params, _IPv6Enabled, NO );
        nw_parameters_set_reuse_local_address( params, true );

        // bind to a specific interface by name, with loopback carve-out: setting
        // requiredInterface against a loopback host produces no path, leaving the
        // nw_connection stuck in .waiting forever. hostIsLoopback() gates the call.
        if ( _interface.length && !hostIsLoopback( _host ) )
        {
            nw_interface_t iface = lookupInterfaceNamed( _interface );
            if ( iface )
                nw_parameters_require_interface( params, iface );
            else
            {
                NSLog( @"Warning: %@ interface '%@' not found; ignoring", self, _interface );
                return NO;
            }
        }

        NSString *portStr = [NSString stringWithFormat:@"%hu", _port];
        nw_endpoint_t endpoint = nw_endpoint_create_host( [_host UTF8String], [portStr UTF8String] );
        nw_connection_t newConn = nw_connection_create( endpoint, params );
        if ( !newConn )
            return NO;

        _connection = newConn;
        nw_connection_set_queue( newConn, _internalQueue );

        F53OSCSocket * __weak weakSelf = self;
        nw_connection_set_state_changed_handler( newConn, ^( nw_connection_state_t state, nw_error_t _Nullable err ) {
            F53OSCSocket *strongSelf = weakSelf;
            if ( !strongSelf )
                return;
#if F53_OSC_SOCKET_DEBUG
            NSLog( @"[F53OSCSocket] UDP client state: %d err=%@", (int)state, nwErrorToNSError(err) );
#endif
            strongSelf.lastConnectionState = state;
            if ( state == nw_connection_state_failed || state == nw_connection_state_cancelled )
                [strongSelf deliverDisconnectWithNWError:err];
        } );

        nw_connection_start( newConn );
        return YES;
    }

    return NO;
}

- (void) disconnect
{
    if ( _connection )
    {
        if ( _role == F53OSCSocketRoleTCPAccepted )
            nw_connection_force_cancel( _connection ); // RST to avoid TIME_WAIT on listener restart
        else
            nw_connection_cancel( _connection ); // graceful
        _connection = nil;
    }
    _lastConnectionState = nw_connection_state_invalid;
}

- (BOOL) isConnected
{
    if ( _role == F53OSCSocketRoleTCPClient || _role == F53OSCSocketRoleTCPAccepted )
        return ( _lastConnectionState == nw_connection_state_ready );

    if ( _role == F53OSCSocketRoleUDPClient || _role == F53OSCSocketRoleUDPAccepted )
        return ( _connection != nil );

    // listeners don't have a meaningful "connected" state
    return NO;
}


#pragma mark - Receive arming

- (void) armReceiveOnConnection:(nw_connection_t)conn
{
    BOOL isTcp = self.isTcpSocket;
    F53OSCSocket * __weak weakSelf = self;

    if ( isTcp )
    {
        // byte-stream: receive 1..65536 bytes per callback; re-arm until error or close
        nw_connection_receive( conn, 1, 65536, ^( dispatch_data_t _Nullable content,
                                                   nw_content_context_t _Nullable ctx,
                                                   bool is_complete,
                                                   nw_error_t _Nullable error ) {
            F53OSCSocket *strongSelf = weakSelf;
            if ( !strongSelf )
                return;

            if ( error )
            {
                [strongSelf deliverDisconnectWithNWError:error];
                return;
            }

            if ( content && dispatch_data_get_size( content ) > 0 )
            {
                // flatten dispatch_data → NSData
                size_t totalSize = dispatch_data_get_size( content );
                NSMutableData *buffer = [NSMutableData dataWithCapacity:totalSize];
                dispatch_data_apply( content, ^bool( dispatch_data_t  _Nonnull region,
                                                     size_t           offset,
                                                     const void      *bytes,
                                                     size_t           size ) {
                    [buffer appendBytes:bytes length:size];
                    return true;
                } );

                // stamp activity before yielding to the delegate
                atomic_store_explicit( &strongSelf->_atomicLastActivityTicks,
                                       mach_continuous_time(),
                                       memory_order_relaxed );

                dispatch_async( strongSelf->_callbackQueue, ^{
                    if ( [strongSelf.delegate respondsToSelector:@selector(socket:didReceiveData:)] )
                        [strongSelf.delegate socket:strongSelf didReceiveData:buffer];
                });
            }

            if ( is_complete && ( !content || dispatch_data_get_size( content ) == 0 ) )
            {
                // graceful close (FIN received with no data)
                [strongSelf deliverDisconnectWithNWError:nil];
                return;
            }

            // re-arm for next chunk
            [strongSelf armReceiveOnConnection:conn];
        } );
    }
    else
    {
        // datagram: one complete datagram per callback; re-arm before delivering so the kernel
        // buffer keeps draining during bursts
        nw_connection_receive_message( conn, ^( dispatch_data_t _Nullable content,
                                                nw_content_context_t _Nullable ctx,
                                                bool is_complete,
                                                nw_error_t _Nullable error ) {
            F53OSCSocket *strongSelf = weakSelf;
            if ( !strongSelf )
                return;

            // re-arm before delivering (keeps drain going during bursts)
            if ( !error )
                [strongSelf armReceiveOnConnection:conn];

            if ( error )
            {
                [strongSelf deliverDisconnectWithNWError:error];
                return;
            }

            if ( content && dispatch_data_get_size( content ) > 0 )
            {
                size_t totalSize = dispatch_data_get_size( content );
                NSMutableData *buffer = [NSMutableData dataWithCapacity:totalSize];
                dispatch_data_apply( content, ^bool( dispatch_data_t  _Nonnull region,
                                                     size_t           offset,
                                                     const void      *bytes,
                                                     size_t           size ) {
                    [buffer appendBytes:bytes length:size];
                    return true;
                } );

                // stamp activity before yielding to the delegate (used by idle-sweep in F53OSCServer)
                atomic_store_explicit( &strongSelf->_atomicLastActivityTicks,
                                      mach_continuous_time(),
                                      memory_order_relaxed );

                dispatch_async( strongSelf->_callbackQueue, ^{
                    if ( [strongSelf.delegate respondsToSelector:@selector(socket:didReceiveData:)] )
                        [strongSelf.delegate socket:strongSelf didReceiveData:buffer];
                });
            }
        } );
    }
}


#pragma mark - Disconnect delivery helper

- (void) deliverDisconnectWithNWError:(nullable nw_error_t)nwError
{
    // Guard against double-delivery: nw_connection can transition .failed -> .cancelled
    // (we cancel the connection on .failed for cleanup), which would otherwise fire
    // socket:didDisconnectWithError: twice. lastConnectionState being .cancelled is
    // our marker that disconnect has already been reported for this connection.
    if ( _lastConnectionState == nw_connection_state_cancelled )
        return;

    NSError *error = nwErrorToNSError( nwError );
    _lastConnectionState = nw_connection_state_cancelled;

    dispatch_async( _callbackQueue, ^{
        if ( [self->_delegate respondsToSelector:@selector(socket:didDisconnectWithError:)] )
            [self->_delegate socket:self didDisconnectWithError:error];
    });
}


#pragma mark - sendPacket:

- (void) sendPacket:(F53OSCPacket *)packet
{
#if F53_OSC_SOCKET_DEBUG
    NSLog( @"%@ sending packet: %@", self, packet );
#endif

    if ( packet == nil )
        return;

    NSData *data = [packet packetData];

    if ( self.isEncrypting )
    {
        NSData *encrypted = [self.encrypter encryptDataWithClearData:data];
        char marker = '*';
        NSMutableData *newData = [NSMutableData dataWithBytes:&marker length:1];
        [newData appendData:encrypted];
        data = newData;
    }

    if ( self.isTcpSocket )
    {
        switch ( self.tcpDataFraming )
        {
            case F53TCPDataFramingNone:
                break;

            case F53TCPDataFramingSLIP:
                data = [F53OSCParser slipFrameData:data];
                break;
        }

        if ( !_connection )
        {
            NSLog( @"Error: %@ TCP send failed; no connection.", self );
            return;
    }

        // dispatch_data_create with DEFAULT destructor copies the bytes — safe after data release
        dispatch_data_t sendData = dispatch_data_create( [data bytes], [data length],
                                                         _callbackQueue,
                                                         DISPATCH_DATA_DESTRUCTOR_DEFAULT );
        dispatch_semaphore_t sema = _sendPipelineSemaphore;
        dispatch_semaphore_wait( sema, DISPATCH_TIME_FOREVER );
        nw_connection_send( _connection, sendData, NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT,
                            true, ^( nw_error_t _Nullable error ) {
            dispatch_semaphore_signal( sema );
#if F53_OSC_SOCKET_DEBUG
            if ( error )
                NSLog( @"[F53OSCSocket] TCP send error: %@", nwErrorToNSError(error) );
#endif
        } );
    }
    else // UDP
    {
        if ( !_connection )
        {
            // lazy-create the UDP connection on first send
            if ( ![self connect] )
            {
                NSLog( @"Error: %@ UDP send failed; could not start connection.", self );
                return;
            }
        }

        dispatch_data_t sendData = dispatch_data_create( [data bytes], [data length],
                                                         _callbackQueue,
                                                         DISPATCH_DATA_DESTRUCTOR_DEFAULT );
        dispatch_semaphore_t sema = _sendPipelineSemaphore;
        dispatch_semaphore_wait( sema, DISPATCH_TIME_FOREVER );
        nw_connection_send( _connection, sendData, NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT,
                            true, ^( nw_error_t _Nullable error ) {
            dispatch_semaphore_signal( sema );
#if F53_OSC_SOCKET_DEBUG
            if ( error )
                NSLog( @"[F53OSCSocket] UDP send error: %@", nwErrorToNSError(error) );
#endif
        } );
    }
}

- (void) sendRawBytes:(NSData *)bytes
{
    if ( !bytes.length )
        return;
    if ( !_connection )
    {
        NSLog( @"Error: %@ sendRawBytes: failed; no connection.", self );
        return;
    }

    dispatch_data_t sendData = dispatch_data_create( bytes.bytes, bytes.length,
                                                     _callbackQueue,
                                                     DISPATCH_DATA_DESTRUCTOR_DEFAULT );
    dispatch_semaphore_t sema = _sendPipelineSemaphore;
    dispatch_semaphore_wait( sema, DISPATCH_TIME_FOREVER );
    nw_connection_send( _connection, sendData, NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT,
                        true, ^( nw_error_t _Nullable error ) {
        dispatch_semaphore_signal( sema );
#if F53_OSC_SOCKET_DEBUG
        if ( error )
            NSLog( @"[F53OSCSocket] sendRawBytes error: %@", nwErrorToNSError(error) );
#endif
    } );
}

@end

NS_ASSUME_NONNULL_END
