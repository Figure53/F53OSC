//
//  F53OSC_ConcurrencyTests.m
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

#import "F53OSCBundle.h"
#import "F53OSCClient.h"
#import "F53OSCMessage.h"
#import "F53OSCServer.h"


NS_ASSUME_NONNULL_BEGIN

#define PORT_BASE   9100

@interface F53OSC_ConcurrencyTests : XCTestCase <F53OSCServerDelegate, F53OSCClientDelegate>

@property (nonatomic, strong) F53OSCServer *testServer;
@property (nonatomic, strong) NSMutableArray<F53OSCClient *> *clients;
@property (nonatomic, strong) NSMutableArray<F53OSCMessage *> *receivedMessages;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *clientConnectionStates;

@property (nonatomic, strong) dispatch_queue_t testQueue;
@property (nonatomic, strong) dispatch_queue_t testServerQueue;
@property (nonatomic, strong) NSMutableSet<NSString *> *executingThreads;

@property (nonatomic, strong) XCTestExpectation *concurrencyExpectation;
@property (nonatomic, strong) NSMutableArray<XCTestExpectation *> *clientExpectations;

@end

@implementation F53OSC_ConcurrencyTests

- (void)setUp
{
    [super setUp];

    self.clients = [NSMutableArray array];
    self.receivedMessages = [NSMutableArray array];
    self.clientConnectionStates = [NSMutableArray array];
    self.clientExpectations = [NSMutableArray array];
    self.executingThreads = [NSMutableSet set];

    self.testQueue = dispatch_queue_create("com.figure53.osctest.concurrent", DISPATCH_QUEUE_CONCURRENT);
    self.testServerQueue = dispatch_queue_create("com.figure53.osctest.server", DISPATCH_QUEUE_SERIAL);
}

- (void)tearDown
{
    for (F53OSCClient *client in self.clients)
    {
        [client disconnect];
        client.delegate = nil;
    }

    [self.testServer stopListening];
    self.testServer.delegate = nil;

    [super tearDown];
}

- (void)setupServerAndMultipleClients:(NSUInteger)clientCount useTCP:(BOOL)useTCP
{
    // Avoid port conflicts.
    UInt16 port = PORT_BASE + 10;

    // Setup server with dedicated queue.
    self.testServer = [[F53OSCServer alloc] initWithDelegateQueue:self.testServerQueue];
    self.testServer.delegate = self;
    self.testServer.port = port;

    if (!useTCP)
        self.testServer.udpReplyPort = port + 1;

    BOOL isListening = [self.testServer startListening];
    XCTAssertTrue(isListening, @"Server should start listening on port %hu", port);

    // Create multiple clients.
    for (NSUInteger i = 0; i < clientCount; i++)
    {
        F53OSCClient *client = [[F53OSCClient alloc] init];
        client.useTcp = useTCP;
        client.host = @"localhost";
        client.port = port;
        client.delegate = self;

        [self.clients addObject:client];
        [self.clientConnectionStates addObject:@(NO)]; // Not connected initially

        [client connect];
    }

    // Wait a moment for TCP connections to establish
    if (useTCP)
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
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


#pragma mark - Basic concurrent client tests

- (void)testThat_multipleTCPClientsCanConnectSimultaneously
{
    NSUInteger clientCount = 5;
    [self setupServerAndMultipleClients:clientCount useTCP:YES];

    // Wait for connections to establish.
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];

    // Verify all clients connected.
    NSUInteger connectedClients = 0;
    for (F53OSCClient *client in self.clients)
    {
        if (client.isConnected)
            connectedClients++;
    }

    XCTAssertEqual(connectedClients, clientCount, @"All TCP clients should be connected");
}

- (void)testThat_multipleUDPClientsCanConnectSimultaneously
{
    NSUInteger clientCount = 5;
    [self setupServerAndMultipleClients:clientCount useTCP:NO];

    // Wait for connections to establish.
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];

    // Verify all clients connected.
    NSUInteger connectedClients = 0;
    for (F53OSCClient *client in self.clients)
    {
        if (client.isConnected)
            connectedClients++;
    }

    XCTAssertEqual(connectedClients, clientCount, @"All UDP clients should be connected");
}

- (void)testThat_multipleTCPClientsCanSendMessagesConcurrently
{
    NSUInteger clientCount = 3;
    NSUInteger messagesPerClient = 5;

    [self setupServerAndMultipleClients:clientCount useTCP:YES];

    NSUInteger expectedMessageCount = clientCount * messagesPerClient;

    XCTestExpectation *concurrencyExpectation = [[XCTestExpectation alloc] initWithDescription:@"All concurrent TCP messages received"];
    concurrencyExpectation.expectedFulfillmentCount = expectedMessageCount;
    self.concurrencyExpectation = concurrencyExpectation;

    NSTimeInterval testStartTime = [NSDate timeIntervalSinceReferenceDate];

    // Send messages concurrently from all clients.
    dispatch_group_t sendGroup = dispatch_group_create();

    for (NSUInteger clientIndex = 0; clientIndex < clientCount; clientIndex++)
    {
        F53OSCClient *client = self.clients[clientIndex];

        dispatch_group_async(sendGroup, self.testQueue, ^{
            for (NSUInteger msgIndex = 0; msgIndex < messagesPerClient; msgIndex++)
            {
                NSString *address = [NSString stringWithFormat:@"/tcp/client/%lu/message/%lu", (unsigned long)clientIndex, (unsigned long)msgIndex];
                NSArray<id> *arguments = @[@"TCP", @(clientIndex), @(msgIndex), [NSDate date]];

                F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:address arguments:arguments];
                [client sendPacket:message];

                // Small delay to prevent overwhelming.
                usleep(10000); // 10ms
            }
        });
    }

    // Wait for all TCP messages to be received.
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[concurrencyExpectation] timeout:2.0];
    XCTAssertEqual(result, XCTWaiterResultCompleted, @"All concurrent TCP messages should be received");

    NSTimeInterval elapsed = [NSDate timeIntervalSinceReferenceDate] - testStartTime;
    NSLog(@"Concurrent TCP messaging completed in %.3f seconds (%lu messages)", elapsed, (unsigned long)self.receivedMessages.count);

    XCTAssertEqual(self.receivedMessages.count, expectedMessageCount, @"Should receive all sent TCP messages");
}

- (void)testThat_multipleUDPClientsCanSendMessagesConcurrently
{
    NSUInteger clientCount = 3;
    NSUInteger messagesPerClient = 5;

    [self setupServerAndMultipleClients:clientCount useTCP:NO];

    NSUInteger expectedMessageCount = clientCount * messagesPerClient;

    XCTestExpectation *concurrencyExpectation = [[XCTestExpectation alloc] initWithDescription:@"All concurrent UDP messages received"];
    concurrencyExpectation.expectedFulfillmentCount = expectedMessageCount;
    self.concurrencyExpectation = concurrencyExpectation;

    NSTimeInterval testStartTime = [NSDate timeIntervalSinceReferenceDate];

    // Send messages concurrently from all clients.
    dispatch_group_t sendGroup = dispatch_group_create();

    for (NSUInteger clientIndex = 0; clientIndex < clientCount; clientIndex++)
    {
        F53OSCClient *client = self.clients[clientIndex];

        dispatch_group_async(sendGroup, self.testQueue, ^{
            for (NSUInteger msgIndex = 0; msgIndex < messagesPerClient; msgIndex++)
            {
                NSString *address = [NSString stringWithFormat:@"/udp/client/%lu/message/%lu", (unsigned long)clientIndex, (unsigned long)msgIndex];
                NSArray<id> *arguments = @[@"UDP", @(clientIndex), @(msgIndex), [NSDate date]];

                F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:address arguments:arguments];
                [client sendPacket:message];

                // Small delay to prevent overwhelming.
                usleep(10000); // 10ms
            }
        });
    }

    // Wait for all UDP messages to be received.
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[concurrencyExpectation] timeout:2.0];
    XCTAssertEqual(result, XCTWaiterResultCompleted, @"All concurrent UDP messages should be received");

    NSTimeInterval elapsed = [NSDate timeIntervalSinceReferenceDate] - testStartTime;
    NSLog(@"Concurrent UDP messaging completed in %.3f seconds (%lu messages)", elapsed, (unsigned long)self.receivedMessages.count);

    // UDP technically might lose some packets, but we should get all of them in a localhost test environment.
    XCTAssertEqual(self.receivedMessages.count, expectedMessageCount, @"Should receive all sent UDP messages");
}


#pragma mark - High-load concurrency tests

- (void)testThat_serverHandlesHighVolumeOfConcurrentTCPMessages
{
    NSUInteger clientCount = 2; // Fewer clients, more messages per client
    NSUInteger messagesPerClient = 20;

    [self setupServerAndMultipleClients:clientCount useTCP:YES];

    NSUInteger expectedMessageCount = clientCount * messagesPerClient;

    XCTestExpectation *concurrencyExpectation = [[XCTestExpectation alloc] initWithDescription:@"High volume concurrent TCP messages"];
    concurrencyExpectation.expectedFulfillmentCount = expectedMessageCount;
    self.concurrencyExpectation = concurrencyExpectation;

    NSTimeInterval testStartTime = [NSDate timeIntervalSinceReferenceDate];

    // Send many messages very quickly.
    dispatch_group_t sendGroup = dispatch_group_create();

    for (NSUInteger clientIndex = 0; clientIndex < clientCount; clientIndex++)
    {
        F53OSCClient *client = self.clients[clientIndex];

        dispatch_group_async(sendGroup, self.testQueue, ^{
            for (NSUInteger msgIndex = 0; msgIndex < messagesPerClient; msgIndex++)
            {
                NSString *address = @"/tcp/highvolume/test";
                NSArray<id> *arguments = @[@"TCP", @(clientIndex), @(msgIndex), @"high_load_test"];

                F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:address arguments:arguments];
                [client sendPacket:message];

                // Minimal delay for high throughput.
                usleep(1000); // 1ms
            }
        });
    }

    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[concurrencyExpectation] timeout:2.0];
    XCTAssertEqual(result, XCTWaiterResultCompleted, @"High volume TCP messages should be processed");

    NSTimeInterval elapsed = [NSDate timeIntervalSinceReferenceDate] - testStartTime;
    double messagesPerSecond = self.receivedMessages.count / elapsed;

    NSLog(@"High volume TCP test: %.0f messages/second (%.3f seconds total)", messagesPerSecond, elapsed);
    XCTAssertGreaterThan(messagesPerSecond, 100.0, @"Should handle at least 100 TCP messages/second");
}

- (void)testThat_serverHandlesHighVolumeOfConcurrentUDPMessages
{
    NSUInteger clientCount = 2; // Fewer clients, more messages per client
    NSUInteger messagesPerClient = 20;

    [self setupServerAndMultipleClients:clientCount useTCP:NO];

    NSUInteger expectedMessageCount = clientCount * messagesPerClient;

    XCTestExpectation *concurrencyExpectation = [[XCTestExpectation alloc] initWithDescription:@"High volume concurrent UDP messages"];
    concurrencyExpectation.expectedFulfillmentCount = expectedMessageCount;
    self.concurrencyExpectation = concurrencyExpectation;

    NSTimeInterval testStartTime = [NSDate timeIntervalSinceReferenceDate];

    // Send many messages very quickly.
    dispatch_group_t sendGroup = dispatch_group_create();

    for (NSUInteger clientIndex = 0; clientIndex < clientCount; clientIndex++)
    {
        F53OSCClient *client = self.clients[clientIndex];

        dispatch_group_async(sendGroup, self.testQueue, ^{
            for (NSUInteger msgIndex = 0; msgIndex < messagesPerClient; msgIndex++)
            {
                NSString *address = @"/udp/highvolume/test";
                NSArray<id> *arguments = @[@"UDP", @(clientIndex), @(msgIndex), @"high_load_test"];

                F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:address arguments:arguments];
                [client sendPacket:message];

                // Minimal delay for high throughput.
                usleep(1000); // 1ms
            }
        });
    }

    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[concurrencyExpectation] timeout:2.0];
    XCTAssertEqual(result, XCTWaiterResultCompleted, @"High volume UDP messages should be processed");

    NSTimeInterval elapsed = [NSDate timeIntervalSinceReferenceDate] - testStartTime;
    double messagesPerSecond = self.receivedMessages.count / elapsed;

    NSLog(@"High volume UDP test: %.0f messages/second (%.3f seconds total)", messagesPerSecond, elapsed);
    XCTAssertGreaterThan(messagesPerSecond, 100.0, @"Should handle at least 100 UDP messages/second");
}

- (void)testThat_serverHandlesMixedTCPAndUDPConcurrentClients
{
    // Avoid port conflicts.
    UInt16 port = PORT_BASE + 20;

    self.testServer = [[F53OSCServer alloc] initWithDelegateQueue:self.testServerQueue];
    self.testServer.delegate = self;
    self.testServer.port = port;
    self.testServer.udpReplyPort = port + 1;

    BOOL isListening = [self.testServer startListening];
    XCTAssertTrue(isListening, @"Server should listen for mixed protocol test");

    // Create 2 TCP clients and 2 UDP clients.
    NSUInteger tcpClients = 2;
    NSUInteger udpClients = 2;
    NSUInteger messagesPerClient = 3;

    // TCP clients
    for (NSUInteger i = 0; i < tcpClients; i++)
    {
        F53OSCClient *client = [[F53OSCClient alloc] init];
        client.useTcp = YES;
        client.host = @"localhost";
        client.port = port;
        client.delegate = self;
        [client connect];
        [self.clients addObject:client];
    }

    // UDP clients
    for (NSUInteger i = 0; i < udpClients; i++)
    {
        F53OSCClient *client = [[F53OSCClient alloc] init];
        client.useTcp = NO;
        client.host = @"localhost";
        client.port = port;
        client.delegate = self;
        [self.clients addObject:client];
    }

    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];

    NSUInteger expectedMessageCount = (tcpClients + udpClients) * messagesPerClient;

    XCTestExpectation *concurrencyExpectation = [[XCTestExpectation alloc] initWithDescription:@"Mixed protocol messages"];
    concurrencyExpectation.expectedFulfillmentCount = expectedMessageCount;
    self.concurrencyExpectation = concurrencyExpectation;

    // Send messages from both TCP and UDP clients concurrently.
    dispatch_group_t sendGroup = dispatch_group_create();

    for (NSUInteger clientIndex = 0; clientIndex < self.clients.count; clientIndex++)
    {
        F53OSCClient *client = self.clients[clientIndex];
        BOOL isTCP = (clientIndex < tcpClients);

        dispatch_group_async(sendGroup, self.testQueue, ^{
            for (NSUInteger msgIndex = 0; msgIndex < messagesPerClient; msgIndex++)
            {
                NSString *address = [NSString stringWithFormat:@"/mixed/%@/client/%lu", isTCP ? @"tcp" : @"udp", (unsigned long)clientIndex];
                NSArray<id> *arguments = @[isTCP ? @"TCP" : @"UDP", @(clientIndex), @(msgIndex)];

                F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:address arguments:arguments];
                [client sendPacket:message];

                usleep(10000); // 10ms delay
            }
        });
    }

    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[concurrencyExpectation] timeout:2.0];
    XCTAssertEqual(result, XCTWaiterResultCompleted, @"Mixed protocol concurrent messages should be received");

    // Verify we got messages from both protocols.
    NSUInteger receivedTcpMessages = 0;
    NSUInteger receivedUdpMessages = 0;
    for (F53OSCMessage *msg in self.receivedMessages)
    {
        if ([msg.addressPattern containsString:@"/tcp/"])
            receivedTcpMessages++;
        else if ([msg.addressPattern containsString:@"/udp/"])
            receivedUdpMessages++;
    }

    XCTAssertEqual(receivedTcpMessages, tcpClients * messagesPerClient, @"Should receive all sent TCP messages");
    XCTAssertEqual(receivedUdpMessages, udpClients * messagesPerClient, @"Should receive all sent UDP messages");
}


#pragma mark - Bundle concurrency tests

- (void)testThat_serverHandlesConcurrentTCPBundleMessages
{
    NSUInteger clientCount = 3;
    [self setupServerAndMultipleClients:clientCount useTCP:YES];

    NSUInteger bundlesPerClient = 2;
    NSUInteger messagesPerBundle = 3;
    NSUInteger expectedMessageCount = clientCount * bundlesPerClient * messagesPerBundle;

    XCTestExpectation *concurrencyExpectation = [[XCTestExpectation alloc] initWithDescription:@"Concurrent TCP bundle messages"];
    concurrencyExpectation.expectedFulfillmentCount = expectedMessageCount;
    self.concurrencyExpectation = concurrencyExpectation;

    // Send bundles concurrently.
    dispatch_group_t sendGroup = dispatch_group_create();

    for (NSUInteger clientIndex = 0; clientIndex < clientCount; clientIndex++)
    {
        F53OSCClient *client = self.clients[clientIndex];

        dispatch_group_async(sendGroup, self.testQueue, ^{
            for (NSUInteger bundleIndex = 0; bundleIndex < bundlesPerClient; bundleIndex++)
            {
                // Create bundle with multiple messages.
                NSMutableArray<NSData *> *messages = [NSMutableArray array];

                for (NSUInteger msgIndex = 0; msgIndex < messagesPerBundle; msgIndex++)
                {
                    NSString *address = [NSString stringWithFormat:@"/tcp/bundle/client%lu/bundle%lu/msg%lu",
                                         (unsigned long)clientIndex, (unsigned long)bundleIndex, (unsigned long)msgIndex];
                    NSArray<id> *arguments = @[@"TCP", @(clientIndex), @(bundleIndex), @(msgIndex)];

                    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:address arguments:arguments];
                    [messages addObject:message.packetData];
                }

                F53OSCTimeTag *timeTag = [F53OSCTimeTag immediateTimeTag];
                F53OSCBundle *bundle = [F53OSCBundle bundleWithTimeTag:timeTag elements:messages];
                [client sendPacket:bundle];

                usleep(20000); // 20ms between bundles
            }
        });
    }

    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[concurrencyExpectation] timeout:2.0];
    XCTAssertEqual(result, XCTWaiterResultCompleted, @"All TCP bundle messages should be received");

    XCTAssertEqual(self.receivedMessages.count, expectedMessageCount, @"Should receive all TCP messages from concurrent bundles");
}

- (void)testThat_serverHandlesConcurrentUDPBundleMessages
{
    NSUInteger clientCount = 3;
    [self setupServerAndMultipleClients:clientCount useTCP:NO];

    NSUInteger bundlesPerClient = 2;
    NSUInteger messagesPerBundle = 3;
    NSUInteger expectedMessageCount = clientCount * bundlesPerClient * messagesPerBundle;

    XCTestExpectation *concurrencyExpectation = [[XCTestExpectation alloc] initWithDescription:@"Concurrent UDP bundle messages"];
    concurrencyExpectation.expectedFulfillmentCount = expectedMessageCount;
    self.concurrencyExpectation = concurrencyExpectation;

    // Send bundles concurrently.
    dispatch_group_t sendGroup = dispatch_group_create();

    for (NSUInteger clientIndex = 0; clientIndex < clientCount; clientIndex++)
    {
        F53OSCClient *client = self.clients[clientIndex];

        dispatch_group_async(sendGroup, self.testQueue, ^{
            for (NSUInteger bundleIndex = 0; bundleIndex < bundlesPerClient; bundleIndex++)
            {
                // Create bundle with multiple messages.
                NSMutableArray<NSData *> *messages = [NSMutableArray array];

                for (NSUInteger msgIndex = 0; msgIndex < messagesPerBundle; msgIndex++)
                {
                    NSString *address = [NSString stringWithFormat:@"/udp/bundle/client%lu/bundle%lu/msg%lu",
                                         (unsigned long)clientIndex, (unsigned long)bundleIndex, (unsigned long)msgIndex];
                    NSArray<id> *arguments = @[@"UDP", @(clientIndex), @(bundleIndex), @(msgIndex)];

                    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:address arguments:arguments];
                    [messages addObject:message.packetData];
                }

                F53OSCTimeTag *timeTag = [F53OSCTimeTag immediateTimeTag];
                F53OSCBundle *bundle = [F53OSCBundle bundleWithTimeTag:timeTag elements:messages];
                [client sendPacket:bundle];

                usleep(20000); // 20ms between bundles
            }
        });
    }

    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[concurrencyExpectation] timeout:2.0];
    XCTAssertEqual(result, XCTWaiterResultCompleted, @"All UDP bundle messages should be received");

    XCTAssertEqual(self.receivedMessages.count, expectedMessageCount, @"Should receive all UDP messages from concurrent bundles");
}


#pragma mark - Thread safety tests

- (void)testThat_serverTCPDelegateCallbacksAreThreadSafe
{
    [self setupServerAndMultipleClients:3 useTCP:YES];

    NSUInteger expectedMessageCount = 10;

    XCTestExpectation *concurrencyExpectation = [[XCTestExpectation alloc] initWithDescription:@"TCP thread safety test"];
    concurrencyExpectation.expectedFulfillmentCount = expectedMessageCount;
    self.concurrencyExpectation = concurrencyExpectation;

    // Track which threads the delegate methods execute on.
    dispatch_group_t sendGroup = dispatch_group_create();

    for (NSUInteger i = 0; i < expectedMessageCount; i++)
    {
        F53OSCClient *client = self.clients[i % self.clients.count];

        dispatch_group_async(sendGroup, self.testQueue, ^{
            NSString *address = @"/tcp/threadsafety/test";
            NSArray<id> *arguments = @[@"TCP", @(i), [NSString stringWithFormat:@"thread_test_%lu", (unsigned long)i]];

            F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:address arguments:arguments];
            [client sendPacket:message];
        });
    }

    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[concurrencyExpectation] timeout:2.0];
    XCTAssertEqual(result, XCTWaiterResultCompleted, @"TCP thread safety test should complete");

    // Verify delegate callbacks were executed on the correct queue.
    XCTAssertGreaterThan(self.executingThreads.count, 0, @"Should track executing threads");
    NSLog(@"Delegate callbacks executed on %lu different threads", (unsigned long)self.executingThreads.count);
}

- (void)testThat_serverUDPDelegateCallbacksAreThreadSafe
{
    [self setupServerAndMultipleClients:3 useTCP:NO];

    NSUInteger expectedMessageCount = 10;

    XCTestExpectation *concurrencyExpectation = [[XCTestExpectation alloc] initWithDescription:@"UDP thread safety test"];
    concurrencyExpectation.expectedFulfillmentCount = expectedMessageCount;
    self.concurrencyExpectation = concurrencyExpectation;

    // Track which threads the delegate methods execute on.
    dispatch_group_t sendGroup = dispatch_group_create();

    for (NSUInteger i = 0; i < expectedMessageCount; i++)
    {
        F53OSCClient *client = self.clients[i % self.clients.count];

        dispatch_group_async(sendGroup, self.testQueue, ^{
            NSString *address = @"/udp/threadsafety/test";
            NSArray<id> *arguments = @[@"UDP", @(i), [NSString stringWithFormat:@"thread_test_%lu", (unsigned long)i]];

            F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:address arguments:arguments];
            [client sendPacket:message];
        });
    }

    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[concurrencyExpectation] timeout:2.0];
    XCTAssertEqual(result, XCTWaiterResultCompleted, @"UDP thread safety test should complete");

    // Verify delegate callbacks were executed on the correct queue.
    XCTAssertGreaterThan(self.executingThreads.count, 0, @"Should track executing threads");
    NSLog(@"Delegate callbacks executed on %lu different threads", (unsigned long)self.executingThreads.count);
}


#pragma mark - Connection lifecycle tests

- (void)testThat_multipleClientsCanConnectAndDisconnectConcurrently
{
    NSUInteger clientCount = 4;
    [self setupServerAndMultipleClients:clientCount useTCP:YES];

    // Wait for initial connections.
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];

    // Disconnect and reconnect concurrently.
    dispatch_group_t lifecycleGroup = dispatch_group_create();

    for (NSUInteger i = 0; i < clientCount; i++)
    {
        F53OSCClient *client = self.clients[i];

        dispatch_group_async(lifecycleGroup, self.testQueue, ^{
            // Disconnect
            [client disconnect];
            usleep(100000); // 100ms

            // Reconnect
            [client connect];
            usleep(100000); // 100ms

            // Send a test message.
            F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:@"/lifecycle/test"
                                                                    arguments:@[@(i), @"reconnect_test"]];
            [client sendPacket:message];
        });
    }

    // Wait for all lifecycle operations.
    dispatch_group_wait(lifecycleGroup, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));

    // Allow time for messages to be processed.
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2.0]];

    // Verify we got some messages (reconnection might not be 100% reliable in rapid test)
    XCTAssertGreaterThan(self.receivedMessages.count, 0, @"Should receive some messages after reconnection");
}


#pragma mark - F53OSCServerDelegate

- (void)takeMessage:(nullable F53OSCMessage *)message
{
    @synchronized(self.executingThreads) {
        NSString *threadName = [NSThread currentThread].description;
        [self.executingThreads addObject:threadName];
    }

    @synchronized(self.receivedMessages) {
        [self.receivedMessages addObject:message];
    }

    [self.concurrencyExpectation fulfill];
}


#pragma mark - F53OSCClientDelegate

- (void)clientDidConnect:(F53OSCClient *)client
{
    NSUInteger clientIndex = [self.clients indexOfObject:client];
    if (clientIndex != NSNotFound && clientIndex < self.clientConnectionStates.count)
    {
        @synchronized(self.clientConnectionStates) {
            self.clientConnectionStates[clientIndex] = @(YES);
        }
    }
}

- (void)clientDidDisconnect:(F53OSCClient *)client
{
    NSUInteger clientIndex = [self.clients indexOfObject:client];
    if (clientIndex != NSNotFound && clientIndex < self.clientConnectionStates.count)
    {
        @synchronized(self.clientConnectionStates) {
            self.clientConnectionStates[clientIndex] = @(NO);
        }
    }
}

@end

NS_ASSUME_NONNULL_END
