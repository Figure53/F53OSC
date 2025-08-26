//
//  F53OSC_ClientTests.m
//  F53OSC
//
//  Created by Brent Lord on 8/5/25.
//  Copyright (c) 2025 Figure 53. All rights reserved.
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

#import "F53OSCClient.h"
#import "F53OSCMessage.h"
#import "F53OSCServer.h"

#if __has_include(<F53OSC/F53OSC-Swift.h>) // F53OSC_BUILT_AS_FRAMEWORK
#import <F53OSC/F53OSC-Swift.h>
#elif __has_include("F53OSC-Swift.h")
#import "F53OSC-Swift.h"
#endif


NS_ASSUME_NONNULL_BEGIN

#define PORT_BASE   9000

@interface F53OSCClient (F53OSC_ClientTestsAccess)
@property (strong, nullable)    F53OSCSocket *socket;
@end

@interface F53OSC_ClientTests : XCTestCase <F53OSCServerDelegate, F53OSCClientDelegate>

@property (nonatomic, strong, nullable) XCTestExpectation *connectionExpectation;
@property (nonatomic, strong, nullable) XCTestExpectation *disconnectionExpectation;
@property (nonatomic, strong, nullable) XCTestExpectation *chunkedMessageExpectation;

@property (nonatomic, strong, nullable) F53OSCMessage *receivedMessage;
@property (nonatomic, strong, nullable) XCTestExpectation *tcpUnencryptedMessageExpectation;
@property (nonatomic, strong, nullable) XCTestExpectation *tcpEncryptedMessageExpectation;
@property (nonatomic, strong, nullable) XCTestExpectation *udpAttemptedEncryptedMessageExpectation;

@end

@implementation F53OSC_ClientTests

//- (void)setUp
//{
//    [super setUp];
//}

//- (void)tearDown
//{
//    [super tearDown];
//}

- (F53OSCServer *)basicServerWithPort:(UInt16)port
{
    F53OSCServer *server = [[F53OSCServer alloc] init];
    server.delegate = self;
    server.port = port;
    server.udpReplyPort = port + 1;

    [self addTeardownBlock:^{
        [server stopListening];
        server.delegate = nil;
    }];

    return server;
}

- (F53OSCClient *)basicClientWithPort:(UInt16)port
{
    // Setup client.
    F53OSCClient *client = [[F53OSCClient alloc] init];
    client.delegate = self;
    client.port = port;

    [self addTeardownBlock:^{
        [client disconnect];
        client.delegate = nil;
    }];

    return client;
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

- (void)testThat_clientHasCorrectDefaults
{
    F53OSCClient *client = [[F53OSCClient alloc] init];

    NSDictionary<NSString *, id> *expectedState = @{
        @"interface" : @"",
        @"host" : @"localhost",
        @"port" : @(53000),
        @"useTcp" : @(NO),
        @"tcpTimeout" : @(-1),
        @"userData" : [NSNull null],
    };

    XCTAssertNotNil(client, @"Client should not be nil");
    XCTAssertNil(client.delegate, @"Default delegate should be nil");
    XCTAssertEqualObjects(client.socketDelegateQueue, dispatch_get_main_queue(), @"Default socketDelegateQueue should be the main queue");
    XCTAssertNil(client.interface, @"Default interface should be nil");
    XCTAssertEqualObjects(client.host, @"localhost", @"Default host should be 'localhost'");
    XCTAssertEqual(client.port, 53000, @"Default port should be 53000");
    XCTAssertFalse(client.IPv6Enabled, @"Default IPv6Enabled should be NO");
    XCTAssertFalse(client.useTcp, @"Default useTcp should be NO");
    XCTAssertEqual(client.tcpTimeout, -1, @"Default tcpTimeout should be -1");
    XCTAssertEqual(client.readChunkSize, 0, @"Default readChunkSize should be 0");
    XCTAssertNil(client.userData, @"Default userData should be nil");
    XCTAssertNotNil(client.state, @"Default state should not be nil");
    XCTAssertGreaterThan(client.state.count, 0, @"Default state should not be empty");
    XCTAssertEqualObjects(client.state, expectedState, @"Default state should not be empty");
    XCTAssertNotNil(client.title, @"Default title should not be nil");
    XCTAssertTrue(client.isValid, @"Default client should be valid");
    XCTAssertFalse(client.isConnected, @"Default client should not be connected");
    XCTAssertTrue(client.hostIsLocal, @"Default hostIsLocal should be YES");
}

- (void)testThat_clientCanConfigureProperties
{
    F53OSCClient *client = [[F53OSCClient alloc] init];

    [self addTeardownBlock:^{
        [client disconnect];
        client.delegate = nil;
    }];

    client.delegate = self;
    XCTAssertEqualObjects(client.delegate, self, @"Client delegate should be self");

    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    client.socketDelegateQueue = queue;
    XCTAssertEqualObjects(client.socketDelegateQueue, queue, @"Client socketDelegateQueue should be %@", queue);

    client.interface = @"en0";
    XCTAssertEqualObjects(client.interface, @"en0", @"Client interface should be 'en0'");

    client.host = @"127.0.0.1";
    XCTAssertEqualObjects(client.host, @"127.0.0.1", @"Client interface should be '127.0.0.1'");

    client.port = 9999;
    XCTAssertEqual(client.port, 9999, @"Client interface should be 9999");

    client.IPv6Enabled = YES;
    XCTAssertTrue(client.IPv6Enabled, @"Client IPv6Enabled should be YES");

    client.useTcp = YES;
    XCTAssertTrue(client.useTcp, @"Client useTcp should be YES");

    client.tcpTimeout = 3;
    XCTAssertEqual(client.tcpTimeout, 3, @"Client interface should be 3");

    client.readChunkSize = 1024;
    XCTAssertEqual(client.readChunkSize, 1024, @"Client interface should be 1024");

    client.userData = @"some user data";
    XCTAssertEqualObjects(client.userData, @"some user data", @"Client interface should be 'some user data'");

    // Test that properties remain unchanged when client connects to a server.
    F53OSCServer *server = [self basicServerWithPort:client.port];

    BOOL isListening = [server startListening];
    XCTAssertTrue(isListening, @"Server should start listening on port %hu", client.port);

    // Unset interface before connect, in case 'en0' is unavailable on test machine.
    client.interface = @"";

    [client connect];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertTrue(client.isConnected, @"Client should be connected");

    XCTAssertEqualObjects(client.delegate, self, @"Client delegate should remain self");
    XCTAssertEqualObjects(client.socketDelegateQueue, queue, @"Client socketDelegateQueue should remain %@", queue);
    XCTAssertNil(client.interface, @"Client interface set to empty-string should be nil");
    XCTAssertEqualObjects(client.host, @"127.0.0.1", @"Client interface should remain '127.0.0.1'");
    XCTAssertEqual(client.port, 9999, @"Client interface should remain 9999");
    XCTAssertTrue(client.IPv6Enabled, @"Client IPv6Enabled should remain YES");
    XCTAssertTrue(client.useTcp, @"Client useTcp should remain YES");
    XCTAssertEqual(client.tcpTimeout, 3, @"Client interface should remain 3");
    XCTAssertEqual(client.readChunkSize, 1024, @"Client interface should remain 1024");
    XCTAssertEqualObjects(client.userData, @"some user data", @"Client interface should remain 'some user data'");
}

- (void)testThat_clientCannotBeCopied
{
    F53OSCClient *client = [[F53OSCClient alloc] init];

    XCTAssertThrows(client.copy, @"Client does not conform to NSCopying");
}

- (void)testThat_clientSupportsNSSecureCoding
{
    F53OSCClient *client = [[F53OSCClient alloc] init];

    // Configure client with non-default values.
    client.interface = @"en0";
    client.host = @"test.example.com";
    client.port = 9876;
    client.IPv6Enabled = YES;
    client.useTcp = YES;
    client.tcpTimeout = 12.5;
    client.readChunkSize = 2048;
    client.userData = @{@"test": @"data"};

    NSError *error = nil;

    // Encode and decode.
    NSData *archivedData = [NSKeyedArchiver archivedDataWithRootObject:client requiringSecureCoding:YES error:&error];
    XCTAssertNotNil(archivedData, @"Should be able to archive client as data");
    XCTAssertNil(error, @"Should be able to archive client without error");

    F53OSCClient *unarchivedClient = [NSKeyedUnarchiver unarchivedObjectOfClass:[F53OSCClient class] fromData:archivedData error:&error];
    XCTAssertNotNil(archivedData, @"Should be able to unarchive client from data");
    XCTAssertNil(error, @"Should be able to unarchive client without error");

    // Verify all properties were preserved.
    XCTAssertNotNil(unarchivedClient, @"Unarchived client should not be nil");
    XCTAssertNotEqual(unarchivedClient, client, @"Unarchived client should be a different object");
    XCTAssertEqualObjects(unarchivedClient.interface, client.interface, @"Interface should be preserved");
    XCTAssertEqualObjects(unarchivedClient.host, client.host, @"Host should be preserved");
    XCTAssertEqual(unarchivedClient.port, client.port, @"Port should be preserved");
    XCTAssertEqual(unarchivedClient.isIPv6Enabled, client.isIPv6Enabled, @"IPv6 setting should be preserved");
    XCTAssertEqual(unarchivedClient.useTcp, client.useTcp, @"TCP setting should be preserved");
    XCTAssertEqualWithAccuracy(unarchivedClient.tcpTimeout, client.tcpTimeout, 0.01, @"TCP timeout should be preserved");
    XCTAssertEqual(unarchivedClient.readChunkSize, client.readChunkSize, @"Read chunk size should be preserved");
    XCTAssertEqualObjects(unarchivedClient.userData, client.userData, @"User data should be preserved");
}

- (void)testThat_clientDescriptionIsCorrect
{
    F53OSCClient *client = [[F53OSCClient alloc] init];

    client.host = @"test.example.com";
    client.port = 8080;

    NSString *description = [client description];
    XCTAssertTrue([description containsString:@"F53OSCClient"], @"Description should contain class name");
    XCTAssertTrue([description containsString:@"test.example.com"], @"Description should contain host");
    XCTAssertTrue([description containsString:@"8080"], @"Description should contain port");
    XCTAssertEqualObjects(description, @"<F53OSCClient test.example.com:8080>");
}

- (void)testThat_clientSocketDelegateQueueHandlesEdgeValues
{
    F53OSCClient *client = [[F53OSCClient alloc] init];

    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    client.socketDelegateQueue = queue;
    XCTAssertEqualObjects(client.socketDelegateQueue, queue, @"Socket delegate queue should be same object");

    client.socketDelegateQueue = nil;
    XCTAssertEqualObjects(client.socketDelegateQueue, dispatch_get_main_queue(), @"nil socket delegate queue should be converted to main queue");
}

- (void)testThat_clientInterfaceHandlesEdgeValues
{
    F53OSCClient *client = [[F53OSCClient alloc] init];

    // Empty string should be converted to nil.
    client.interface = @"";
    XCTAssertNil(client.interface, @"Empty string interface should be converted to nil");

    // Whitespace-only interface name
    client.interface = @"   ";
    XCTAssertEqualObjects(client.interface, @"   ", @"Should preserve whitespace-only interface name");

    // Very long interface name
    NSString *longInterface = [@"" stringByPaddingToLength:1000 withString:@"a" startingAtIndex:0];
    client.interface = longInterface;
    XCTAssertEqualObjects(client.interface, longInterface, @"Should handle very long interface names");

    // Interface name containing special characters
    client.interface = @"en0:1.2.3@test";
    XCTAssertEqualObjects(client.interface, @"en0:1.2.3@test", @"Should handle special characters in interface name");
}

- (void)testThat_clientInterfaceHandlesInvalidValue
{
    UInt16 port = PORT_BASE + 10;

    F53OSCClient *client = [[F53OSCClient alloc] init];
    client.port = port;

    [self addTeardownBlock:^{
        [client disconnect];
        client.delegate = nil;
    }];

    // Set invalid interface name.
    client.interface = @"nonexistent_interface_999";

    // Should not crash when attempting to connect.
    XCTAssertNoThrow([client connect], @"Should not crash with invalid interface");

    // The connection may fail, but it should be handled gracefully.
    XCTAssertEqualObjects(client.interface, @"nonexistent_interface_999", @"Invalid interface name should still be stored");
}

- (void)testThat_clientReadChunkSizeHandlesEdgeValues
{
    F53OSCClient *client = [[F53OSCClient alloc] init];

    // Test very small chunk size.
    client.readChunkSize = 1;
    XCTAssertEqual(client.readChunkSize, 1, @"Should handle very small chunk size");

    // Test large chunk size.
    client.readChunkSize = 1048576; // 1MB
    XCTAssertEqual(client.readChunkSize, 1048576, @"Should handle large chunk size");

    // Test maximum NSUInteger (implementation should handle this).
    NSUInteger maxSize = NSUIntegerMax;
    client.readChunkSize = maxSize;
    XCTAssertEqual(client.readChunkSize, maxSize, @"Should handle maximum chunk size");
}

- (void)testThat_clientReadChunkSizeAffectsTCPConnections
{
    UInt16 port = PORT_BASE + 20;

    F53OSCServer *server = [self basicServerWithPort:port];
    F53OSCClient *client = [self basicClientWithPort:port];

    BOOL isListening = [server startListening];
    XCTAssertTrue(isListening, @"Server should start listening on port %hu", port);

    // Configure client for partial reads.
    client.readChunkSize = 512;
    client.useTcp = YES; // readChunkSize only affects TCP

    XCTestExpectation *connectionExpectation = [[XCTestExpectation alloc] initWithDescription:@"TCP connection with chunk size"];
    self.connectionExpectation = connectionExpectation;
    [client connect];

    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[connectionExpectation] timeout:2.0];
    XCTAssertEqual(result, XCTWaiterResultCompleted, @"Should connect with readChunkSize configured");

    // Send a message to test chunked reading.
    XCTestExpectation *chunkedMessageExpectation = [[XCTestExpectation alloc] initWithDescription:@"Message with chunked reading"];
    self.chunkedMessageExpectation = chunkedMessageExpectation;

    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:@"/chunk/test" arguments:@[@"chunked_reading"]];
    [client sendPacket:message];

    result = [XCTWaiter waitForExpectations:@[chunkedMessageExpectation] timeout:2.0];
    XCTAssertEqual(result, XCTWaiterResultCompleted, @"Should receive message with chunked reading");
}

- (void)testThat_clientCanStoreUserData
{
    F53OSCClient *client = [[F53OSCClient alloc] init];

    // Default should be nil.
    XCTAssertNil(client.userData, @"Default userData should be nil");

    // String
    client.userData = @"test_user_data";
    XCTAssertEqualObjects(client.userData, @"test_user_data", @"Should store string userData");

    // Number
    client.userData = @(42);
    XCTAssertEqualObjects(client.userData, @(42), @"Should store number userData");

    // Dictionary
    NSDictionary<NSString *, id> *dictData = @{@"key": @"value", @"number": @(123)};
    client.userData = dictData;
    XCTAssertEqualObjects(client.userData, dictData, @"Should store dictionary userData");

    // Array
    NSArray<id> *arrayData = @[@"item1", @"item2", @(456)];
    client.userData = arrayData;
    XCTAssertEqualObjects(client.userData, arrayData, @"Should store array userData");
}

- (void)testThat_clientUserDataHandlesNSNullConversion
{
    F53OSCClient *client = [[F53OSCClient alloc] init];

    // NSNull should be converted to nil.
    client.userData = [NSNull null];
    XCTAssertNil(client.userData, @"NSNull should be converted to nil");

    // Set to non-null, then NSNull again.
    client.userData = @"test";
    client.userData = [NSNull null];
    XCTAssertNil(client.userData, @"NSNull should convert existing userData to nil");
}

- (void)testThat_clientUserDataPersistsThroughOperations
{
    UInt16 port = PORT_BASE + 30;

    F53OSCServer *server = [self basicServerWithPort:port];
    F53OSCClient *client = [self basicClientWithPort:port];

    BOOL isListening = [server startListening];
    XCTAssertTrue(isListening, @"Server should start listening on port %hu", port);

    client.useTcp = YES; // needed for delegate callback to fulfill `connectionExpectation`

    // Set userData before connecting.
    NSDictionary<NSString *, id> *testData = @{@"session": @"test", @"id": @(999)};
    client.userData = testData;

    // Connect and verify userData persists.
    XCTestExpectation *connectionExpectation = [[XCTestExpectation alloc] initWithDescription:@"Connection with userData"];
    self.connectionExpectation = connectionExpectation;
    [client connect];

    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[connectionExpectation] timeout:2.0];
    XCTAssertEqual(result, XCTWaiterResultCompleted, @"Should connect successfully");

    XCTAssertEqualObjects(client.userData, testData, @"userData should persist through connection");

    // Send message and verify userData still persists.
    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:@"/user/data/test" arguments:@[@"test"]];
    [client sendPacket:message];

    XCTAssertEqualObjects(client.userData, testData, @"userData should persist through message sending");

    // Disconnect and verify userData persists.
    [client disconnect];
    XCTAssertEqualObjects(client.userData, testData, @"userData should persist after disconnection");
}

- (void)testThat_clientStateReflectsAllProperties
{
    F53OSCClient *client = [[F53OSCClient alloc] init];

    // Configure client with various properties.
    client.interface = @"en0";
    client.host = @"test.example.com";
    client.port = 9123;
    client.useTcp = YES;
    client.tcpTimeout = 10.0;
    client.userData = @{@"session": @"test"};

    NSDictionary<NSString *, id> *state = client.state;

    XCTAssertEqual(state.count, 6, @"State should have 6 key/values");
    XCTAssertEqualObjects(state[@"interface"], @"en0", @"State should include interface");
    XCTAssertEqualObjects(state[@"host"], @"test.example.com", @"State should include host");
    XCTAssertEqualObjects(state[@"port"], @(9123), @"State should include port");
    XCTAssertEqualObjects(state[@"useTcp"], @(YES), @"State should include useTcp");
    XCTAssertEqualObjects(state[@"tcpTimeout"], @(10.0), @"State should include tcpTimeout");
    XCTAssertEqualObjects(state[@"userData"], @{@"session": @"test"}, @"State should include userData");
}

- (void)testThat_clientStateHandlesNilValues
{
    F53OSCClient *client = [[F53OSCClient alloc] init];

    // Leave interface and host as nil.
    client.interface = nil;
    client.host = nil;
    client.userData = nil;

    NSDictionary<NSString *, id> *state = client.state;

    XCTAssertEqual(state.count, 6, @"State should have 6 key/values");
    XCTAssertEqualObjects(state[@"interface"], @"", @"Nil interface should be empty string in state");
    XCTAssertEqualObjects(state[@"host"], @"", @"Nil host should be empty string in state");
    XCTAssertEqualObjects(state[@"userData"], [NSNull null], @"Nil userData should be NSNull in state");
}

- (void)testThat_clientCanRestoreFromState
{
    F53OSCClient *client = [[F53OSCClient alloc] init];

    // Create a state dictionary.
    NSDictionary<NSString *, id> *savedState = @{
        @"interface": @"lo0",
        @"host": @"192.168.1.100",
        @"port": @(9600),
        @"useTcp": @(NO),
        @"tcpTimeout": @(5.5),
        @"userData": @{@"restored": @"yes"}
    };

    // Restore client from state.
    [client setState:savedState];

    XCTAssertEqualObjects(client.interface, @"lo0", @"Interface should be restored");
    XCTAssertEqualObjects(client.host, @"192.168.1.100", @"Host should be restored");
    XCTAssertEqual(client.port, 9600, @"Port should be restored");
    XCTAssertFalse(client.useTcp, @"useTcp should be restored");
    XCTAssertEqualWithAccuracy(client.tcpTimeout, 5.5, 0.01, @"tcpTimeout should be restored");
    XCTAssertEqualObjects(client.userData, @{@"restored": @"yes"}, @"userData should be restored");
}

- (void)testThat_clientStateRoundTripIsLossless
{
    F53OSCClient *client = [[F53OSCClient alloc] init];

    // Configure client.
    client.interface = @"en0";
    client.host = @"test.local";
    client.port = 9234;
    client.useTcp = YES;
    client.tcpTimeout = 15.0;
    client.userData = @[@"item1", @"item2"];

    // Save and restore state.
    NSDictionary<NSString *, id> *originalState = client.state;
    F53OSCClient *newClient = [[F53OSCClient alloc] init];
    [newClient setState:originalState];

    // Compare all properties.
    XCTAssertEqualObjects(newClient.interface, client.interface, @"Interface should match");
    XCTAssertEqualObjects(newClient.host, client.host, @"Host should match");
    XCTAssertEqual(newClient.port, client.port, @"Port should match");
    XCTAssertEqual(newClient.useTcp, client.useTcp, @"useTcp should match");
    XCTAssertEqualWithAccuracy(newClient.tcpTimeout, client.tcpTimeout, 0.01, @"tcpTimeout should match");
    XCTAssertEqualObjects(newClient.userData, client.userData, @"userData should match");

    // Compare state dictionaries.
    NSDictionary<NSString *, id> *restoredState = newClient.state;
    XCTAssertEqualObjects(restoredState, originalState, @"State dictionaries should be identical");
}

- (void)testThat_clientValidationWorksCorrectly
{
    F53OSCClient *client = [[F53OSCClient alloc] init];

    // Initially valid (default host/port configured).
    XCTAssertTrue(client.isValid, @"Client should be valid with default host/port");

    // Set host but clear port.
    client.host = @"localhost";
    client.port = 0;
    XCTAssertFalse(client.isValid, @"Client should be invalid without a port");

    // Set port but clear host.
    client.host = nil;
    client.port = 8000;
    XCTAssertFalse(client.isValid, @"Client should be invalid without a host");

    // Set both host and port.
    client.host = @"localhost";
    client.port = 8000;
    XCTAssertTrue(client.isValid, @"Client should be valid with both host and port");

    // Test edge cases.
    client.host = @"";
    XCTAssertFalse(client.isValid, @"Client should be invalid with empty host");
}

- (void)testThat_clientTitleReflectsConfiguration
{
    F53OSCClient *client = [[F53OSCClient alloc] init];

    // Client with valid configuration.
    client.host = @"localhost";
    client.port = 8000;

    XCTAssertTrue(client.isValid, @"Client should be valid");
    XCTAssertEqualObjects(client.title, @"localhost : 8000", @"Title should be 'localhost : 8000'");

    // Change configuration and verify title updates.
    client.host = @"example.com";
    client.port = 9345;

    XCTAssertTrue(client.isValid, @"Client should be valid");
    XCTAssertEqualObjects(client.title, @"example.com : 9345", @"Title should be 'example.com : 9345'");

    // Client with invalid configuration (no host).
    client.host = nil;
    client.port = 8000;

    XCTAssertFalse(client.isValid, @"Client should be invalid without a host");
    XCTAssertEqualObjects(client.title, @"<invalid>", @"Title should be '<invalid>'");

    // Client with invalid port.
    client.host = @"localhost";
    client.port = 0;

    XCTAssertFalse(client.isValid, @"Client should be invalid without a port");
    XCTAssertEqualObjects(client.title, @"<invalid>", @"Title should be '<invalid>'");
}

- (void)testThat_clientHostIsLocalDetectionWorksCorrectly
{
    F53OSCClient *client = [[F53OSCClient alloc] init];

    // Test various localhost representations.
    client.host = @"localhost";
    XCTAssertTrue(client.hostIsLocal, @"'localhost' should be detected as local");

    client.host = @"127.0.0.1";
    XCTAssertTrue(client.hostIsLocal, @"'127.0.0.1' should be detected as local");

    client.host = nil;
    XCTAssertTrue(client.hostIsLocal, @"nil host should be considered local");

    client.host = @"";
    XCTAssertTrue(client.hostIsLocal, @"empty host should be considered local");

    // Test remote hosts.
    client.host = @"example.com";
    XCTAssertFalse(client.hostIsLocal, @"'example.com' should not be local");

    client.host = @"192.168.1.100";
    XCTAssertFalse(client.hostIsLocal, @"'192.168.1.100' should not be local");

    client.host = @"10.0.0.1";
    XCTAssertFalse(client.hostIsLocal, @"'10.0.0.1' should not be local");
}


#pragma mark - Encryption tests

- (void)testThat_tcpClientCanSendMessageWithEncryption
{
    F53OSCClient *client = [[F53OSCClient alloc] init];
    client.host = @"localhost";
    client.port = PORT_BASE + 40;
    client.useTcp = YES;
    client.delegate = self;

    F53OSCServer *server = [self basicServerWithPort:client.port];

    F53OSCEncrypt *encrypter = [[F53OSCEncrypt alloc] init];
    NSData *keyPairData = [encrypter generateKeyPair];
    XCTAssertNotNil(keyPairData, @"keyPairData should not be nil");

    // Configure server with same key pair for encryption
    server.keyPair = keyPairData;

    BOOL isListening = [server startListening];
    XCTAssertTrue(isListening, @"Server should start listening");

    [self addTeardownBlock:^{
        [client disconnect];
        client.delegate = nil;
    }];

    // Set up connection expectation to wait for actual connection
    XCTestExpectation *connectionExpectation = [[XCTestExpectation alloc] initWithDescription:@"Client connected"];
    self.connectionExpectation = connectionExpectation;

    XCTAssertTrue([client connectEncryptedWithKeyPair:keyPairData], @"Should connect with valid key pair");
    XCTAssertNotNil(client.socket.encrypter.keyPairData, @"Client internal socket encrypter keyPairData should not be nil");
    XCTAssertEqualObjects(client.socket.encrypter.keyPairData, keyPairData, @"Client internal socket encrypter keyPairData should equal server keyPair");

    // Wait for connection to complete properly (delegate callback)
    XCTWaiterResult connectionResult = [XCTWaiter waitForExpectations:@[connectionExpectation] timeout:5.0];
    XCTAssertEqual(connectionResult, XCTWaiterResultCompleted, @"Should connect within timeout");

    XCTAssertTrue([client isConnected], @"Client should be connected");
    XCTAssertTrue(client.socket.isEncrypting, @"Client internal socket should be encrypting");

    // Test sending encrypted data between client and server
    XCTestExpectation *tcpEncryptedMessageExpectation = [[XCTestExpectation alloc] initWithDescription:@"Encrypted message received"];
    self.tcpEncryptedMessageExpectation = tcpEncryptedMessageExpectation;

    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:@"/tcp/encrypted/test" arguments:@[@"encrypted_data", @(42)]];
    XCTAssertNoThrow([client sendPacket:message], @"Sending encrypted message should not crash");

    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[tcpEncryptedMessageExpectation] timeout:2.0];
    XCTAssertEqual(result, XCTWaiterResultCompleted, @"Should receive encrypted message through server");

    F53OSCMessage *receivedMessage = self.receivedMessage;
    XCTAssertEqualObjects(receivedMessage.addressPattern, @"/tcp/encrypted/test", @"Decrypted address should match");
    XCTAssertEqual(receivedMessage.arguments.count, 2, @"Should have two arguments");
    XCTAssertEqualObjects(receivedMessage.arguments.firstObject, @"encrypted_data", @"Decrypted argument should match");
    XCTAssertEqualObjects(receivedMessage.arguments.lastObject, @(42), @"Decrypted argument should match");
}

- (void)testThat_tcpClientEncryptedMessageWithDifferentKeyPairIsRejected
{
    F53OSCClient *client = [[F53OSCClient alloc] init];
    client.host = @"localhost";
    client.port = PORT_BASE + 50;
    client.useTcp = YES;
    client.delegate = self;

    F53OSCServer *server = [self basicServerWithPort:client.port];

    F53OSCEncrypt *encrypter = [[F53OSCEncrypt alloc] init];
    NSData *keyPairData = [encrypter generateKeyPair];
    XCTAssertNotNil(keyPairData, @"keyPairData should not be nil");

    // Configure server with same key pair for encryption
    server.keyPair = keyPairData;

    BOOL isListening = [server startListening];
    XCTAssertTrue(isListening, @"Server should start listening");

    [self addTeardownBlock:^{
        [client disconnect];
        client.delegate = nil;
    }];

    // Set up connection expectation to wait for actual connection
    XCTestExpectation *connectionExpectation = [[XCTestExpectation alloc] initWithDescription:@"Client connected"];
    self.connectionExpectation = connectionExpectation;

    XCTAssertTrue([client connectEncryptedWithKeyPair:keyPairData], @"Should connect with valid key pair");
    XCTAssertNotNil(client.socket.encrypter.keyPairData, @"Client internal socket encrypter keyPairData should not be nil");
    XCTAssertEqualObjects(client.socket.encrypter.keyPairData, keyPairData, @"Client internal socket encrypter keyPairData should equal server keyPair");

    // Wait for connection to complete properly (delegate callback)
    XCTWaiterResult connectionResult = [XCTWaiter waitForExpectations:@[connectionExpectation] timeout:5.0];
    XCTAssertEqual(connectionResult, XCTWaiterResultCompleted, @"Should connect within timeout");

    XCTAssertTrue([client isConnected], @"Client should be connected");
    XCTAssertTrue(client.socket.isEncrypting, @"Client internal socket should be encrypting");

    XCTAssertNotNil([client.socket.encrypter generateKeyPair]);
    XCTAssertTrue([client.socket.encrypter beginEncryptingWithPeerKey:client.socket.encrypter.peerKey]); // force setting a different `symmetricKey`

    // Test sending encrypted data between client and server
    XCTestExpectation *tcpEncryptedMessageExpectation = [[XCTestExpectation alloc] initWithDescription:@"Encrypted message received"];
    self.tcpEncryptedMessageExpectation = tcpEncryptedMessageExpectation;

    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:@"/tcp/encrypted/test" arguments:@[@"encrypted_data", @(42)]];
    XCTAssertNoThrow([client sendPacket:message], @"Sending encrypted message should not crash");

    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[tcpEncryptedMessageExpectation] timeout:2.0];
    XCTAssertEqual(result, XCTWaiterResultTimedOut, @"Should not receive message encrypted with different keyPair through server");

    F53OSCMessage *receivedMessage = self.receivedMessage;
    XCTAssertNil(receivedMessage, @"Should not receive message encrypted with different keyPair through server");
}

- (void)testThat_tcpClientEncryptedMessageWithDifferentSaltIsRejected
{
    F53OSCClient *client = [[F53OSCClient alloc] init];
    client.host = @"localhost";
    client.port = PORT_BASE + 60;
    client.useTcp = YES;
    client.delegate = self;

    F53OSCServer *server = [self basicServerWithPort:client.port];

    F53OSCEncrypt *encrypter = [[F53OSCEncrypt alloc] init];
    NSData *keyPairData = [encrypter generateKeyPair];
    XCTAssertNotNil(keyPairData, @"keyPairData should not be nil");

    // Configure server with same key pair for encryption
    server.keyPair = keyPairData;

    BOOL isListening = [server startListening];
    XCTAssertTrue(isListening, @"Server should start listening");

    [self addTeardownBlock:^{
        [client disconnect];
        client.delegate = nil;
    }];

    // Set up connection expectation to wait for actual connection
    XCTestExpectation *connectionExpectation = [[XCTestExpectation alloc] initWithDescription:@"Client connected"];
    self.connectionExpectation = connectionExpectation;

    XCTAssertTrue([client connectEncryptedWithKeyPair:keyPairData], @"Should connect with valid key pair");
    XCTAssertNotNil(client.socket.encrypter.keyPairData, @"Client internal socket encrypter keyPairData should not be nil");
    XCTAssertEqualObjects(client.socket.encrypter.keyPairData, keyPairData, @"Client internal socket encrypter keyPairData should equal server keyPair");

    // Wait for connection to complete properly (delegate callback)
    XCTWaiterResult connectionResult = [XCTWaiter waitForExpectations:@[connectionExpectation] timeout:5.0];
    XCTAssertEqual(connectionResult, XCTWaiterResultCompleted, @"Should connect within timeout");

    XCTAssertTrue([client isConnected], @"Client should be connected");
    XCTAssertTrue(client.socket.isEncrypting, @"Client internal socket should be encrypting");

    [client.socket.encrypter generateSalt];
    XCTAssertTrue([client.socket.encrypter beginEncryptingWithPeerKey:client.socket.encrypter.peerKey]); // force setting a different `symmetricKey`

    // Test sending encrypted data between client and server
    XCTestExpectation *tcpEncryptedMessageExpectation = [[XCTestExpectation alloc] initWithDescription:@"Encrypted message received"];
    self.tcpEncryptedMessageExpectation = tcpEncryptedMessageExpectation;

    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:@"/tcp/encrypted/test" arguments:@[@"encrypted_data", @(42)]];
    XCTAssertNoThrow([client sendPacket:message], @"Sending encrypted message should not crash");

    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[tcpEncryptedMessageExpectation] timeout:2.0];
    XCTAssertEqual(result, XCTWaiterResultTimedOut, @"Should not receive message encrypted with different salt through server");

    F53OSCMessage *receivedMessage = self.receivedMessage;
    XCTAssertNil(receivedMessage, @"Should not receive message encrypted with different salt through server");
}

- (void)testThat_tcpClientCanSendMessageWithInvalidEncryptionConfiguration
{
    F53OSCClient *client = [[F53OSCClient alloc] init];
    client.host = @"localhost";
    client.port = PORT_BASE + 70;
    client.useTcp = YES;
    client.delegate = self;

    F53OSCServer *server = [self basicServerWithPort:client.port];

    // Configure server with nil key pair (no encryption)
    server.keyPair = nil;

    BOOL isListening = [server startListening];
    XCTAssertTrue(isListening, @"Server should start listening");

    [self addTeardownBlock:^{
        [client disconnect];
        client.delegate = nil;
    }];

    // Set up connection expectation to wait for actual connection
    XCTestExpectation *connectionExpectation = [[XCTestExpectation alloc] initWithDescription:@"Client connected"];
    self.connectionExpectation = connectionExpectation;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertTrue([client connectEncryptedWithKeyPair:nil], @"Should handle nil key pair gracefully but still connect");
    XCTAssertNil(client.socket.encrypter.keyPairData, @"Client internal socket encrypter keyPairData should be nil");
#pragma clang diagnostic pop

    // Wait for connection to complete properly (delegate callback)
    XCTWaiterResult connectionResult = [XCTWaiter waitForExpectations:@[connectionExpectation] timeout:5.0];
    XCTAssertEqual(connectionResult, XCTWaiterResultCompleted, @"Should connect within timeout");

    XCTAssertTrue([client isConnected], @"Client should be connected");
    XCTAssertFalse(client.socket.isEncrypting, @"Client internal socket should not be encrypting");

    // Test sending data between client and server, should not be encrypted
    XCTestExpectation *tcpUnencryptedMessageExpectation = [[XCTestExpectation alloc] initWithDescription:@"Unencrypted message received"];
    self.tcpUnencryptedMessageExpectation = tcpUnencryptedMessageExpectation;

    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:@"/tcp/unencrypted/test" arguments:@[@"unencrypted_data", @(123)]];
    XCTAssertNoThrow([client sendPacket:message], @"Sending unencrypted message should not crash");

    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[tcpUnencryptedMessageExpectation] timeout:2.0];
    XCTAssertEqual(result, XCTWaiterResultCompleted, @"Should receive unencrypted message through server");

    F53OSCMessage *receivedMessage = self.receivedMessage;
    XCTAssertEqualObjects(receivedMessage.addressPattern, @"/tcp/unencrypted/test", @"Address should match");
    XCTAssertEqual(receivedMessage.arguments.count, 2, @"Should have two arguments");
    XCTAssertEqualObjects(receivedMessage.arguments.firstObject, @"unencrypted_data", @"Argument should match");
    XCTAssertEqualObjects(receivedMessage.arguments.lastObject, @(123), @"Argument should match");

    // Verify encryption is not active on server
    XCTAssertNil(server.keyPair, @"Server keyPair should remain nil (no encryption)");
}

- (void)testThat_udpClientCanSendMessageWithAttemptedEncryptionIgnored
{
    F53OSCClient *client = [[F53OSCClient alloc] init];
    client.host = @"localhost";
    client.port = PORT_BASE + 80;
    client.useTcp = NO; // UDP, encryption not supported
    client.delegate = self;

    F53OSCServer *server = [self basicServerWithPort:client.port];

    F53OSCEncrypt *encrypter = [[F53OSCEncrypt alloc] init];
    NSData *keyPairData = [encrypter generateKeyPair];
    XCTAssertNotNil(keyPairData, @"keyPairData should not be nil");

    // Configure server with same key pair for encryption
    server.keyPair = keyPairData;

    BOOL isListening = [server startListening];
    XCTAssertTrue(isListening, @"Server should start listening");

    [self addTeardownBlock:^{
        [client disconnect];
        client.delegate = nil;
    }];

    // Set up connection expectation to wait for actual connection
    XCTestExpectation *connectionExpectation = [[XCTestExpectation alloc] initWithDescription:@"Client connected"];
    self.connectionExpectation = connectionExpectation;

    XCTAssertTrue([client connectEncryptedWithKeyPair:keyPairData], @"Should connect with valid key pair, but no handshake will take place");
    XCTAssertNotNil(client.socket.encrypter.keyPairData, @"Client internal socket encrypter keyPairData should not be nil");
    XCTAssertEqualObjects(client.socket.encrypter.keyPairData, keyPairData, @"Client internal socket encrypter keyPairData should equal server keyPair");

    // UDP clients do not automatically initiate any encryption handshake.
    // Here we try to request a session, which should be ignored.
    F53OSCEncryptHandshake *handshake = [F53OSCEncryptHandshake handshakeWithEncrypter:client.socket.encrypter];
    F53OSCMessage *requestMessage = [handshake requestEncryptionMessage];
    XCTAssertNotNil(requestMessage, @"Handshake request message should not be nil");
    XCTAssertNoThrow([client sendPacket:requestMessage], @"Sending request message should not crash, but it will be ignored");

    // No connection delegate callback for UDP clients
    [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:5.0]];

    XCTAssertTrue([client isConnected], @"Client should be connected");
    XCTAssertFalse(client.socket.isEncrypting, @"Client internal socket should not be encrypting");

    F53OSCMessage *beginMessage = [handshake beginEncryptionMessage];
    XCTAssertNotNil(beginMessage, @"Handshake begin message should not be nil");
    XCTAssertNoThrow([client sendPacket:beginMessage], @"Sending begin message should not crash, but it will be ignored");

    // Test sending encrypted data between client and server
    XCTestExpectation *udpAttemptedEncryptedMessageExpectation = [[XCTestExpectation alloc] initWithDescription:@"Attempted encrypted message received"];
    self.udpAttemptedEncryptedMessageExpectation = udpAttemptedEncryptedMessageExpectation;

    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:@"/udp/encrypted/attempt/test" arguments:@[@"encrypted_data", @(42)]];
    XCTAssertNoThrow([client sendPacket:message], @"Sending attempted encrypted message should not crash, even though it will not be encrypted");

    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[udpAttemptedEncryptedMessageExpectation] timeout:2.0];
    XCTAssertEqual(result, XCTWaiterResultCompleted, @"Should receive attempted encrypted message through server");

    F53OSCMessage *receivedMessage = self.receivedMessage;
    XCTAssertEqualObjects(receivedMessage.addressPattern, @"/udp/encrypted/attempt/test", @"Message address should match");
    XCTAssertEqual(receivedMessage.arguments.count, 2, @"Should have two arguments");
    XCTAssertEqualObjects(receivedMessage.arguments.firstObject, @"encrypted_data", @"Message argument should match");
    XCTAssertEqualObjects(receivedMessage.arguments.lastObject, @(42), @"Message argument should match");
}


#pragma mark - Control message handling tests

- (void)testThat_clientHandlesControlMessageWithValidMessage
{
    F53OSCClient *client = [[F53OSCClient alloc] init];

    // Test with valid control message
    F53OSCMessage *controlMessage = [F53OSCMessage messageWithAddressPattern:@"!/client/control" arguments:@[@"control_arg"]];
    XCTAssertNoThrow([client handleF53OSCControlMessage:controlMessage], @"Should handle valid control message gracefully");

    // Test with complex control message
    F53OSCMessage *complexControl = [F53OSCMessage messageWithAddressPattern:@"!/complex/control/path" arguments:@[@"arg1", @42, @3.14f]];
    XCTAssertNoThrow([client handleF53OSCControlMessage:complexControl], @"Should handle complex control message gracefully");
}

- (void)testThat_clientHandlesControlMessageWithEncryptHandshakeMessage
{
    F53OSCClient *client = [[F53OSCClient alloc] init];

    F53OSCEncrypt *encrypter = [[F53OSCEncrypt alloc] init];

    // Generate key pair and salt.
    NSData *keyPairData = [encrypter generateKeyPair];
    XCTAssertNotNil(keyPairData, @"keyPairData should not be nil");

    [encrypter generateSalt];

    XCTAssertTrue([client connectEncryptedWithKeyPair:keyPairData], @"Should connect with valid key pair");
    XCTAssertNotNil(client.socket.encrypter.keyPairData, @"Client internal socket encrypter keyPairData should not be nil");
    XCTAssertEqualObjects(client.socket.encrypter.keyPairData, keyPairData, @"Client internal socket encrypter keyPairData should equal server keyPair");
    XCTAssertFalse(client.socket.isEncrypting, @"Client internal socket should not be encrypting before handling approve message");

    // NOTE: Full handshake testing is in F53OSC_EncryptTests.m.
    // We are only testing the F53OSCClient requirements here.

    F53OSCEncryptHandshake *handshake = [F53OSCEncryptHandshake handshakeWithEncrypter:encrypter];

    F53OSCMessage *message = [handshake approveEncryptionMessage];

    XCTAssertNoThrow([client handleF53OSCControlMessage:message], @"Should handle valid approve message gracefully");
    XCTAssertTrue(client.socket.isEncrypting, @"Client internal socket should be encrypting after handling approve message");
}

- (void)testThat_clientHandlesNilControlMessage
{
    F53OSCClient *client = [[F53OSCClient alloc] init];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertNoThrow([client handleF53OSCControlMessage:nil], @"Should handle nil control message gracefully");
#pragma clang diagnostic pop
}


#pragma mark - Socket delegate method tests

- (void)testThat_clientNewSocketQueueForConnectionFromAddress
{
    F53OSCClient *client = [[F53OSCClient alloc] init];

    GCDAsyncSocket *socket = [[GCDAsyncSocket alloc] initWithDelegate:nil delegateQueue:dispatch_get_main_queue()];

    // Test new socket queue method
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    dispatch_queue_t resultQueue = [client newSocketQueueForConnectionFromAddress:nil onSocket:socket];
#pragma clang diagnostic pop

    XCTAssertNotNil(resultQueue, @"Should return a dispatch queue");
    // The method should return the client's socket delegate queue
    XCTAssertEqual(resultQueue, client.socketDelegateQueue, @"Should return the client's socket delegate queue");
}

- (void)testThat_clientSocketDidAcceptNewSocket
{
    F53OSCClient *client = [[F53OSCClient alloc] init];

    GCDAsyncSocket *socket = [[GCDAsyncSocket alloc] initWithDelegate:nil delegateQueue:dispatch_get_main_queue()];
    GCDAsyncSocket *newSocket = [[GCDAsyncSocket alloc] initWithDelegate:nil delegateQueue:dispatch_get_main_queue()];

    // Test socket acceptance - should handle gracefully
    XCTAssertNoThrow([client socket:socket didAcceptNewSocket:newSocket], @"Should handle new socket acceptance gracefully");
}

- (void)testThat_clientSocketDidReadDataWithTag
{
    F53OSCClient *client = [[F53OSCClient alloc] init];

    GCDAsyncSocket *socket = [[GCDAsyncSocket alloc] initWithDelegate:nil delegateQueue:dispatch_get_main_queue()];
    NSData *testData = [@"test data" dataUsingEncoding:NSUTF8StringEncoding];

    // Test data reading - should handle gracefully
    XCTAssertNoThrow([client socket:socket didReadData:testData withTag:0], @"Should handle socket data reading gracefully");
}

- (void)testThat_clientSocketDidReadPartialDataOfLengthTag
{
    F53OSCClient *client = [[F53OSCClient alloc] init];

    GCDAsyncSocket *socket = [[GCDAsyncSocket alloc] initWithDelegate:nil delegateQueue:dispatch_get_main_queue()];

    // Test partial data reading - should handle gracefully
    XCTAssertNoThrow([client socket:socket didReadPartialDataOfLength:100 tag:0], @"Should handle partial data reading gracefully");
}

- (void)testThat_clientSocketDidWritePartialDataOfLengthTag
{
    F53OSCClient *client = [[F53OSCClient alloc] init];

    GCDAsyncSocket *socket = [[GCDAsyncSocket alloc] initWithDelegate:nil delegateQueue:dispatch_get_main_queue()];

    // Test partial data writing - should handle gracefully
    XCTAssertNoThrow([client socket:socket didWritePartialDataOfLength:50 tag:0], @"Should handle partial data writing gracefully");
}

- (void)testThat_clientSocketShouldTimeoutWriteWithTag
{
    F53OSCClient *client = [[F53OSCClient alloc] init];

    GCDAsyncSocket *socket = [[GCDAsyncSocket alloc] initWithDelegate:nil delegateQueue:dispatch_get_main_queue()];

    // Test write timeout - should return NO to continue
    BOOL shouldTimeout = [client socket:socket shouldTimeoutWriteWithTag:0 elapsed:5.0 bytesDone:100];
    XCTAssertFalse(shouldTimeout, @"Should not timeout write operations by default");
}

- (void)testThat_clientSocketDidCloseReadStream
{
    F53OSCClient *client = [[F53OSCClient alloc] init];

    GCDAsyncSocket *socket = [[GCDAsyncSocket alloc] initWithDelegate:nil delegateQueue:dispatch_get_main_queue()];

    // Test read stream closing - should handle gracefully
    XCTAssertNoThrow([client socketDidCloseReadStream:socket], @"Should handle read stream closing gracefully");
}

- (void)testThat_clientSocketDidSecure
{
    F53OSCClient *client = [[F53OSCClient alloc] init];

    GCDAsyncSocket *socket = [[GCDAsyncSocket alloc] initWithDelegate:nil delegateQueue:dispatch_get_main_queue()];

    // Test socket securing - should handle gracefully
    XCTAssertNoThrow([client socketDidSecure:socket], @"Should handle socket securing gracefully");
}


#pragma mark - UDP socket delegate method tests

- (void)testThat_clientUdpSocketDidConnectToAddress
{
    F53OSCClient *client = [[F53OSCClient alloc] init];

    GCDAsyncUdpSocket *udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:nil delegateQueue:dispatch_get_main_queue()];

    // Create an address (localhost)
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    addr.sin_port = htons(8080);
    NSData *addressData = [NSData dataWithBytes:&addr length:sizeof(addr)];

    // Test UDP connection - should handle gracefully
    XCTAssertNoThrow([client udpSocket:udpSocket didConnectToAddress:addressData], @"Should handle UDP connection gracefully");
}

- (void)testThat_clientUdpSocketDidNotConnect
{
    F53OSCClient *client = [[F53OSCClient alloc] init];

    GCDAsyncUdpSocket *udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:nil delegateQueue:dispatch_get_main_queue()];
    NSError *mockError = [NSError errorWithDomain:@"TestErrorDomain" code:100 userInfo:@{NSLocalizedDescriptionKey: @"Test connection error"}];

    // Test UDP connection failure - should handle gracefully
    XCTAssertNoThrow([client udpSocket:udpSocket didNotConnect:mockError], @"Should handle UDP connection failure gracefully");
}

- (void)testThat_clientUdpSocketDidNotSendDataWithTag
{
    F53OSCClient *client = [[F53OSCClient alloc] init];

    GCDAsyncUdpSocket *udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:nil delegateQueue:dispatch_get_main_queue()];
    NSError *mockError = [NSError errorWithDomain:@"TestErrorDomain" code:200 userInfo:@{NSLocalizedDescriptionKey: @"Test send error"}];

    // Test UDP send failure - should handle gracefully
    XCTAssertNoThrow([client udpSocket:udpSocket didNotSendDataWithTag:0 dueToError:mockError], @"Should handle UDP send failure gracefully");
}

- (void)testThat_clientUdpSocketDidReceiveDataFromAddress
{
    F53OSCClient *client = [[F53OSCClient alloc] init];

    GCDAsyncUdpSocket *udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:nil delegateQueue:dispatch_get_main_queue()];
    NSData *testData = [@"test udp data" dataUsingEncoding:NSUTF8StringEncoding];

    // Create an address
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    addr.sin_port = htons(8080);
    NSData *addressData = [NSData dataWithBytes:&addr length:sizeof(addr)];

    // Test UDP data reception - should handle gracefully
    XCTAssertNoThrow([client udpSocket:udpSocket didReceiveData:testData fromAddress:addressData withFilterContext:nil], @"Should handle UDP data reception gracefully");
}


#pragma mark - Socket delegate queue tests

- (void)testThat_clientSocketDelegateQueueHandlesRepeatedChanges
{
    F53OSCClient *client = [[F53OSCClient alloc] init];

    [self addTeardownBlock:^{
        [client disconnect];
        client.delegate = nil;
    }];

    dispatch_queue_t queue1 = dispatch_queue_create("test.queue.1", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t queue2 = dispatch_queue_create("test.queue.2", DISPATCH_QUEUE_SERIAL);

    // Change queue multiple times before connecting
    client.socketDelegateQueue = queue1;
    XCTAssertEqual(client.socketDelegateQueue, queue1, @"Should set first queue");

    client.socketDelegateQueue = queue2;
    XCTAssertEqual(client.socketDelegateQueue, queue2, @"Should set second queue");

    client.socketDelegateQueue = dispatch_get_main_queue();
    XCTAssertEqual(client.socketDelegateQueue, dispatch_get_main_queue(), @"Should set main queue");
}

- (void)testThat_clientSocketDelegateQueueHandlesConnectionStateChanges
{
    F53OSCClient *client = [[F53OSCClient alloc] init];
    client.port = PORT_BASE + 90;

    [self addTeardownBlock:^{
        [client disconnect];
        client.delegate = nil;
    }];

    F53OSCServer *server = [self basicServerWithPort:client.port];
    BOOL isListening = [server startListening];
    XCTAssertTrue(isListening, @"Server should start listening");

    // Connect with default queue
    [client connect];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertTrue(client.isConnected, @"Should connect with default queue");

    // Change queue while connected - should recreate socket
    dispatch_queue_t customQueue = dispatch_queue_create("test.connected.queue", DISPATCH_QUEUE_SERIAL);
    client.socketDelegateQueue = customQueue;
    XCTAssertEqual(client.socketDelegateQueue, customQueue, @"Should change queue while connected");

    // Should still be able to send messages
    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:@"/queue/test" arguments:@[@"test"]];
    XCTAssertNoThrow([client sendPacket:message], @"Should send message after queue change");
}


#pragma mark - F53OSCServerDelegate

- (void)takeMessage:(nullable F53OSCMessage *)message
{
    self.receivedMessage = message;

    if ([message.addressPattern hasPrefix:@"/chunk"])
        [self.chunkedMessageExpectation fulfill];
    else if ([message.addressPattern hasPrefix:@"/tcp/unencrypted"])
        [self.tcpUnencryptedMessageExpectation fulfill];
    else if ([message.addressPattern hasPrefix:@"/tcp/encrypted"])
        [self.tcpEncryptedMessageExpectation fulfill];
    else if ([message.addressPattern hasPrefix:@"/udp/encrypted"])
        [self.udpAttemptedEncryptedMessageExpectation fulfill];
}


#pragma mark - F53OSCClientDelegate

- (void)clientDidConnect:(F53OSCClient *)client
{
    if (self.connectionExpectation)
        [self.connectionExpectation fulfill];
}

- (void)clientDidDisconnect:(F53OSCClient *)client
{
    if (self.disconnectionExpectation)
        [self.disconnectionExpectation fulfill];
}

@end

NS_ASSUME_NONNULL_END
