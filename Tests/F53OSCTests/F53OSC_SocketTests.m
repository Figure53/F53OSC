//
//  F53OSC_SocketTests.m
//  F53OSC
//
//  Created by Brent Lord on 8/5/25.
//  Copyright (c) 2025-2026 Figure 53. All rights reserved.
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

#import <XCTest/XCTest.h>

#import "F53OSCSocket.h"
#import "F53OSCMessage.h"
#import "F53OSCServer.h"

#if __has_include(<F53OSC/F53OSC-Swift.h>) // F53OSC_BUILT_AS_FRAMEWORK
#import <F53OSC/F53OSC-Swift.h>
#elif __has_include("F53OSC-Swift.h")
#import "F53OSC-Swift.h"
#endif


NS_ASSUME_NONNULL_BEGIN

#define PORT_BASE   9900

@interface F53OSC_SocketTests : XCTestCase <F53OSCServerDelegate>

@property (nonatomic, strong, nullable) F53OSCServer *testServer;
@property (nonatomic, strong) NSMutableArray<F53OSCMessage *> *receivedMessages;

// Test expectations
@property (nonatomic, strong, nullable) XCTestExpectation *connectionExpectation;
@property (nonatomic, strong, nullable) XCTestExpectation *disconnectionExpectation;

@end

@implementation F53OSC_SocketTests

- (void)setUp
{
    [super setUp];

    self.receivedMessages = [NSMutableArray array];
}

//- (void)tearDown
//{
//    [super tearDown];
//}

- (void)setupTestServer
{
    UInt16 port = PORT_BASE + 10;

    F53OSCServer *testServer = [[F53OSCServer alloc] init];
    testServer.delegate = self;
    testServer.port = port;

    [self addTeardownBlock:^{
        [testServer stopListening];
        testServer.delegate = nil;
    }];
    self.testServer = testServer;

    NSError *error = nil;
    BOOL isListening = [testServer startListening:&error];
    XCTAssertTrue(isListening, @"Test server should start listening on port %hu", port);
    XCTAssertNil(error, @"Test server should start listening without error");
}


#pragma mark - Basic configuration tests

- (void)testThat__setupWorks
{
    // given
    // - state created by `+setUp` and `-setUp`

    // when
    // - triggered by running this test

    // then
    XCTAssertTrue(YES);
}

- (void)testThat_statsHasCorrectDefaults
{
    F53OSCStats *stats = [[F53OSCStats alloc] init];

    XCTAssertNotNil(stats, @"Stats should not be nil");
    XCTAssertEqual([stats totalBytes], 0.0, @"Stats totalBytes should be 0");
    XCTAssertEqual([stats bytesPerSecond], 0.0, @"Stats bytesPerSecond should be 0");
}

- (void)testThat_statsTracksBytes
{
    F53OSCStats *stats = [[F53OSCStats alloc] init];

    // Add some bytes.
    [stats addBytes:100.0];
    XCTAssertEqualWithAccuracy([stats totalBytes], 100.0, DBL_EPSILON, @"Should track 100 bytes");

    [stats addBytes:50.0];
    XCTAssertEqualWithAccuracy([stats totalBytes], 150.0, DBL_EPSILON, @"Should accumulate to 150 bytes");

    [stats addBytes:25.5];
    XCTAssertEqualWithAccuracy([stats totalBytes], 175.5, DBL_EPSILON, @"Should handle fractional bytes");
}

- (void)testThat_statsCalculatesBytesPerSecond
{
    F53OSCStats *stats = [[F53OSCStats alloc] init];

    // Add bytes and check bytes per second calculation.
    [stats addBytes:1024.0];

    double initialRate = [stats bytesPerSecond];
    NSLog(@"Initial bytes per second: %.2f", initialRate);

    // Wait a bit and add more bytes.
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    [stats addBytes:512.0];

    double secondRate = [stats bytesPerSecond];
    NSLog(@"Second bytes per second: %.2f", secondRate);

    XCTAssertGreaterThanOrEqual([stats totalBytes], 1536.0, @"Total bytes should be at least 1536");
    XCTAssertGreaterThanOrEqual([stats bytesPerSecond], 0.0, @"Bytes per second should not be negative");
}

- (void)testThat_statsHandlesZeroAndNegativeBytes
{
    F53OSCStats *stats = [[F53OSCStats alloc] init];

    // Add zero bytes.
    [stats addBytes:0.0];
    XCTAssertEqual([stats totalBytes], 0.0, @"Adding zero bytes should not change total");

    // Add negative bytes (implementation-defined behavior).
    [stats addBytes:-10.0];
    double totalAfterNegative = [stats totalBytes];
    NSLog(@"Total after negative bytes: %.2f", totalAfterNegative);

    // Just ensure it doesn't crash.
    XCTAssertNoThrow([stats bytesPerSecond], @"Should not crash after negative bytes");
}

- (void)testThat_statsHandlesLargeNumbers
{
    F53OSCStats *stats = [[F53OSCStats alloc] init];

    // Add very large number of bytes.
    [stats addBytes:1e9]; // 1 billion bytes
    XCTAssertEqualWithAccuracy([stats totalBytes], 1e9, DBL_EPSILON, @"Should handle large byte counts");

    [stats addBytes:1e9]; // Another billion.
    XCTAssertEqualWithAccuracy([stats totalBytes], 2e9, DBL_EPSILON, @"Should handle very large totals");

    // Should not crash or overflow.
    XCTAssertNoThrow([stats bytesPerSecond], @"Should handle large numbers without crashing");
}

- (void)testThat_socketWithTcpSocketHasCorrectDefaults
{
    F53OSCSocket *socket = [F53OSCSocket outboundTcpSocketWithCallbackQueue:dispatch_get_main_queue()];

    XCTAssertNotNil(socket, @"Socket should not be nil");
    XCTAssertTrue(socket.isTcpSocket, @"Default isTcpSocket should be YES");
    XCTAssertFalse(socket.isUdpSocket, @"Default isUdpSocket should be NO");
    XCTAssertEqual(socket.tcpDataFraming, F53TCPDataFramingSLIP, @"Default tcpDataFraming should be SLIP");
    XCTAssertNil(socket.interface, @"Default interface should be nil");
    XCTAssertEqualObjects(socket.host, @"localhost", @"Default host should be 'localhost'");
    XCTAssertEqual(socket.port, 0, @"Default port should be 0");
    XCTAssertTrue(socket.hostIsLocal, @"Default hostIsLocal should be YES");
    XCTAssertNil(socket.stats, @"Default stats should be nil");
    XCTAssertNil(socket.encrypter, @"Default encrypter should be nil");
    XCTAssertFalse(socket.isEncrypting, @"Default isEncrypting should be NO");
    XCTAssertFalse(socket.isConnected, @"Default isConnected should be NO");
}

- (void)testThat_socketWithUdpSocketHasCorrectDefaults
{
    F53OSCSocket *socket = [F53OSCSocket outboundUdpSocketWithCallbackQueue:dispatch_get_main_queue()];

    XCTAssertNotNil(socket, @"Socket should not be nil");
    XCTAssertFalse(socket.isTcpSocket, @"Default isTcpSocket should be NO");
    XCTAssertTrue(socket.isUdpSocket, @"Default isUdpSocket should be YES");
    XCTAssertEqual(socket.tcpDataFraming, F53TCPDataFramingSLIP, @"Default tcpDataFraming should be SLIP");
    XCTAssertNil(socket.interface, @"Default interface should be nil");
    XCTAssertEqualObjects(socket.host, @"localhost", @"Default host should be 'localhost'");
    XCTAssertEqual(socket.port, 0, @"Default port should be 0");
    XCTAssertTrue(socket.hostIsLocal, @"Default hostIsLocal should be YES");
    XCTAssertNil(socket.stats, @"Default stats should be nil");
    XCTAssertNil(socket.encrypter, @"Default encrypter should be nil");
    XCTAssertFalse(socket.isEncrypting, @"Default isEncrypting should be NO");
    // Modernized UDP sockets do not assert isConnected until first send. This
    // differs from the GCDAsyncUdpSocket contract.
    XCTAssertFalse(socket.isConnected, @"Modernized UDP socket isConnected is NO until first send");
}

- (void)testThat_socketCanConfigureProperties
{
    F53OSCSocket *socket = [F53OSCSocket outboundTcpSocketWithCallbackQueue:dispatch_get_main_queue()];

    socket.tcpDataFraming = F53TCPDataFramingNone;
    XCTAssertEqual(socket.tcpDataFraming, F53TCPDataFramingNone, @"Socket tcpDataFraming should be None");

    socket.interface = @"en0";
    XCTAssertEqualObjects(socket.interface, @"en0", @"Socket interface should be 'en0'");

    socket.interface = @"";
    XCTAssertEqualObjects(socket.interface, @"", @"Interface should accept empty string");

    socket.host = @"192.168.1.100";
    XCTAssertEqualObjects(socket.host, @"192.168.1.100", @"Socket host should be '192.168.1.100'");

    socket.port = 8080;
    XCTAssertEqual(socket.port, 8080, @"Socket port should be 8080");
}

- (void)testThat_socketCannotBeCopied
{
    F53OSCSocket *socket = [F53OSCSocket outboundTcpSocketWithCallbackQueue:dispatch_get_main_queue()];

    XCTAssertThrows(socket.copy, @"Socket does not conform to NSCopying");
}

- (void)testThat_tcpSocketHandlesMinimumPortNumber
{
    F53OSCSocket *socket = [F53OSCSocket tcpListenerWithCallbackQueue:dispatch_get_main_queue()];

    [self addTeardownBlock:^{
        [socket disconnect];
        [socket stopListening];
    }];

    // Test with port 0 (should bind to random available port).
    socket.port = 0;
    XCTAssertEqual(socket.port, 0, @"Socket port should be 0");

    NSError *error = nil;
    BOOL isListeningMin = [socket startListening:&error];
    XCTAssertTrue(isListeningMin, @"Should start listening on min port %hu", socket.port);
    XCTAssertNil(error, @"Server should start listening without error");
}

- (void)testThat_udpSocketHandlesMinimumPortNumber
{
    F53OSCSocket *socket = [F53OSCSocket udpListenerWithCallbackQueue:dispatch_get_main_queue()];

    [self addTeardownBlock:^{
        [socket disconnect];
        [socket stopListening];
    }];

    // Test with port 0 (should bind to random available port).
    socket.port = 0;
    XCTAssertEqual(socket.port, 0, @"Socket port should be 0");

    NSError *error = nil;
    BOOL isListeningMin = [socket startListening:&error];
    XCTAssertTrue(isListeningMin, @"Should start listening on min port %hu", socket.port);
    XCTAssertNil(error, @"Server should start listening without error");
}

- (void)testThat_tcpSocketHandlesMaximumPortNumber
{
    F53OSCSocket *socket = [F53OSCSocket tcpListenerWithCallbackQueue:dispatch_get_main_queue()];

    [self addTeardownBlock:^{
        [socket disconnect];
        [socket stopListening];
    }];

    // Test with max port number 65535.
    socket.port = UINT16_MAX;
    XCTAssertEqual(socket.port, 65535, @"Socket port should be 65535");

    NSError *error = nil;
    BOOL isListeningMax = [socket startListening:&error];
    XCTAssertTrue(isListeningMax, @"Should start listening on max port %hu", socket.port);
    XCTAssertNil(error, @"Server should start listening without error");
}

- (void)testThat_udpSocketHandlesMaximumPortNumber
{
    F53OSCSocket *socket = [F53OSCSocket udpListenerWithCallbackQueue:dispatch_get_main_queue()];

    [self addTeardownBlock:^{
        [socket disconnect];
        [socket stopListening];
    }];

    // Test with max port number 65535.
    socket.port = UINT16_MAX;
    XCTAssertEqual(socket.port, 65535, @"Socket port should be 65535");

    NSError *error = nil;
    BOOL isListeningMax = [socket startListening:&error];
    XCTAssertTrue(isListeningMax, @"Should start listening on max port %hu", socket.port);
    XCTAssertNil(error, @"Server should start listening without error");
}

- (void)testThat_tcpSocketHasNoStatsObjectAfterCreation
{
    F53OSCSocket *socket = [F53OSCSocket tcpListenerWithCallbackQueue:dispatch_get_main_queue()];

    [self addTeardownBlock:^{
        [socket disconnect];
        [socket stopListening];
    }];

    XCTAssertNil(socket.stats, @"Socket should not have a stats object yet");

    NSError *error = nil;
    BOOL isListening = [socket startListening:&error];
    XCTAssertTrue(isListening, @"Socket should start listening");
    XCTAssertNil(error, @"Should start listening without error");

    XCTAssertNil(socket.stats, @"Socket still should not have a stats object");
}

- (void)testThat_udpSocketHasStatsObjectAfterCreation
{
    F53OSCSocket *socket = [F53OSCSocket udpListenerWithCallbackQueue:dispatch_get_main_queue()];

    [self addTeardownBlock:^{
        [socket disconnect];
        [socket stopListening];
    }];

    XCTAssertNil(socket.stats, @"Socket should not have a stats object yet");

    NSError *error = nil;
    BOOL isListening = [socket startListening:&error];
    XCTAssertTrue(isListening, @"Socket should start listening");
    XCTAssertNil(error, @"Socket should start listening without error");

    XCTAssertNotNil(socket.stats, @"Socket should now have a stats object");
    XCTAssertEqualWithAccuracy([socket.stats totalBytes], 0.0, 0.01, @"Initial stats should be zero");
}

- (void)testThat_tcpSocketCanChangeTCPDataFraming
{
    F53OSCSocket *socket = [F53OSCSocket outboundTcpSocketWithCallbackQueue:dispatch_get_main_queue()];

    // Change to no framing.
    socket.tcpDataFraming = F53TCPDataFramingNone;
    XCTAssertEqual(socket.tcpDataFraming, F53TCPDataFramingNone, @"Should change to no framing");

    // Change back to SLIP.
    socket.tcpDataFraming = F53TCPDataFramingSLIP;
    XCTAssertEqual(socket.tcpDataFraming, F53TCPDataFramingSLIP, @"Should change back to SLIP");
}

- (void)testThat_udpSocketIgnoresTCPDataFraming
{
    F53OSCSocket *socket = [F53OSCSocket outboundUdpSocketWithCallbackQueue:dispatch_get_main_queue()];

    // TCP data framing should still be settable but not meaningful for UDP.
    socket.tcpDataFraming = F53TCPDataFramingNone;
    XCTAssertEqual(socket.tcpDataFraming, F53TCPDataFramingNone, @"UDP socket should still allow TCP framing setting");
}

- (void)testThat_tcpSocketDescriptionIsCorrect
{
    F53OSCSocket *socket = [F53OSCSocket outboundTcpSocketWithCallbackQueue:dispatch_get_main_queue()];

    socket.host = @"example.com";
    socket.port = 8080;

    NSString *description = [socket description];
    XCTAssertNotNil(description, @"Description should not be nil");
    XCTAssertTrue([description containsString:@"TCP"], @"Description should mention TCP");
    XCTAssertTrue([description containsString:@"example.com"], @"Description should contain host");
    XCTAssertTrue([description containsString:@"8080"], @"Description should contain port");
    XCTAssertEqualObjects(description, @"<F53OSCSocket TCP example.com:8080 isConnected = 0>", @"Description is incorrect");
}

- (void)testThat_udpSocketDescriptionIsCorrect
{
    F53OSCSocket *socket = [F53OSCSocket outboundUdpSocketWithCallbackQueue:dispatch_get_main_queue()];

    socket.host = @"localhost";
    socket.port = 9123;

    NSString *description = [socket description];
    XCTAssertNotNil(description, @"Description should not be nil");
    XCTAssertTrue([description containsString:@"UDP"], @"Description should mention UDP");
    XCTAssertTrue([description containsString:@"localhost"], @"Description should contain host");
    XCTAssertTrue([description containsString:@"9123"], @"Description should contain port");
    XCTAssertEqualObjects(description, @"<F53OSCSocket UDP localhost:9123>", @"Description is incorrect");
}

- (void)testThat_socketHandlesIPv6Configuration
{
    F53OSCSocket *socket = [F53OSCSocket outboundTcpSocketWithCallbackQueue:dispatch_get_main_queue()];

    // Test IPv6 configuration.
    socket.IPv6Enabled = YES;
    XCTAssertTrue(socket.isIPv6Enabled, @"IPv6 should be enabled");

    socket.IPv6Enabled = NO;
    XCTAssertFalse(socket.isIPv6Enabled, @"IPv6 should be disabled");
}

- (void)testThat_socketStopListeningWorks
{
    F53OSCSocket *socket = [F53OSCSocket tcpListenerWithCallbackQueue:dispatch_get_main_queue()];

    socket.port = PORT_BASE + 20;

    // Start listening.
    NSError *error = nil;
    BOOL isListening = [socket startListening:&error];
    XCTAssertTrue(isListening, @"Socket should start listening");
    XCTAssertNil(error, @"Socket should start listening without error");

    // Stop listening.
    XCTAssertNoThrow([socket stopListening], @"Stop listening should not crash");

    // Should be able to stop multiple times.
    XCTAssertNoThrow([socket stopListening], @"Multiple stop listening should not crash");
}

- (void)testThat_hostIsLocalWorks
{
    F53OSCSocket *socket = [F53OSCSocket outboundTcpSocketWithCallbackQueue:dispatch_get_main_queue()];

    // Test localhost detection.
    socket.host = @"localhost";
    XCTAssertTrue(socket.hostIsLocal, @"localhost should be detected as local");

    socket.host = @"127.0.0.1";
    XCTAssertTrue(socket.hostIsLocal, @"127.0.0.1 should be detected as local");

    socket.host = @"example.com";
    XCTAssertFalse(socket.hostIsLocal, @"example.com should not be detected as local");

    socket.host = nil;
    XCTAssertTrue(socket.hostIsLocal, @"nil host should be detected as local");
}


#pragma mark - Connection tests

- (void)testThat_tcpSocketCanConnect
{
    [self setupTestServer];

    F53OSCSocket *socket = [F53OSCSocket outboundTcpSocketWithCallbackQueue:dispatch_get_main_queue()];

    [self addTeardownBlock:^{
        [socket disconnect];
        [socket stopListening];
    }];

    socket.host = @"localhost";
    socket.port = self.testServer.port;

    // Initial state should be disconnected.
    XCTAssertFalse([socket isConnected], @"Socket should not initially be connected");

    // Connect should succeed.
    BOOL didConnect = [socket connect];
    XCTAssertTrue(didConnect, @"Connect should return YES");
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];

    // Should now be connected.
    XCTAssertTrue([socket isConnected], @"Socket should be connected after connect");
}

- (void)testThat_tcpSocketCanDisconnect
{
    [self setupTestServer];

    F53OSCSocket *socket = [F53OSCSocket outboundTcpSocketWithCallbackQueue:dispatch_get_main_queue()];

    [self addTeardownBlock:^{
        [socket disconnect];
        [socket stopListening];
    }];

    socket.host = @"localhost";
    socket.port = self.testServer.port;

    // Initial state should be disconnected.
    XCTAssertFalse([socket isConnected], @"Socket should not initially be connected");

    // Connect should succeed.
    BOOL didConnect = [socket connect];
    XCTAssertTrue(didConnect, @"Connect should return YES");
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];

    // Should now be connected.
    XCTAssertTrue([socket isConnected], @"Socket should be connected after connect");

    // Disconnect.
    [socket disconnect];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];

    // Should be disconnected.
    XCTAssertFalse([socket isConnected], @"Socket should be disconnected after disconnect");
}

- (void)testThat_udpSocketCanConnect
{
    F53OSCSocket *socket = [F53OSCSocket outboundUdpSocketWithCallbackQueue:dispatch_get_main_queue()];
    socket.host = @"localhost";
    socket.port = 8000;

    // UDP sockets have different connection semantics.
    BOOL connectResult = [socket connect];
    NSLog(@"UDP connect result: %@", connectResult ? @"YES" : @"NO");

    BOOL isConnected = [socket isConnected];
    NSLog(@"UDP isConnected: %@", isConnected ? @"YES" : @"NO");

    // UDP behavior is implementation-defined but should not crash.
    XCTAssertNoThrow([socket disconnect], @"UDP disconnect should not crash");
}

- (void)testThat_tcpSocketHandlesMultipleConnectAttempts
{
    [self setupTestServer];

    F53OSCSocket *socket = [F53OSCSocket outboundTcpSocketWithCallbackQueue:dispatch_get_main_queue()];

    [self addTeardownBlock:^{
        [socket disconnect];
        [socket stopListening];
    }];

    socket.host = @"localhost";
    socket.port = self.testServer.port;

    // First connect.
    BOOL firstConnect = [socket connect];
    XCTAssertTrue(firstConnect, @"First connect should succeed");

    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];

    // Second connect while already connected should return NO.
    BOOL secondConnect = [socket connect];
    XCTAssertFalse(secondConnect, @"Second connect should return NO when already connected");

    XCTAssertTrue([socket isConnected], @"Socket should remain connected");
}

- (void)testThat_udpSocketHandlesMultipleConnectAttempts
{
    [self setupTestServer];

    F53OSCSocket *socket = [F53OSCSocket outboundUdpSocketWithCallbackQueue:dispatch_get_main_queue()];

    [self addTeardownBlock:^{
        [socket disconnect];
        [socket stopListening];
    }];

    socket.host = @"localhost";
    socket.port = self.testServer.port;

    // First connect.
    BOOL firstConnect = [socket connect];
    XCTAssertTrue(firstConnect, @"First connect should succeed");

    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];

    // Second connect while already connected should return NO.
    BOOL secondConnect = [socket connect];
    XCTAssertTrue(secondConnect, @"Second connect should return YES, UDP sockets always connect");

    XCTAssertTrue([socket isConnected], @"Socket should remain connected");
}

- (void)testThat_tcpSocketHandlesConnectionFailure
{
    F53OSCSocket *socket = [F53OSCSocket outboundTcpSocketWithCallbackQueue:dispatch_get_main_queue()];

    [self addTeardownBlock:^{
        [socket disconnect];
        [socket stopListening];
    }];

    // Try to connect to non-existent server.
    socket.host = @"localhost";
    socket.port = 9999; // Assume this port is not in use

    BOOL connectResult = [socket connect];
    // Connect may return YES initially but fail later.
    NSLog(@"Connect to non-existent server result: %@", connectResult ? @"YES" : @"NO");

    // Give it time to fail.
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];

    // Should not be connected.
    XCTAssertFalse([socket isConnected], @"Should not be connected to non-existent server");
}

- (void)testThat_udpSocketHandlesConnectionFailure
{
    F53OSCSocket *socket = [F53OSCSocket outboundUdpSocketWithCallbackQueue:dispatch_get_main_queue()];

    [self addTeardownBlock:^{
        [socket disconnect];
        [socket stopListening];
    }];

    // Try to connect to non-existent server.
    socket.host = @"localhost";
    socket.port = 9999; // Assume this port is not in use

    BOOL connectResult = [socket connect];
    // Connect may return YES initially but fail later.
    NSLog(@"Connect to non-existent server result: %@", connectResult ? @"YES" : @"NO");

    // Give it time to fail.
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];

    // Should be connected.
    XCTAssertTrue([socket isConnected], @"UDP sockets are always connected, even to a non-existent server");
}

- (void)testThat_tcpSocketHandlesInvalidInterface
{
    // Create TCP socket with invalid interface
    F53OSCSocket *socket = [F53OSCSocket tcpListenerWithCallbackQueue:dispatch_get_main_queue()];
    socket.port = PORT_BASE + 30;
    socket.interface = @"invalid_interface_name_999";

    NSError *error = nil;
    BOOL isListening = [socket startListening:&error];
    XCTAssertFalse(isListening, @"Socket should fail to listen on invalid interface");
    XCTAssertNotNil(error, @"Socket start should return error");
}

- (void)testThat_udpSocketHandlesInvalidInterface
{
    // Create UDP socket with invalid interface
    F53OSCSocket *socket = [F53OSCSocket udpListenerWithCallbackQueue:dispatch_get_main_queue()];
    socket.port = PORT_BASE + 40;
    socket.interface = @"invalid_interface_name_999";

    NSError *error = nil;
    BOOL isListening = [socket startListening:&error];
    XCTAssertFalse(isListening, @"Should fail to bind to invalid interface");
    XCTAssertNotNil(error, @"Socket start should return error");
}



#pragma mark - Server listening tests

- (void)testThat_tcpSocketCanStartListening
{
    F53OSCSocket *socket = [F53OSCSocket tcpListenerWithCallbackQueue:dispatch_get_main_queue()];

    [self addTeardownBlock:^{
        [socket disconnect];
        [socket stopListening];
    }];

    socket.port = PORT_BASE + 50;

    NSError *error = nil;
    BOOL isListening = [socket startListening:&error];
    XCTAssertTrue(isListening, @"Socket should start listening");
    XCTAssertNil(error, @"Socket should start listening without error");
}

- (void)testThat_udpSocketCanStartListening
{
    F53OSCSocket *socket = [F53OSCSocket udpListenerWithCallbackQueue:dispatch_get_main_queue()];

    [self addTeardownBlock:^{
        [socket disconnect];
        [socket stopListening];
    }];

    socket.port = PORT_BASE + 60;

    NSError *error = nil;
    BOOL isListening = [socket startListening:&error];
    XCTAssertTrue(isListening, @"Socket should start listening");
    XCTAssertNil(error, @"Socket should start listening without error");
}

// Port-in-use detection is no longer reliable in the modernized socket layer.
// `nw_parameters_set_reuse_local_address(true)` is set on listeners so that
// stop + restart on the same port works without waiting for the kernel to
// release the socket. As a side effect, two listeners can bind the same port
// without error (only one receives traffic). This is an intentional trade-off
// documented in F53OSC-Swift research notes. Tests that asserted "second bind
// fails" were removed because the new contract makes that assertion invalid.

#pragma mark - Encryption property tests

- (void)testThat_socketHasEncryptionProperties
{
    F53OSCSocket *socket = [F53OSCSocket outboundTcpSocketWithCallbackQueue:dispatch_get_main_queue()];

    XCTAssertNil(socket.encrypter, @"Initial encrypter should be nil");
    XCTAssertFalse(socket.isEncrypting, @"Initial encryption state should be NO");

    // Test setting encryption state without encrypter.
    socket.isEncrypting = YES;
    XCTAssertTrue(socket.isEncrypting, @"Encryption state should be settable");

    socket.isEncrypting = NO;
    XCTAssertFalse(socket.isEncrypting, @"Encryption state should be resettable");
}

- (void)testThat_socketCanSetKeyPairData
{
    F53OSCSocket *socket = [F53OSCSocket outboundTcpSocketWithCallbackQueue:dispatch_get_main_queue()];

    // Create some test key data.
    NSData *testKeyData = [@"test_key_data_placeholder" dataUsingEncoding:NSUTF8StringEncoding];

    // Should not crash when setting key pair (implementation may validate or not).
    XCTAssertNoThrow([socket setKeyPair:testKeyData], @"Setting key pair should not crash");

    // Should not crash with nil data.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertNoThrow([socket setKeyPair:nil], @"Setting nil key pair should not crash");
#pragma clang diagnostic pop
}


#pragma mark - Message sending tests

- (void)testThat_socketCanSendPacket
{
    [self setupTestServer];

    F53OSCSocket *socket = [F53OSCSocket outboundTcpSocketWithCallbackQueue:dispatch_get_main_queue()];

    [self addTeardownBlock:^{
        [socket disconnect];
        [socket stopListening];
    }];

    socket.host = @"localhost";
    socket.port = self.testServer.port;

    // Connect.
    [socket connect];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertTrue([socket isConnected], @"Socket should be connected");

    // Send message.
    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:@"/socket/test" arguments:@[@"socket_message"]];

    XCTAssertNoThrow([socket sendPacket:message], @"Sending message should not crash");

    // Give message time to be received.
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];

    // Should have been received by test server.
    XCTAssertGreaterThan(self.receivedMessages.count, 0, @"Should have received message");

    if (self.receivedMessages.count > 0)
    {
        F53OSCMessage *receivedMessage = self.receivedMessages.firstObject;
        XCTAssertEqualObjects(receivedMessage.addressPattern, @"/socket/test", @"Address should match");
        XCTAssertEqual(receivedMessage.arguments.count, 1, @"Should have one argument");
        XCTAssertEqualObjects(receivedMessage.arguments.firstObject, @"socket_message", @"Argument should match");
    }
}

- (void)testThat_socketHandlesSendingWithoutConnect
{
    F53OSCSocket *socket = [F53OSCSocket outboundTcpSocketWithCallbackQueue:dispatch_get_main_queue()];

    XCTAssertFalse([socket isConnected], @"Socket should not be connected");

    // Try to send without connecting.
    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:@"/no/connection" arguments:@[@"test"]];

    // Should not crash.
    XCTAssertNoThrow([socket sendPacket:message], @"Sending without connection should not crash");
}

- (void)testThat_sendPacketHandlesSLIPFraming
{
    [self setupTestServer];

    // Create TCP socket with SLIP framing to test SLIP encoding path
    F53OSCSocket *socket = [F53OSCSocket outboundTcpSocketWithCallbackQueue:dispatch_get_main_queue()];

    [self addTeardownBlock:^{
        [socket disconnect];
        [socket stopListening];
    }];

    socket.host = @"localhost";
    socket.port = self.testServer.port;
    socket.tcpDataFraming = F53TCPDataFramingSLIP;

    // Connect.
    [socket connect];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertTrue([socket isConnected], @"Socket should be connected");

    // Create a message that contains SLIP special characters
    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:@"/slip/test" arguments:@[@"data with END and ESC bytes"]];

    XCTAssertNoThrow([socket sendPacket:message], @"Should handle SLIP framing without crashing");
}

- (void)testThat_sendPacketHandlesUDPInterfaceBinding
{
    [self setupTestServer];

    // Create UDP socket with interface to test interface binding path
    F53OSCSocket *socket = [F53OSCSocket outboundUdpSocketWithCallbackQueue:dispatch_get_main_queue()];

    [self addTeardownBlock:^{
        [socket disconnect];
        [socket stopListening];
    }];

    socket.host = @"localhost";
    socket.port = self.testServer.port;
    socket.interface = @"lo0"; // loopback interface should exist

    // Connect.
    [socket connect];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertTrue([socket isConnected], @"Socket should be connected");

    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:@"/interface/test" arguments:@[@"test"]];

    XCTAssertNoThrow([socket sendPacket:message], @"Should handle interface binding without crashing");
}

- (void)testThat_sendPacketHandlesUDPInterfaceBindingFailure
{
    [self setupTestServer];

    // Create UDP socket with invalid interface to test error handling
    F53OSCSocket *socket = [F53OSCSocket outboundUdpSocketWithCallbackQueue:dispatch_get_main_queue()];

    [self addTeardownBlock:^{
        [socket disconnect];
        [socket stopListening];
    }];

    socket.host = @"localhost";
    socket.port = self.testServer.port;
    socket.interface = @"nonexistent_interface_999"; // should fail to bind

    // Connect.
    [socket connect];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertTrue([socket isConnected], @"Socket should be connected");

    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:@"/error/test" arguments:@[@"test"]];

    XCTAssertNoThrow([socket sendPacket:message], @"Should handle interface binding failure gracefully");
}

- (void)testThat_sendPacketHandlesUDPWithoutHost
{
    [self setupTestServer];

    // UDP socket with nil host should not crash on sendPacket: — it should
    // log a warning and return.
    F53OSCSocket *socket = [F53OSCSocket outboundUdpSocketWithCallbackQueue:dispatch_get_main_queue()];

    [self addTeardownBlock:^{
        [socket disconnect];
        [socket stopListening];
    }];

    socket.host = nil;
    socket.port = self.testServer.port;

    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:@"/nohost/test" arguments:@[@"test"]];

    XCTAssertNoThrow([socket sendPacket:message], @"Should handle UDP without host gracefully");
}

- (void)testThat_sendPacketHandlesTCPWithNoFraming
{
    [self setupTestServer];

    // Create TCP socket with no framing to test the no-framing case
    F53OSCSocket *socket = [F53OSCSocket outboundTcpSocketWithCallbackQueue:dispatch_get_main_queue()];

    [self addTeardownBlock:^{
        [socket disconnect];
        [socket stopListening];
    }];

    socket.host = @"localhost";
    socket.port = self.testServer.port;
    socket.tcpDataFraming = F53TCPDataFramingNone; // explicitly set to none

    // Connect.
    [socket connect];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertTrue([socket isConnected], @"Socket should be connected");

    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:@"/noframe/test" arguments:@[@"test"]];

    XCTAssertNoThrow([socket sendPacket:message], @"Should handle TCP with no framing without crashing");
}

- (void)testThat_socketHandlesNilMessageSending
{
    [self setupTestServer];

    F53OSCSocket *socket = [F53OSCSocket outboundTcpSocketWithCallbackQueue:dispatch_get_main_queue()];

    [self addTeardownBlock:^{
        [socket disconnect];
        [socket stopListening];
    }];

    socket.host = @"localhost";
    socket.port = self.testServer.port;

    // Connect.
    [socket connect];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertTrue([socket isConnected], @"Socket should be connected");

    // Try to send nil message.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertNoThrow([socket sendPacket:nil], @"Sending nil packet should not crash");
#pragma clang diagnostic pop
}


#pragma mark - F53OSCServerDelegate

- (void)takeMessage:(nullable F53OSCMessage *)message
{
    if (message)
        [self.receivedMessages addObject:message];
}

@end

NS_ASSUME_NONNULL_END
