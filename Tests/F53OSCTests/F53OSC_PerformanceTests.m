//
//  F53OSC_PerformanceTests.m
//  F53OSC Tests
//
//  Created by Christopher Cahoon on 5/24/26.
//  Copyright (c) 2026 Figure 53 LLC, https://figure53.com
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
//  Performance characterization suite. Distinct from F53OSC_ThroughputTests
//  which exists as a single-number sanity baseline. This file fans out across
//  payload size, sender concurrency, latency-at-idle, and sustained duration.
//
//  Each test is intentionally structured as a recipe — setUp / measure /
//  tearDown — so the Swift mirror in F53OSC-Swift and the cross-impl bench
//  (docs/PARITY_BENCH_PLAN.md) can be a near-mechanical translation.
//
//  Counter helper lives in F53OSCTestCounter. LatencyTimer and payload /
//  routable-host helpers are inline at the top of this file; they will
//  split out when the bench arrives.
//

#if !__has_feature(objc_arc)
#error This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#import <XCTest/XCTest.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <net/if.h>

#if F53OSC_BUILT_AS_FRAMEWORK
#import <F53OSC/F53OSC.h>
#else
#import "F53OSC.h"
#endif

#import "F53OSCTestCounter.h"


NS_ASSUME_NONNULL_BEGIN


#pragma mark - LatencyTimer

// Records send time per message and the matching delivery time. Computes
// p50 / p99 of the round-trip-ish delay (sender enqueue → server delegate).
// Not a "round trip" in the strict sense because there's no echo back —
// this measures one-way enqueue-to-delivery, which is what most QLab use
// cases actually care about (the time from "send the cue's OSC" to "OSC has
// arrived at the target"). A future test could add a round-trip variant.

@interface LatencyTimer : NSObject <F53OSCServerDelegate>
@property (atomic) NSUInteger sendCount;
@property (atomic) NSUInteger recvCount;
@property (strong, nonatomic) dispatch_semaphore_t doneSemaphore;
- (void) noteSendAtIndex:(NSUInteger)idx;
- (NSArray<NSNumber *> *) deltasMicroseconds;
- (NSTimeInterval) percentile:(double)p;
@end

@implementation LatencyTimer
{
    NSLock *_lock;
    // monotonic timestamps in seconds, indexed by message sequence number
    NSMutableArray<NSNumber *> *_sendTimes;
    NSMutableArray<NSNumber *> *_recvTimes;
    NSInteger _target;
    BOOL _signaled;
}

- (instancetype) init
{
    self = [super init];
    if ( self )
    {
        _lock = [[NSLock alloc] init];
        _sendTimes = [NSMutableArray array];
        _recvTimes = [NSMutableArray array];
        _doneSemaphore = dispatch_semaphore_create( 0 );
    }
    return self;
}

- (void) resetWithExpected:(NSUInteger)expected
{
    [_lock lock];
    _sendTimes = [NSMutableArray arrayWithCapacity:expected];
    _recvTimes = [NSMutableArray arrayWithCapacity:expected];
    self.sendCount = 0;
    self.recvCount = 0;
    _target = (NSInteger)expected;
    _signaled = NO;
    _doneSemaphore = dispatch_semaphore_create( 0 );
    [_lock unlock];
}

- (void) noteSendAtIndex:(NSUInteger)idx
{
    NSTimeInterval now = [[NSProcessInfo processInfo] systemUptime];
    [_lock lock];
    while ( _sendTimes.count <= idx )
        [_sendTimes addObject:@(0)];
    _sendTimes[idx] = @(now);
    self.sendCount = self.sendCount + 1;
    [_lock unlock];
}

- (void) takeMessage:(nullable F53OSCMessage *)message
{
    NSTimeInterval now = [[NSProcessInfo processInfo] systemUptime];
    // Each test message carries its sequence number as its first integer arg.
    NSArray *args = message.arguments;
    NSInteger seq = -1;
    if ( args.count > 0 && [args[0] isKindOfClass:[NSNumber class]] )
        seq = [args[0] integerValue];

    [_lock lock];
    if ( seq >= 0 )
    {
        while ( (NSInteger)_recvTimes.count <= seq )
            [_recvTimes addObject:@(0)];
        _recvTimes[seq] = @(now);
    }
    self.recvCount = self.recvCount + 1;
    if ( !_signaled && _target > 0 && (NSInteger)self.recvCount >= _target )
    {
        _signaled = YES;
        dispatch_semaphore_signal( _doneSemaphore );
    }
    [_lock unlock];
}

- (NSArray<NSNumber *> *) deltasMicroseconds
{
    [_lock lock];
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:_sendTimes.count];
    NSUInteger n = MIN( _sendTimes.count, _recvTimes.count );
    for ( NSUInteger i = 0; i < n; i++ )
    {
        double s = [_sendTimes[i] doubleValue];
        double r = [_recvTimes[i] doubleValue];
        if ( s > 0 && r > 0 )
            [out addObject:@((r - s) * 1e6)];
    }
    [_lock unlock];
    return out;
}

- (NSTimeInterval) percentile:(double)p
{
    NSArray<NSNumber *> *deltas = [self deltasMicroseconds];
    if ( deltas.count == 0 )
        return 0.0;
    NSArray<NSNumber *> *sorted = [deltas sortedArrayUsingSelector:@selector(compare:)];
    NSUInteger idx = (NSUInteger)( p * (sorted.count - 1) );
    return [sorted[idx] doubleValue];
}

- (void) waitForAllWithTimeout:(NSTimeInterval)timeout
{
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    while ( [deadline timeIntervalSinceNow] > 0
            && dispatch_semaphore_wait( _doneSemaphore, DISPATCH_TIME_NOW ) != 0 )
    {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
}

@end


#pragma mark - Payload factory

// Builds OSC messages of a target wire size. The exact size is approximate —
// OSC has 4-byte padding rules — but close enough for size-banded measurements.

static F53OSCMessage * MakeMessageOfSize( NSUInteger targetBytes, NSInteger sequence )
{
    // Address pattern + type tag eats roughly 12-16 bytes for our short pattern.
    // Each integer arg is 4 bytes + 1 tag char. We use one int seq number,
    // and pad with a single NSData blob to hit the target size.
    NSInteger overhead = 24;
    if ( targetBytes <= (NSUInteger)overhead )
    {
        return [F53OSCMessage messageWithAddressPattern:@"/perf"
                                              arguments:@[@(sequence)]];
    }
    NSUInteger blobSize = targetBytes - overhead;
    NSMutableData *blob = [NSMutableData dataWithLength:blobSize];
    // Fill with a non-trivial byte pattern so SLIP framing has real work to do
    // (some bytes hit the END / ESC special cases).
    uint8_t *bytes = blob.mutableBytes;
    for ( NSUInteger i = 0; i < blobSize; i++ )
        bytes[i] = (uint8_t)(i & 0xFF);
    return [F53OSCMessage messageWithAddressPattern:@"/perf"
                                          arguments:@[@(sequence), blob]];
}


#pragma mark - Routable host discovery

// Find a non-loopback IPv4 address belonging to this host. Returns nil if
// no routable interface is available (e.g., test sandbox with no network).
// Sending to this address still gets short-circuited by the kernel and never
// actually crosses any wire, but the packet does traverse the routing layer,
// MAC-cache lookup, and interface scheduling — none of which happens for
// 127.0.0.1. Caveat: this is NOT a real-network test. For true network
// conditions (latency, loss, MTU) you need a second machine or
// NetworkLinkConditioner. Documented at the call sites.

static NSString * _Nullable RoutableHostIPv4(void)
{
    struct ifaddrs *ifa = NULL;
    if ( getifaddrs(&ifa) != 0 )
        return nil;

    NSString *found = nil;
    for ( struct ifaddrs *cur = ifa; cur != NULL; cur = cur->ifa_next )
    {
        if ( !cur->ifa_addr || cur->ifa_addr->sa_family != AF_INET )
            continue;
        if ( !(cur->ifa_flags & IFF_UP) || (cur->ifa_flags & IFF_LOOPBACK) )
            continue;

        char buf[INET_ADDRSTRLEN] = {0};
        struct sockaddr_in *sin = (struct sockaddr_in *)cur->ifa_addr;
        if ( inet_ntop(AF_INET, &sin->sin_addr, buf, sizeof(buf)) )
        {
            found = [NSString stringWithUTF8String:buf];
            // Prefer en0 if present, but accept any routable interface.
            if ( cur->ifa_name && strncmp(cur->ifa_name, "en0", 3) == 0 )
                break;
        }
    }
    freeifaddrs(ifa);
    return found;
}


#pragma mark - F53OSC_PerformanceTests

@interface F53OSC_PerformanceTests : XCTestCase
@end

@implementation F53OSC_PerformanceTests


#pragma mark - Helpers (per-test boilerplate)

// Stand up a UDP server on port 0, register cleanup, return the bound port
// and the server (caller keeps strong refs via the surrounding test block).
- (UInt16) bringUpUDPServer:(out F53OSCServer **)outServer
                  withDelegate:(id<F53OSCServerDelegate>)delegate
{
    F53OSCServer *server = [[F53OSCServer alloc] initWithDelegateQueue:dispatch_get_main_queue()];
    server.port = 0;
    server.delegate = delegate;
    *outServer = server;

    __weak F53OSCServer *weakServer = server;
    [self addTeardownBlock:^{
        [weakServer stopListening];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }];

    XCTAssertTrue( [server startListening], @"UDP server must start" );
    return server.udpSocket.port;
}

- (UInt16) bringUpTCPServer:(out F53OSCServer **)outServer
                  withDelegate:(id<F53OSCServerDelegate>)delegate
{
    F53OSCServer *server = [[F53OSCServer alloc] initWithDelegateQueue:dispatch_get_main_queue()];
    server.port = 0;
    server.delegate = delegate;
    *outServer = server;

    __weak F53OSCServer *weakServer = server;
    [self addTeardownBlock:^{
        [weakServer stopListening];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }];

    XCTAssertTrue( [server startListening], @"TCP server must start" );
    return server.tcpSocket.port;
}

- (F53OSCClient *) bringUpClientWithHost:(NSString *)host
                                      port:(UInt16)port
                                    useTcp:(BOOL)useTcp
                                  delegate:(nullable id<F53OSCClientDelegate>)delegate
{
    F53OSCClient *client = [[F53OSCClient alloc] init];
    client.host = host;
    client.port = port;
    client.useTcp = useTcp;
    client.delegate = delegate;

    __weak F53OSCClient *weakClient = client;
    [self addTeardownBlock:^{
        [weakClient disconnect];
    }];

    if ( useTcp )
    {
        [client connect];
        // wait briefly for handshake; if delegate is a F53OSCTestCounter it signals
        if ( [delegate isKindOfClass:[F53OSCTestCounter class]] )
        {
            F53OSCTestCounter *pc = (F53OSCTestCounter *)delegate;
            NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:5.0];
            while ( [deadline timeIntervalSinceNow] > 0
                    && dispatch_semaphore_wait(pc.connectSemaphore, DISPATCH_TIME_NOW) != 0 )
            {
                [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
            }
            XCTAssertTrue( client.isConnected, @"TCP client must connect" );
        }
    }
    return client;
}


#pragma mark - Latency

// One-way enqueue-to-delivery latency at low rate. The sender pauses briefly
// between messages so each send is measured in isolation (no batching, no
// queue contention). Reports p50 and p99 in microseconds.

- (void) testLatency_UDP_Localhost_LowRate
{
    F53OSCTestCounter *counter = [[F53OSCTestCounter alloc] init];
    LatencyTimer *timer = [[LatencyTimer alloc] init];

    F53OSCServer *server = nil;
    UInt16 port = [self bringUpUDPServer:&server withDelegate:timer];

    F53OSCClient *client = [self bringUpClientWithHost:@"127.0.0.1"
                                                    port:port
                                                  useTcp:NO
                                                delegate:nil];

    NSUInteger const N = 100;
    [timer resetWithExpected:N];

    for ( NSUInteger i = 0; i < N; i++ )
    {
        F53OSCMessage *msg = MakeMessageOfSize( 24, (NSInteger)i );
        [timer noteSendAtIndex:i];
        [client sendPacket:msg];
        // 10ms gap so we're measuring per-message latency, not bulk throughput
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.010]];
    }

    [timer waitForAllWithTimeout:5.0];

    XCTAssertEqual( timer.recvCount, N, @"All low-rate UDP messages should arrive" );
    NSLog(@"UDP low-rate latency (μs): p50=%.1f p99=%.1f over %lu samples",
          [timer percentile:0.50], [timer percentile:0.99], (unsigned long)timer.recvCount);
    (void)counter;
}


// Same shape as above but TCP+SLIP. Establishes a connection first, then
// runs the same low-rate ping pattern.
- (void) testLatency_TCP_Localhost_LowRate
{
    F53OSCTestCounter *connectCounter = [[F53OSCTestCounter alloc] init];
    LatencyTimer *timer = [[LatencyTimer alloc] init];

    F53OSCServer *server = nil;
    UInt16 port = [self bringUpTCPServer:&server withDelegate:timer];

    F53OSCClient *client = [self bringUpClientWithHost:@"127.0.0.1"
                                                    port:port
                                                  useTcp:YES
                                                delegate:connectCounter];

    NSUInteger const N = 100;
    [timer resetWithExpected:N];

    for ( NSUInteger i = 0; i < N; i++ )
    {
        F53OSCMessage *msg = MakeMessageOfSize( 24, (NSInteger)i );
        [timer noteSendAtIndex:i];
        [client sendPacket:msg];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.010]];
    }

    [timer waitForAllWithTimeout:5.0];

    XCTAssertEqual( timer.recvCount, N, @"All low-rate TCP messages should arrive" );
    NSLog(@"TCP low-rate latency (μs): p50=%.1f p99=%.1f over %lu samples",
          [timer percentile:0.50], [timer percentile:0.99], (unsigned long)timer.recvCount);
}


#pragma mark - Realistic payload sizes

// Throughput measured separately for small / medium / large payloads. Each
// has its own measure block so XCTest tracks them as independent metrics.
// Payload sizes chosen to mirror common OSC traffic patterns:
//   small  =  24 B  (typical /cue/N/start with one int arg)
//   medium = 256 B  (cue notes, text strings, small blob)
//   large  = 4 KB   (audio buffer dispatch, large state messages)

- (void) measureThroughputUDPWithPayloadSize:(NSUInteger)payloadBytes
                                            N:(NSUInteger)N
{
    // What this measures: F53OSC's UDP send-path throughput at the given
    // payload size on localhost. The credit-based send pipeline (depth 1 for
    // UDP) gates each nw_connection_send on the prior send's completion,
    // which back-pressures the sender when the kernel buffer fills.
    // Localhost delivery is therefore ~100% even at large payload sizes that
    // would otherwise overflow net.inet.udp.recvspace. Anything materially
    // below 100% on this test points at a send-path regression.
    F53OSCTestCounter *counter = [[F53OSCTestCounter alloc] init];

    F53OSCServer *server = nil;
    UInt16 port = [self bringUpUDPServer:&server withDelegate:counter];

    F53OSCClient *client = [self bringUpClientWithHost:@"127.0.0.1"
                                                    port:port
                                                  useTcp:NO
                                                delegate:nil];

    // Warmup at the same payload size. Short timeout because losses are OK.
    [counter reset];
    NSUInteger warmup = MIN(N / 4, (NSUInteger)1000);
    for ( NSUInteger i = 0; i < warmup; i++ )
        [client sendPacket:MakeMessageOfSize( payloadBytes, (NSInteger)i )];
    [counter waitForCount:warmup timeout:2.0];

    [self measureBlock:^{
        [counter reset];
        counter.targetCount = N;
        for ( NSUInteger i = 0; i < N; i++ )
            [client sendPacket:MakeMessageOfSize( payloadBytes, (NSInteger)i )];
        [counter waitForCount:N timeout:10.0];

        double rate = (double)counter.receivedCount / (double)N * 100.0;
        NSLog(@"UDP %lu-byte payload: %ld of %lu delivered (%.1f%%)",
              (unsigned long)payloadBytes, (long)counter.receivedCount, (unsigned long)N, rate);

        XCTAssertGreaterThanOrEqual( (double)counter.receivedCount, 0.99 * (double)N,
                                     @"UDP %lu-byte payload should deliver near-100%% on localhost",
                                     (unsigned long)payloadBytes );
    }];
}

- (void) testPayload_UDP_Small  { [self measureThroughputUDPWithPayloadSize:24   N:10000]; }
- (void) testPayload_UDP_Medium { [self measureThroughputUDPWithPayloadSize:256  N:10000]; }
- (void) testPayload_UDP_Large  { [self measureThroughputUDPWithPayloadSize:4096 N:5000]; }


// TCP variant of the same recipe. F53OSCTestCounter does double duty as both the
// server's receive delegate (counts arrivals) and the client's delegate
// (signals connect via connectSemaphore). bringUpClientWithHost waits for
// the connect signal before returning.
- (void) measureThroughputTCPWithPayloadSize:(NSUInteger)payloadBytes
                                            N:(NSUInteger)N
{
    F53OSCTestCounter *counter = [[F53OSCTestCounter alloc] init];

    F53OSCServer *server = nil;
    UInt16 port = [self bringUpTCPServer:&server withDelegate:counter];

    F53OSCClient *client = [self bringUpClientWithHost:@"127.0.0.1"
                                                    port:port
                                                  useTcp:YES
                                                delegate:counter];

    [counter reset];
    NSUInteger warmup = MIN(N / 4, (NSUInteger)1000);
    for ( NSUInteger i = 0; i < warmup; i++ )
        [client sendPacket:MakeMessageOfSize( payloadBytes, (NSInteger)i )];
    [counter waitForCount:warmup timeout:5.0];

    [self measureBlock:^{
        [counter reset];
        counter.targetCount = N;
        for ( NSUInteger i = 0; i < N; i++ )
            [client sendPacket:MakeMessageOfSize( payloadBytes, (NSInteger)i )];
        [counter waitForCount:N timeout:10.0];

        if ( counter.receivedCount < (NSInteger)N )
            XCTFail(@"TCP %lu-byte payload: only received %ld of %lu", (unsigned long)payloadBytes, (long)counter.receivedCount, (unsigned long)N);
    }];
}

- (void) testPayload_TCP_Small  { [self measureThroughputTCPWithPayloadSize:24   N:10000]; }
- (void) testPayload_TCP_Medium { [self measureThroughputTCPWithPayloadSize:256  N:10000]; }
- (void) testPayload_TCP_Large  { [self measureThroughputTCPWithPayloadSize:4096 N:5000]; }


#pragma mark - Multi-sender contention

// N concurrent producer queues call sendPacket: on the same F53OSCClient
// instance. Validates that the client's internal queue serializes correctly
// under contention and reports throughput vs the single-sender baseline.
// THIS is the test most likely to reveal queue-topology differences when
// mirrored on F53OSC-Swift (actors vs dispatch queues).

- (void) testMultiSender_UDP_16Producers
{
    // What this measures: F53OSC's send-side serialization under producer
    // contention. 16 concurrent producers call sendPacket: on one client.
    // The credit-based send pipeline (depth 1 for UDP) keeps in-flight sends
    // bounded, which back-pressures the producers when the kernel buffer
    // would otherwise fill. Localhost delivery is therefore ~100% even at 16k
    // datagrams in a burst that would overflow net.inet.udp.recvspace without
    // the pacing.
    F53OSCTestCounter *counter = [[F53OSCTestCounter alloc] init];

    F53OSCServer *server = nil;
    UInt16 port = [self bringUpUDPServer:&server withDelegate:counter];

    F53OSCClient *client = [self bringUpClientWithHost:@"127.0.0.1"
                                                    port:port
                                                  useTcp:NO
                                                delegate:nil];

    NSUInteger const kProducers = 16;
    NSUInteger const kPerProducer = 1000;
    NSUInteger const N = kProducers * kPerProducer;

    [self measureBlock:^{
        [counter reset];
        counter.targetCount = (NSInteger)N;

        dispatch_group_t group = dispatch_group_create();
        for ( NSUInteger p = 0; p < kProducers; p++ )
        {
            dispatch_queue_t q = dispatch_queue_create("f53osc.perf.producer", DISPATCH_QUEUE_SERIAL);
            dispatch_group_async( group, q, ^{
                for ( NSUInteger i = 0; i < kPerProducer; i++ )
                {
                    F53OSCMessage *msg = MakeMessageOfSize( 24, (NSInteger)(p * kPerProducer + i) );
                    [client sendPacket:msg];
                }
            });
        }
        dispatch_group_wait( group, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC)) );

        [counter waitForCount:(NSInteger)N timeout:10.0];

        double rate = (double)counter.receivedCount / (double)N * 100.0;
        NSLog(@"Multi-sender UDP burst: %ld of %lu delivered (%.1f%%)",
              (long)counter.receivedCount, (unsigned long)N, rate);

        XCTAssertGreaterThanOrEqual( (double)counter.receivedCount, 0.99 * (double)N,
                                     @"Multi-sender UDP should deliver near-100%% under send pacing" );
    }];
}

// TCP multi-sender contention. Producers concurrently call sendPacket: on a
// single F53OSCClient over a TCP+SLIP connection. Compared to UDP, TCP
// serialization happens both at F53OSCSocket's internal queue (sender side)
// and in the kernel's TCP send buffer. Worth measuring whether TCP's
// in-order constraint creates additional contention vs the UDP case.
- (void) testMultiSender_TCP_16Producers
{
    F53OSCTestCounter *counter = [[F53OSCTestCounter alloc] init];

    F53OSCServer *server = nil;
    UInt16 port = [self bringUpTCPServer:&server withDelegate:counter];

    F53OSCClient *client = [self bringUpClientWithHost:@"127.0.0.1"
                                                    port:port
                                                  useTcp:YES
                                                delegate:counter];

    NSUInteger const kProducers = 16;
    NSUInteger const kPerProducer = 1000;
    NSUInteger const N = kProducers * kPerProducer;

    [self measureBlock:^{
        [counter reset];
        counter.targetCount = (NSInteger)N;

        dispatch_group_t group = dispatch_group_create();
        for ( NSUInteger p = 0; p < kProducers; p++ )
        {
            dispatch_queue_t q = dispatch_queue_create("f53osc.perf.producer.tcp", DISPATCH_QUEUE_SERIAL);
            dispatch_group_async( group, q, ^{
                for ( NSUInteger i = 0; i < kPerProducer; i++ )
                {
                    F53OSCMessage *msg = MakeMessageOfSize( 24, (NSInteger)(p * kPerProducer + i) );
                    [client sendPacket:msg];
                }
            });
        }
        dispatch_group_wait( group, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC)) );

        [counter waitForCount:(NSInteger)N timeout:15.0];

        if ( counter.receivedCount < (NSInteger)N )
            XCTFail(@"Multi-sender TCP: only %ld of %lu arrived", (long)counter.receivedCount, (unsigned long)N);
    }];
}


#pragma mark - Sustained throughput

// Long-duration steady-state. Measures whether throughput stays flat over
// time or degrades (memory growth, queue saturation, scheduler hiccups).
// Slow by design — gated behind an env var so CI doesn't run it on every PR.

- (void) testSustained_UDP_60s
{
    if ( ![[[NSProcessInfo processInfo] environment][@"F53OSC_RUN_SUSTAINED"] boolValue] )
    {
        XCTSkip(@"Sustained test gated by F53OSC_RUN_SUSTAINED=1");
    }

    F53OSCTestCounter *counter = [[F53OSCTestCounter alloc] init];

    F53OSCServer *server = nil;
    UInt16 port = [self bringUpUDPServer:&server withDelegate:counter];

    F53OSCClient *client = [self bringUpClientWithHost:@"127.0.0.1"
                                                    port:port
                                                  useTcp:NO
                                                delegate:nil];

    NSTimeInterval const duration = 60.0;
    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:duration];
    NSUInteger sent = 0;
    NSUInteger lastRecv = 0;
    NSDate *lastSample = [NSDate date];
    NSMutableArray<NSNumber *> *samples = [NSMutableArray array];

    [counter reset];
    while ( [end timeIntervalSinceNow] > 0 )
    {
        for ( int i = 0; i < 200; i++ )
        {
            [client sendPacket:MakeMessageOfSize( 24, (NSInteger)sent++ )];
        }
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.005]];

        // sample throughput every second
        if ( [[NSDate date] timeIntervalSinceDate:lastSample] >= 1.0 )
        {
            NSUInteger nowRecv = (NSUInteger)counter.receivedCount;
            [samples addObject:@(nowRecv - lastRecv)];
            lastRecv = nowRecv;
            lastSample = [NSDate date];
        }
    }

    NSLog(@"Sustained UDP 60s: sent=%lu recv=%ld per-second samples=%@",
          (unsigned long)sent, (long)counter.receivedCount, samples);

    // Sanity check: at least 80% of messages should have been delivered
    XCTAssertGreaterThan( (double)counter.receivedCount, 0.80 * (double)sent,
                          @"Sustained run lost too many messages" );
}


#pragma mark - Routable network variant

// Send to the host's own non-loopback IPv4 address. Packets traverse the
// routing layer (different code path than 127.0.0.1) but get short-circuited
// by the kernel — they never actually go on the wire. Better than pure
// loopback, but NOT a real LAN test. Skipped when no routable interface
// is available (sandboxed CI).

- (void) testPayload_UDP_RoutableHost_Medium
{
    NSString *host = RoutableHostIPv4();
    if ( !host )
    {
        XCTSkip(@"No non-loopback IPv4 interface available");
    }

    F53OSCTestCounter *counter = [[F53OSCTestCounter alloc] init];

    F53OSCServer *server = nil;
    UInt16 port = [self bringUpUDPServer:&server withDelegate:counter];

    F53OSCClient *client = [self bringUpClientWithHost:host
                                                    port:port
                                                  useTcp:NO
                                                delegate:nil];

    NSUInteger const N = 10000;

    // Warmup
    [counter reset];
    for ( NSUInteger i = 0; i < 1000; i++ )
        [client sendPacket:MakeMessageOfSize( 256, (NSInteger)i )];
    [counter waitForCount:1000 timeout:5.0];

    [self measureBlock:^{
        [counter reset];
        counter.targetCount = (NSInteger)N;
        for ( NSUInteger i = 0; i < N; i++ )
            [client sendPacket:MakeMessageOfSize( 256, (NSInteger)i )];
        [counter waitForCount:(NSInteger)N timeout:2.0];

        double rate = (double)counter.receivedCount / (double)N * 100.0;
        NSLog(@"Routable-host UDP 256-byte: %ld of %lu delivered (%.1f%%)",
              (long)counter.receivedCount, (unsigned long)N, rate);

        if ( counter.receivedCount == 0 )
            XCTFail(@"Routable-host UDP: zero delivery indicates send path broken");
    }];
}

@end


NS_ASSUME_NONNULL_END
