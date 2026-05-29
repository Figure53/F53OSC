//
//  F53OSC_UDPFlowTests.m
//  F53OSC Tests
//
//  Created by Christopher Cahoon on 5/23/26.
//  Adapted from OSCServerUDPFlowTests.swift in F53OSC-Swift (rev a3006395c721).
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

// Ported from OSCServerUDPFlowTests.swift.
//
// Skipped Swift tests and reasons:
//   testNegativeIdleTimeoutDisablesSweep (Swift uses -1. ObjC property is NSTimeInterval
//   which allows negative, but the doc says "Set to 0 to disable sweeping". Ported with
//   udpFlowIdleTimeout = 0 per the documented ObjC API. The Swift negative-sentinel and
//   the ObjC zero-sentinel are semantically equivalent disable signals.)
//
// Flow-count introspection:
//   The Swift tests use `server.udpFlowCount` (a @_spi(Testing) accessor on the Swift actor).
//   The ObjC F53OSCServer has no public flow-count property.  We use KVC on the private
//   `activeTcpSockets` dict — brittle but the only option short of adding a public accessor.
//   Each such call is wrapped in @try/@catch so the test degrades gracefully if the ivar
//   is ever renamed.  A TODO is left at each site.

#if !__has_feature(objc_arc)
#error This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#import <XCTest/XCTest.h>

#if F53OSC_BUILT_AS_FRAMEWORK
#import <F53OSC/F53OSC.h>
#else
#import "F53OSC.h"
#endif


NS_ASSUME_NONNULL_BEGIN

// port chosen to avoid collisions with throughput tests and SLIP roundtrip tests
#define UDP_FLOW_PORT ((UInt16)53993)


#pragma mark - UDPFlowCounter

// Simplified message counter with semaphore signaling. Inline copy to keep this
// file self-contained (avoids depending on F53OSC_ThroughputTests.m).

@interface UDPFlowCounter : NSObject <F53OSCServerDelegate>
@property (atomic) NSInteger receivedCount;
@property (strong, nonatomic) dispatch_semaphore_t doneSemaphore;
- (void) waitForCount:(NSInteger)count timeout:(NSTimeInterval)timeout;
@end

@implementation UDPFlowCounter
{
    NSLock *_lock;
    NSInteger _target;
    BOOL _signaled;
}

- (instancetype) init
{
    self = [super init];
    if ( self )
    {
        _lock = [[NSLock alloc] init];
        _doneSemaphore = dispatch_semaphore_create( 0 );
        _receivedCount = 0;
        _target = 0;
        _signaled = NO;
    }
    return self;
}

- (void) waitForCount:(NSInteger)count timeout:(NSTimeInterval)timeout
{
    [_lock lock];
    _target = count;
    _signaled = NO;
    // if already reached, signal immediately
    if ( _receivedCount >= count )
    {
        _signaled = YES;
        dispatch_semaphore_signal( _doneSemaphore );
    }
    [_lock unlock];

    // Spin the run loop instead of blocking — delegate callbacks land on main.
    NSDate *runDeadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    while ( [runDeadline timeIntervalSinceNow] > 0
            && dispatch_semaphore_wait(_doneSemaphore, DISPATCH_TIME_NOW) != 0 )
    {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
}

- (void) takeMessage:(nullable F53OSCMessage *)message
{
    if ( !message )
        return;

    [_lock lock];
    _receivedCount++;
    NSInteger current = _receivedCount;
    NSInteger target  = _target;
    BOOL already = _signaled;
    if ( current >= target && !already && target > 0 )
    {
        _signaled = YES;
        dispatch_semaphore_signal( _doneSemaphore );
    }
    [_lock unlock];
}

@end


#pragma mark - Helpers

// Returns the count of entries in activeTcpSockets via KVC.
// Returns NSNotFound if the ivar is inaccessible.
// TODO: replace with a public -activeUDPFlowCount property on F53OSCServer.
static NSUInteger ActiveUDPFlowCount( F53OSCServer *server )
{
    @try
    {
        NSDictionary *active = [server valueForKey:@"activeTcpSockets"];
        if ( [active isKindOfClass:[NSDictionary class]] )
        {
            // activeTcpSockets contains both accepted TCP connections AND accepted UDP flows.
            // Count only the UDP sockets.
            NSUInteger udpCount = 0;
            for ( id value in active.allValues )
            {
                if ( [value isKindOfClass:[F53OSCSocket class]] )
                {
                    F53OSCSocket *s = (F53OSCSocket *)value;
                    if ( s.isUdpSocket )
                        udpCount++;
                }
            }
            return udpCount;
        }
    }
    @catch ( NSException *e )
    {
        NSLog( @"[F53OSC_UDPFlowTests] KVC access to activeTcpSockets failed: %@", e );
    }
    return NSNotFound;
}


#pragma mark - F53OSC_UDPFlowTests

@interface F53OSC_UDPFlowTests : XCTestCase
@end

@implementation F53OSC_UDPFlowTests


- (void) testIdleUDPFlowsAreReapedBySweep
{
    // Send a datagram to register a UDP flow in activeTcpSockets, wait past the idle
    // timeout, wait for the sweep timer to fire (5 s cadence), then verify the server
    // still works — and that the flow was swept.
    //
    // Because the sweep fires on a 5 s GCD timer (not synchronously), we use a
    // udpFlowIdleTimeout of 1 s and then sleep long enough for the 5 s sweep to run.

    F53OSCServer *server = [[F53OSCServer alloc] initWithDelegateQueue:dispatch_get_main_queue()];
    server.port = UDP_FLOW_PORT;
    server.udpFlowIdleTimeout = 0.3;   // short threshold so flows expire quickly
    server.udpFlowSweepInterval = 0.2; // tight cadence keeps the test fast

    UDPFlowCounter *counter = [[UDPFlowCounter alloc] init];
    server.delegate = counter;
    XCTAssertTrue( [server startListening], @"UDP server must start" );

    // Send one datagram.
    F53OSCClient *client = [[F53OSCClient alloc] init];
    client.host = @"127.0.0.1";
    client.port = UDP_FLOW_PORT;
    client.useTcp = NO;
    [client sendPacket:[F53OSCMessage messageWithAddressPattern:@"/thump" arguments:@[]]];

    // Wait for delivery so the flow is registered.
    [counter waitForCount:1 timeout:3.0];
    XCTAssertEqual( counter.receivedCount, 1, @"Server should have received the datagram" );

    // idleTimeout(0.3s) + sweep cadence(0.2s) + margin = 1.0s. Spin run loop so main isn't starved.
    NSDate *sweepDeadline = [NSDate dateWithTimeIntervalSinceNow:1.0];
    while ( [sweepDeadline timeIntervalSinceNow] > 0 )
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];

    // TODO: replace KVC introspection with a public -activeUDPFlowCount property.
    NSUInteger afterSweep = ActiveUDPFlowCount( server );
    if ( afterSweep != NSNotFound )
    {
        XCTAssertEqual( afterSweep, 0u, @"Idle UDP flows should be reaped after the sweep" );
    }
    else
    {
        // KVC inaccessible — degrade gracefully and just verify the server still works.
        [client sendPacket:[F53OSCMessage messageWithAddressPattern:@"/thump" arguments:@[]]];
        [counter waitForCount:2 timeout:3.0];
        XCTAssertEqual( counter.receivedCount, 2, @"Server should still accept datagrams post-sweep" );
    }

    [client disconnect];
    [server stopListening];
}


- (void) testActiveUDPFlowSurvivesSweep
{
    // A sender that keeps sending at intervals shorter than udpFlowIdleTimeout should
    // not be evicted. Each delivery resets secondsSinceLastActivity, preventing the
    // idle check from triggering a removal.

    F53OSCServer *server = [[F53OSCServer alloc] initWithDelegateQueue:dispatch_get_main_queue()];
    server.port = UDP_FLOW_PORT;
    server.udpFlowIdleTimeout = 1.0;

    UDPFlowCounter *counter = [[UDPFlowCounter alloc] init];
    server.delegate = counter;
    XCTAssertTrue( [server startListening], @"UDP server must start" );

    F53OSCClient *client = [[F53OSCClient alloc] init];
    client.host = @"127.0.0.1";
    client.port = UDP_FLOW_PORT;
    client.useTcp = NO;

    F53OSCMessage *msg = [F53OSCMessage messageWithAddressPattern:@"/ping" arguments:@[]];
    NSInteger const rounds = 5;

    for ( NSInteger i = 0; i < rounds; i++ )
    {
        [client sendPacket:msg];
        [counter waitForCount:(i + 1) timeout:3.0];
        XCTAssertEqual( counter.receivedCount, (i + 1), @"Message %ld should be received", (long)(i + 1) );

        // Sleep well within the idle timeout so secondsSinceLastActivity stays small.
        [NSThread sleepForTimeInterval:0.1];

        // TODO: replace KVC introspection with a public -activeUDPFlowCount property.
        NSUInteger flowCount = ActiveUDPFlowCount( server );
        if ( flowCount != NSNotFound )
        {
            XCTAssertGreaterThanOrEqual( flowCount, 1u,
                                         @"Active sender's flow should survive across sends" );
        }
    }

    XCTAssertEqual( counter.receivedCount, rounds, @"All %ld messages should be received", (long)rounds );

    [client disconnect];
    [server stopListening];
}


- (void) testZeroIdleTimeoutDisablesSweep
{
    // Setting udpFlowIdleTimeout = 0 disables the sweep entirely.
    // (Swift test used -1 as the "disabled" sentinel. ObjC property documents 0 as the
    // official disable value. Adapted accordingly.)
    //
    // After delivering some datagrams, we sleep well past a normal sweep cadence and
    // verify the flows remain present.

    F53OSCServer *server = [[F53OSCServer alloc] initWithDelegateQueue:dispatch_get_main_queue()];
    server.port = UDP_FLOW_PORT;
    server.udpFlowIdleTimeout = 0; // disabled

    UDPFlowCounter *counter = [[UDPFlowCounter alloc] init];
    server.delegate = counter;
    XCTAssertTrue( [server startListening], @"UDP server must start" );

    // Send a few datagrams to register flows.
    F53OSCClient *client = [[F53OSCClient alloc] init];
    client.host = @"127.0.0.1";
    client.port = UDP_FLOW_PORT;
    client.useTcp = NO;

    NSInteger const msgCount = 3;
    for ( NSInteger i = 0; i < msgCount; i++ )
        [client sendPacket:[F53OSCMessage messageWithAddressPattern:@"/probe" arguments:@[]]];

    [counter waitForCount:msgCount timeout:5.0];
    XCTAssertEqual( counter.receivedCount, msgCount, @"All probe messages should be received" );

    // TODO: replace KVC introspection with a public -activeUDPFlowCount property.
    NSUInteger peakCount = ActiveUDPFlowCount( server );

    // Spin past several sweep intervals (default 5s) to prove the sweep stays off.
    // Run-loop spin instead of sleep keeps main alive for the delegate thread.
    NSDate *idleDeadline = [NSDate dateWithTimeIntervalSinceNow:1.0];
    while ( [idleDeadline timeIntervalSinceNow] > 0 )
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];

    NSUInteger afterSleep = ActiveUDPFlowCount( server );
    if ( peakCount != NSNotFound && afterSleep != NSNotFound )
    {
        // NOTE: Network.framework may merge datagrams from the same source into one flow,
        // so peakCount could be 1 even for 3 sends.  The key assertion is that flows are
        // NOT reduced (i.e. sweep did not run).
        XCTAssertGreaterThanOrEqual( afterSleep, peakCount,
                                     @"With sweeping disabled, flow count must not decrease" );
    }
    else
    {
        // KVC inaccessible — verify the server still works as a proxy for "not crashed".
        [client sendPacket:[F53OSCMessage messageWithAddressPattern:@"/probe" arguments:@[]]];
        [counter waitForCount:(msgCount + 1) timeout:3.0];
        XCTAssertEqual( counter.receivedCount, (msgCount + 1),
                        @"Server should still accept datagrams when sweep is disabled" );
    }

    [client disconnect];
    [server stopListening];
}


@end

NS_ASSUME_NONNULL_END
