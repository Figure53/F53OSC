//
//  F53OSC_ThroughputTests.m
//  F53OSC
//
//  Created by Christopher Cahoon on 5/23/26.
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

// caveats:
// - UDP localhost may drop messages under burst — that's expected. Each measure iteration has a
//   10-second timeout and the test fails (rather than hangs) if the count isn't reached.
//   Tune N down if your machine isn't keeping up.
// - TCP/SLIP throughput is dominated by syscall and parser cost, not network. The measure result
//   is useful as a regression check, not an absolute benchmark.
// - Both tests count complete F53OSCMessage deliveries (parser successfully extracted a message).
//   UDP: one datagram = one message. TCP/SLIP: one SLIP frame = one message.

#if !__has_feature(objc_arc)
#error This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#import <XCTest/XCTest.h>

#import "F53OSCClient.h"
#import "F53OSCMessage.h"
#import "F53OSCServer.h"
#import "F53OSCTestCounter.h"

#if __has_include(<F53OSC/F53OSC-Swift.h>) // F53OSC_BUILT_AS_FRAMEWORK
#import <F53OSC/F53OSC-Swift.h>
#elif __has_include("F53OSC-Swift.h")
#import "F53OSC-Swift.h"
#endif


NS_ASSUME_NONNULL_BEGIN

#pragma mark - F53OSC_ThroughputTests

@interface F53OSC_ThroughputTests : XCTestCase
@end

@implementation F53OSC_ThroughputTests

// port 0 lets the kernel pick a free ephemeral port for the listener, so the
// throughput tests are immune to host-side port collisions. We read the actual
// bound port back off the server's udpSocket / tcpSocket after startListening.

- (void) testThroughput_UDP_Localhost
{
    // set up server with port 0 so the OS picks any free port
    F53OSCServer *server = [[F53OSCServer alloc] initWithDelegateQueue:dispatch_get_main_queue()];
    server.port = 0;
    F53OSCTestCounter *counter = [[F53OSCTestCounter alloc] init];
    server.delegate = counter;

    // register teardown immediately so the listener is torn down even if a
    // later assertion fails or measureBlock aborts. The 100ms run-loop drain
    // lets Network.framework's async cancel complete before the next test.
    F53OSCClient *client = [[F53OSCClient alloc] init];
    [self addTeardownBlock:^{
        [client disconnect];
        [server stopListening];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }];

    NSError *error = nil;
    XCTAssertTrue([server startListening:&error], @"UDP server should start listening");
    XCTAssertNil(error, @"UDP server should start without error");

    // set up client now that we know the actual bound UDP port
    client.host = @"127.0.0.1";
    client.port = server.udpSocket.port;
    client.useTcp = NO;

    // build test message once — zero-argument messages are the smallest possible
    // payload, which stresses the send/receive loop most directly
    F53OSCMessage *msg = [F53OSCMessage messageWithAddressPattern:@"/thump" arguments:@[]];

    NSInteger const kWarmup = 100;
    NSInteger const N       = 2000;

    // warmup: prime the socket path so the first measure iteration isn't cold
    [counter reset];
    counter.targetCount = kWarmup;
    for ( NSInteger i = 0; i < kWarmup; i++ )
        [client sendPacket:msg];
    [counter waitForCount:kWarmup timeout:5.0];

    // measure block: XCTest runs this 10 times by default and reports
    // min / avg / std-dev. Each iteration is a complete send-and-wait cycle
    [self measureBlock:^{
        [counter reset];
        counter.targetCount = N;
        for ( NSInteger i = 0; i < N; i++ )
            [client sendPacket:msg];
        [counter waitForCount:N timeout:10.0];

        if ( counter.receivedCount < N )
            XCTFail(@"UDP: only received %ld of %ld messages within timeout", (long)counter.receivedCount, (long)N);
    }];
}

- (void) testThroughput_TCP_SLIP_Localhost
{
    // set up server with port 0 so the OS picks any free port
    F53OSCServer *server = [[F53OSCServer alloc] initWithDelegateQueue:dispatch_get_main_queue()];
    server.port = 0;
    F53OSCTestCounter *counter = [[F53OSCTestCounter alloc] init];
    server.delegate = counter;

    // register teardown immediately so the listener and connection are torn
    // down even if a later assertion fails or measureBlock aborts. The 100ms
    // run-loop drain lets Network.framework's async cancel complete before
    // the next test class begins binding.
    F53OSCClient *client = [[F53OSCClient alloc] init];
    [self addTeardownBlock:^{
        [client disconnect];
        [server stopListening];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }];

    NSError *error = nil;
    XCTAssertTrue([server startListening:&error], @"TCP server should start listening");
    XCTAssertNil(error, @"TCP server should start without error");

    // set up client now that we know the actual bound TCP port
    client.host = @"127.0.0.1";
    client.port = server.tcpSocket.port;
    client.useTcp = YES;
    client.delegate = counter; // clientDidConnect: signals connectSemaphore

    // wait for the TCP handshake to complete before running warmup or measure
    [client connect];
    NSDate *connectDeadline = [NSDate dateWithTimeIntervalSinceNow:5.0];
    while ( [connectDeadline timeIntervalSinceNow] > 0
            && dispatch_semaphore_wait(counter.connectSemaphore, DISPATCH_TIME_NOW) != 0 )
    {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    XCTAssertTrue(client.isConnected, @"TCP client should connect within 5 seconds");
    XCTAssertTrue(client.isConnected, @"TCP client should be connected");

    // build test message once
    F53OSCMessage *msg = [F53OSCMessage messageWithAddressPattern:@"/thump" arguments:@[]];

    NSInteger const kWarmup = 100;
    NSInteger const N       = 2000;

    // warmup: send messages before starting the measure block. TCP should
    // not drop on localhost so we expect exactly kWarmup deliveries
    [counter reset];
    counter.targetCount = kWarmup;
    for ( NSInteger i = 0; i < kWarmup; i++ )
        [client sendPacket:msg];
    [counter waitForCount:kWarmup timeout:5.0];

    // measure block
    [self measureBlock:^{
        [counter reset];
        counter.targetCount = N;
        for ( NSInteger i = 0; i < N; i++ )
            [client sendPacket:msg];
        [counter waitForCount:N timeout:10.0];

        if ( counter.receivedCount < N )
            XCTFail(@"TCP/SLIP: only received %ld of %ld messages within timeout", (long)counter.receivedCount, (long)N);
    }];
}

@end

NS_ASSUME_NONNULL_END
