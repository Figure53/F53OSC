//
//  F53OSC_MessageTests.m
//  F53OSC
//
//  Created by Brent Lord on 2/14/20.
//  Copyright (c) 2020-2026 Figure 53, LLC. All rights reserved.
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


NS_ASSUME_NONNULL_BEGIN

#define PORT_BASE   9400

// NOTE: Pure logic tests (message construction, property accessors, encoding,
// string parsing, and address validation) live in F53OSC_MessageLogicTests.
// This file contains only tests that send/receive messages over the network.


@interface F53OSC_MessageTests : XCTestCase <F53OSCServerDelegate, F53OSCClientDelegate>

@property (nonatomic, strong) F53OSCServer *testServer;
@property (nonatomic, strong) F53OSCClient *testClient;

@property (nonatomic, strong) XCTestExpectation *clientConnectExpectation;
@property (nonatomic, strong) NSMutableArray<XCTestExpectation *> *messageExpectations;
@property (nonatomic, strong) NSMutableDictionary<NSString *, F53OSCMessage *> *matchedExpectations;

- (nullable id)oscMessageArgumentFromString:(NSString *)qsc typeTag:(NSString *)typeTag;

@end


@implementation F53OSC_MessageTests

static UInt16 sPortOffset = 0;

- (void)setUp
{
    [super setUp];

    // set up
    self.clientConnectExpectation = [[XCTestExpectation alloc] initWithDescription:@"F53OSCClient connect"];
    self.messageExpectations = [NSMutableArray array];
    self.matchedExpectations = [NSMutableDictionary dictionary];

    // Each test gets a unique port pair (server + udpReply) to
    // avoid collisions when `setUp`/`tearDown` cycle rapidly.
    UInt16 port = PORT_BASE + (sPortOffset * 2);
    sPortOffset++;

    dispatch_queue_t oscQueue = dispatch_queue_create("com.figure53.testServer", DISPATCH_QUEUE_SERIAL);
    F53OSCServer *testServer = [[F53OSCServer alloc] initWithDelegateQueue:oscQueue];
    testServer.delegate = self;
    testServer.port = port;
    testServer.udpReplyPort = port + 1;

    F53OSCClient *testClient = [[F53OSCClient alloc] init];
    testClient.useTcp = YES;
    testClient.host = @"localhost";
    testClient.port = port;
    testClient.delegate = self;

    [self addTeardownBlock:^{
        testClient.delegate = nil;
        testServer.delegate = nil;

        [testClient disconnect];
        [testServer stopListening];
    }];
    self.testServer = testServer;
    self.testClient = testClient;

    NSError *error = nil;
    BOOL isListening = [testServer startListening:&error];
    XCTAssertTrue(isListening, @"F53OSCServer was unable to start listening on port %hu", testServer.port);
    XCTAssertNil(error, @"F53OSCServer should start listening without error");

    [self connectOSCClientAndVerify];
}

//- (void)tearDown
//{
//    [super tearDown];
//}

- (void)connectOSCClientAndVerify
{
    // connect the TCP socket
    [self.testClient connect];
    XCTWaiterResult clientConnectResult = [XCTWaiter waitForExpectations:@[self.clientConnectExpectation] timeout:2.0];
    XCTAssert(clientConnectResult == XCTWaiterResultCompleted, @"F53OSCClient for test failed to connect");
}

- (nullable id)oscMessageArgumentFromString:(NSString *)qsc typeTag:(NSString *)typeTag
{
    id arg = nil;

    // strip escaped quotes marking string argument
    if ([typeTag isEqualToString:@"s"]) // 's'
        arg = [qsc stringByReplacingOccurrencesOfString:@"\"" withString:@""];

    else if ([typeTag isEqualToString:@"b"]) // 'b'
    {
        if ([qsc hasPrefix:@"#blob"])
            qsc = [qsc substringFromIndex:5];
        if (qsc)
            arg = [[NSData alloc] initWithBase64EncodedString:(NSString * _Nonnull)qsc options:0];
    }

    else if ([typeTag isEqualToString:@"i"] || [typeTag isEqualToString:@"f"])
    {
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        [formatter setLocale:[NSLocale currentLocale]];
        [formatter setAllowsFloats:YES];
        [formatter setRoundingMode:NSNumberFormatterRoundHalfUp];

        arg = [formatter numberFromString:qsc]; // 'i' or 'f'
    }

    else if ([typeTag isEqualToString:@"T"]) // 'T'
        arg = [F53OSCValue oscTrue];

    else if ([typeTag isEqualToString:@"F"]) // 'F'
        arg = [F53OSCValue oscFalse];

    else if ([typeTag isEqualToString:@"N"]) // 'N'
        arg = [F53OSCValue oscNull];

    else if ([typeTag isEqualToString:@"I"]) // 'I'
        arg = [F53OSCValue oscImpulse];

    return arg;
}


#pragma mark - Basic configuration tests

- (void)testThat__setupWorks
{
    // given
    // - state created by `+setUp` and `-setUp`

    // when
    // - triggered by running this test

    // then
    XCTAssertTrue(self.testClient.isConnected);
}


#pragma mark - Message sending tests

- (void)testThat_messageCanSendAddressOnly
{
    // given
    NSString *address = @"/thump";
    NSString *typeTagString = @",";
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];

    // when
    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:address arguments:@[]];
    [self.testClient sendPacket:message];

    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:2.0];
    XCTAssert(result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address);

    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil(message);
    XCTAssertNotNil(messageReceived);
    XCTAssertNil(message.userData);
    XCTAssertNil(messageReceived.userData);
    XCTAssertEqualObjects(message.addressPattern, address);
    XCTAssertEqualObjects(messageReceived.addressPattern, address);
    XCTAssertEqualObjects(message.typeTagString, typeTagString);
    XCTAssertEqualObjects(messageReceived.typeTagString, typeTagString);
    XCTAssertEqual(message.arguments.count, 0);
    XCTAssertEqual(messageReceived.arguments.count, 0);
}

- (void)testThat_messageCanSendArgumentString
{
    // given
    NSString *address = @"/thump";
    NSArray<id> *arguments = @[@"thump"];
    NSString *typeTagString = @",s";
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];

    // when
    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:address arguments:arguments];
    [self.testClient sendPacket:message];

    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:2.0];
    XCTAssert(result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address);

    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil(message);
    XCTAssertNotNil(messageReceived);
    XCTAssertNil(message.userData);
    XCTAssertNil(messageReceived.userData);
    XCTAssertEqualObjects(message.addressPattern, address);
    XCTAssertEqualObjects(messageReceived.addressPattern, address);
    XCTAssertEqualObjects(message.typeTagString, typeTagString);
    XCTAssertEqualObjects(messageReceived.typeTagString, typeTagString);
    XCTAssertEqual(message.arguments.count, arguments.count);
    XCTAssertEqual(messageReceived.arguments.count, arguments.count);
    for (NSUInteger i = 0; i < arguments.count; i++)
    {
        id arg = arguments[i];
        XCTAssertEqualObjects(messageReceived.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg);
    }
}

- (void)testThat_messageCanSendArgumentBlob
{
    // given
    NSString *address = @"/thump";
    NSArray<id> *arguments = @[[@"thump" dataUsingEncoding:NSUTF8StringEncoding]];
    NSString *typeTagString = @",b";
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];

    // when
    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:address arguments:arguments];
    [self.testClient sendPacket:message];

    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:2.0];
    XCTAssert(result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address);

    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil(message);
    XCTAssertNotNil(messageReceived);
    XCTAssertNil(message.userData);
    XCTAssertNil(messageReceived.userData);
    XCTAssertEqualObjects(message.addressPattern, address);
    XCTAssertEqualObjects(messageReceived.addressPattern, address);
    XCTAssertEqualObjects(message.typeTagString, typeTagString);
    XCTAssertEqualObjects(messageReceived.typeTagString, typeTagString);
    XCTAssertEqual(message.arguments.count, arguments.count);
    XCTAssertEqual(messageReceived.arguments.count, arguments.count);
    for (NSUInteger i = 0; i < arguments.count; i++)
    {
        id arg = arguments[i];
        XCTAssertEqualObjects(messageReceived.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg);
    }
}

- (void)testThat_messageCanSendArgumentInteger
{
    // given
    NSString *address = @"/thump";
    NSArray<id> *arguments = @[@(INT32_MAX)];
    NSString *typeTagString = @",i";
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];

    // when
    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:address arguments:arguments];
    [self.testClient sendPacket:message];

    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:2.0];
    XCTAssert(result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address);

    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil(message);
    XCTAssertNotNil(messageReceived);
    XCTAssertNil(message.userData);
    XCTAssertNil(messageReceived.userData);
    XCTAssertEqualObjects(message.addressPattern, address);
    XCTAssertEqualObjects(messageReceived.addressPattern, address);
    XCTAssertEqualObjects(message.typeTagString, typeTagString);
    XCTAssertEqualObjects(messageReceived.typeTagString, typeTagString);
    XCTAssertEqual(message.arguments.count, arguments.count);
    XCTAssertEqual(messageReceived.arguments.count, arguments.count);
    for (NSUInteger i = 0; i < arguments.count; i++)
    {
        id arg = arguments[i];
        XCTAssertEqualObjects(messageReceived.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg);
    }
}

- (void)testThat_messageCanSendArgumentFloat
{
    // given
    NSString *address = @"/thump";
    NSArray<id> *arguments = @[@(FLT_MAX)];
    NSString *typeTagString = @",f";
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];

    // when
    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:address arguments:arguments];
    [self.testClient sendPacket:message];

    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:2.0];
    XCTAssert(result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address);

    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil(message);
    XCTAssertNotNil(messageReceived);
    XCTAssertNil(message.userData);
    XCTAssertNil(messageReceived.userData);
    XCTAssertEqualObjects(message.addressPattern, address);
    XCTAssertEqualObjects(messageReceived.addressPattern, address);
    XCTAssertEqualObjects(message.typeTagString, typeTagString);
    XCTAssertEqualObjects(messageReceived.typeTagString, typeTagString);
    XCTAssertEqual(message.arguments.count, arguments.count);
    XCTAssertEqual(messageReceived.arguments.count, arguments.count);
    for (NSUInteger i = 0; i < arguments.count; i++)
    {
        id arg = arguments[i];
        XCTAssertEqualObjects(messageReceived.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg);
    }
}

- (void)testThat_messageCanSendArgumentTrue
{
    // given
    NSString *address = @"/thump";
    NSArray<id> *arguments = @[[F53OSCValue oscTrue]];
    NSString *typeTagString = @",T";
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];

    // when
    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:address arguments:arguments];
    [self.testClient sendPacket:message];

    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:2.0];
    XCTAssert(result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address);

    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil(message);
    XCTAssertNotNil(messageReceived);
    XCTAssertNil(message.userData);
    XCTAssertNil(messageReceived.userData);
    XCTAssertEqualObjects(message.addressPattern, address);
    XCTAssertEqualObjects(messageReceived.addressPattern, address);
    XCTAssertEqualObjects(message.typeTagString, typeTagString);
    XCTAssertEqualObjects(messageReceived.typeTagString, typeTagString);
    XCTAssertEqual(message.arguments.count, arguments.count);
    XCTAssertEqual(messageReceived.arguments.count, arguments.count);
    for (NSUInteger i = 0; i < arguments.count; i++)
    {
        id arg = arguments[i];
        XCTAssertEqualObjects(messageReceived.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg);
    }
}

- (void)testThat_messageCanSendArgumentFalse
{
    // given
    NSString *address = @"/thump";
    NSArray<id> *arguments = @[[F53OSCValue oscFalse]];
    NSString *typeTagString = @",F";
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];

    // when
    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:address arguments:arguments];
    [self.testClient sendPacket:message];

    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:2.0];
    XCTAssert(result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address);

    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil(message);
    XCTAssertNotNil(messageReceived);
    XCTAssertNil(message.userData);
    XCTAssertNil(messageReceived.userData);
    XCTAssertEqualObjects(message.addressPattern, address);
    XCTAssertEqualObjects(messageReceived.addressPattern, address);
    XCTAssertEqualObjects(message.typeTagString, typeTagString);
    XCTAssertEqualObjects(messageReceived.typeTagString, typeTagString);
    XCTAssertEqual(message.arguments.count, arguments.count);
    XCTAssertEqual(messageReceived.arguments.count, arguments.count);
    for (NSUInteger i = 0; i < arguments.count; i++)
    {
        id arg = arguments[i];
        XCTAssertEqualObjects(messageReceived.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg);
    }
}

- (void)testThat_messageCanSendArgumentNull
{
    // given
    NSString *address = @"/thump";
    NSArray<id> *arguments = @[[F53OSCValue oscNull]];
    NSString *typeTagString = @",N";
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];

    // when
    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:address arguments:arguments];
    [self.testClient sendPacket:message];

    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:2.0];
    XCTAssert(result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address);

    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil(message);
    XCTAssertNotNil(messageReceived);
    XCTAssertNil(message.userData);
    XCTAssertNil(messageReceived.userData);
    XCTAssertEqualObjects(message.addressPattern, address);
    XCTAssertEqualObjects(messageReceived.addressPattern, address);
    XCTAssertEqualObjects(message.typeTagString, typeTagString);
    XCTAssertEqualObjects(messageReceived.typeTagString, typeTagString);
    XCTAssertEqual(message.arguments.count, arguments.count);
    XCTAssertEqual(messageReceived.arguments.count, arguments.count);
    for (NSUInteger i = 0; i < arguments.count; i++)
    {
        id arg = arguments[i];
        XCTAssertEqualObjects(messageReceived.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg);
    }
}

- (void)testThat_messageCanSendArgumentImpluse
{
    // given
    NSString *address = @"/thump";
    NSArray<id> *arguments = @[[F53OSCValue oscImpulse]];
    NSString *typeTagString = @",I";
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];

    // when
    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:address arguments:arguments];
    [self.testClient sendPacket:message];

    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:2.0];
    XCTAssert(result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address);

    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil(message);
    XCTAssertNotNil(messageReceived);
    XCTAssertNil(message.userData);
    XCTAssertNil(messageReceived.userData);
    XCTAssertEqualObjects(message.addressPattern, address);
    XCTAssertEqualObjects(messageReceived.addressPattern, address);
    XCTAssertEqualObjects(message.typeTagString, typeTagString);
    XCTAssertEqualObjects(messageReceived.typeTagString, typeTagString);
    XCTAssertEqual(message.arguments.count, arguments.count);
    XCTAssertEqual(messageReceived.arguments.count, arguments.count);
    for (NSUInteger i = 0; i < arguments.count; i++)
    {
        id arg = arguments[i];
        XCTAssertEqualObjects(messageReceived.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg);
    }
}

- (void)testThat_messageCanSendQSCAddressOnly
{
    // given
    NSString *address = @"/thump";
    NSString *typeTagString = @",";
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];

    // when
    F53OSCMessage *message = [F53OSCMessage messageWithString:address locale:nil];
    [self.testClient sendPacket:message];

    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:2.0];
    XCTAssert(result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address);

    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil(message);
    XCTAssertNotNil(messageReceived);
    XCTAssertNil(message.userData);
    XCTAssertNil(messageReceived.userData);
    XCTAssertEqualObjects(message.addressPattern, address);
    XCTAssertEqualObjects(messageReceived.addressPattern, address);
    XCTAssertEqualObjects(message.typeTagString, typeTagString);
    XCTAssertEqualObjects(messageReceived.typeTagString, typeTagString);
    XCTAssertEqual(message.arguments.count, 0);
    XCTAssertEqual(messageReceived.arguments.count, 0);
}

- (void)testThat_messageCanSendQSCArgumentString
{
    // given
    NSString *address = @"/thump";
    NSArray<id> *arguments = @[@"\"thump\""];
    NSString *typeTagString = @",s";
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];

    // when
    NSString *qsc = [NSString stringWithFormat:@"%@ %@", address, [arguments componentsJoinedByString:@" "]];
    F53OSCMessage *message = [F53OSCMessage messageWithString:qsc locale:nil];
    [self.testClient sendPacket:message];

    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:2.0];
    XCTAssert(result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address);

    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil(message);
    XCTAssertNotNil(messageReceived);
    XCTAssertNil(message.userData);
    XCTAssertNil(messageReceived.userData);
    XCTAssertEqualObjects(message.addressPattern, address);
    XCTAssertEqualObjects(messageReceived.addressPattern, address);
    XCTAssertEqualObjects(message.typeTagString, typeTagString);
    XCTAssertEqualObjects(messageReceived.typeTagString, typeTagString);

    NSUInteger argIndex = 0;
    for (NSUInteger t = 0; t < messageReceived.typeTagString.length; t++)
    {
        NSString *typeTag = [messageReceived.typeTagString substringWithRange:NSMakeRange(t, 1)];
        if ([typeTag isEqualToString:@","])
            continue;

        NSString *argStr = arguments[argIndex];
        id arg = [self oscMessageArgumentFromString:argStr typeTag:typeTag];
        XCTAssertEqualObjects(messageReceived.arguments[argIndex], arg, @"arg index %ld not equal - %@", (unsigned long)argIndex, arg);

        argIndex++;
    }
}

- (void)testThat_messageCanSendQSCArgumentBlob
{
    // given
    NSString *address = @"/thump";
    NSArray<id> *arguments = @[[NSString stringWithFormat:@"#blob%@", [[@"thump" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0]]];
    NSString *typeTagString = @",b";
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];

    // when
    NSString *qsc = [NSString stringWithFormat:@"%@ %@", address, [arguments componentsJoinedByString:@" "]];
    F53OSCMessage *message = [F53OSCMessage messageWithString:qsc locale:nil];
    [self.testClient sendPacket:message];

    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:2.0];
    XCTAssert(result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address);

    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil(message);
    XCTAssertNotNil(messageReceived);
    XCTAssertNil(message.userData);
    XCTAssertNil(messageReceived.userData);
    XCTAssertEqualObjects(message.addressPattern, address);
    XCTAssertEqualObjects(messageReceived.addressPattern, address);
    XCTAssertEqualObjects(message.typeTagString, typeTagString);
    XCTAssertEqualObjects(messageReceived.typeTagString, typeTagString);

    NSUInteger argIndex = 0;
    for (NSUInteger t = 0; t < messageReceived.typeTagString.length; t++)
    {
        NSString *typeTag = [messageReceived.typeTagString substringWithRange:NSMakeRange(t, 1)];
        if ([typeTag isEqualToString:@","])
            continue;

        NSString *argStr = arguments[argIndex];
        id arg = [self oscMessageArgumentFromString:argStr typeTag:typeTag];
        XCTAssertEqualObjects(messageReceived.arguments[argIndex], arg, @"arg index %ld not equal - %@", (unsigned long)argIndex, arg);

        argIndex++;
    }
}

- (void)testThat_messageCanSendQSCArgumentInteger
{
    // given
    NSString *address = @"/thump";
    NSArray<id> *arguments = @[[NSString stringWithFormat:@"%d", INT32_MAX]];
    NSString *typeTagString = @",i";
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];

    // when
    NSString *qsc = [NSString stringWithFormat:@"%@ %@", address, [arguments componentsJoinedByString:@" "]];
    F53OSCMessage *message = [F53OSCMessage messageWithString:qsc locale:nil];
    [self.testClient sendPacket:message];

    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:2.0];
    XCTAssert(result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address);

    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil(message);
    XCTAssertNotNil(messageReceived);
    XCTAssertNil(message.userData);
    XCTAssertNil(messageReceived.userData);
    XCTAssertEqualObjects(message.addressPattern, address);
    XCTAssertEqualObjects(messageReceived.addressPattern, address);
    XCTAssertEqualObjects(message.typeTagString, typeTagString);
    XCTAssertEqualObjects(messageReceived.typeTagString, typeTagString);

    NSUInteger argIndex = 0;
    for (NSUInteger t = 0; t < messageReceived.typeTagString.length; t++)
    {
        NSString *typeTag = [messageReceived.typeTagString substringWithRange:NSMakeRange(t, 1)];
        if ([typeTag isEqualToString:@","])
            continue;

        NSString *argStr = arguments[argIndex];
        id arg = [self oscMessageArgumentFromString:argStr typeTag:typeTag];
        XCTAssertEqualObjects(messageReceived.arguments[argIndex], arg, @"arg index %ld not equal - %@", (unsigned long)argIndex, arg);

        argIndex++;
    }
}

- (void)testThat_messageCanSendQSCArgumentFloat
{
    // given
    NSString *address = @"/thump";
    NSArray<id> *arguments = @[[NSString stringWithFormat:@"%F", FLT_MAX]];
    NSString *typeTagString = @",f";
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];

    // when
    NSString *qsc = [NSString stringWithFormat:@"%@ %@", address, [arguments componentsJoinedByString:@" "]];
    F53OSCMessage *message = [F53OSCMessage messageWithString:qsc locale:nil];
    [self.testClient sendPacket:message];

    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:2.0];
    XCTAssert(result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address);

    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil(message);
    XCTAssertNotNil(messageReceived);
    XCTAssertNil(message.userData);
    XCTAssertNil(messageReceived.userData);
    XCTAssertEqualObjects(message.addressPattern, address);
    XCTAssertEqualObjects(messageReceived.addressPattern, address);
    XCTAssertEqualObjects(message.typeTagString, typeTagString);
    XCTAssertEqualObjects(messageReceived.typeTagString, typeTagString);

    NSUInteger argIndex = 0;
    for (NSUInteger t = 0; t < messageReceived.typeTagString.length; t++)
    {
        NSString *typeTag = [messageReceived.typeTagString substringWithRange:NSMakeRange(t, 1)];
        if ([typeTag isEqualToString:@","])
            continue;

        NSString *argStr = arguments[argIndex];
        id arg = [self oscMessageArgumentFromString:argStr typeTag:typeTag];
        XCTAssertEqualObjects(messageReceived.arguments[argIndex], arg, @"arg index %ld not equal - %@", (unsigned long)argIndex, arg);

        argIndex++;
    }
}

- (void)testThat_messageCanSendQSCArgumentTrue
{
    // given
    NSString *address = @"/thump";
    NSArray<id> *arguments = @[@"\\T"];
    NSString *typeTagString = @",T";
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];

    // when
    NSString *qsc = [NSString stringWithFormat:@"%@ %@", address, [arguments componentsJoinedByString:@" "]];
    F53OSCMessage *message = [F53OSCMessage messageWithString:qsc locale:nil];
    [self.testClient sendPacket:message];

    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:2.0];
    XCTAssert(result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address);

    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil(message);
    XCTAssertNotNil(messageReceived);
    XCTAssertNil(message.userData);
    XCTAssertNil(messageReceived.userData);
    XCTAssertEqualObjects(message.addressPattern, address);
    XCTAssertEqualObjects(messageReceived.addressPattern, address);
    XCTAssertEqualObjects(message.typeTagString, typeTagString);
    XCTAssertEqualObjects(messageReceived.typeTagString, typeTagString);

    NSUInteger argIndex = 0;
    for (NSUInteger t = 0; t < messageReceived.typeTagString.length; t++)
    {
        NSString *typeTag = [messageReceived.typeTagString substringWithRange:NSMakeRange(t, 1)];
        if ([typeTag isEqualToString:@","])
            continue;

        NSString *argStr = arguments[argIndex];
        id arg = [self oscMessageArgumentFromString:argStr typeTag:typeTag];
        XCTAssertEqualObjects(messageReceived.arguments[argIndex], arg, @"arg index %ld not equal - %@", (unsigned long)argIndex, arg);

        argIndex++;
    }
}

- (void)testThat_messageCanSendQSCArgumentFalse
{
    // given
    NSString *address = @"/thump";
    NSArray<id> *arguments = @[@"\\F"];
    NSString *typeTagString = @",F";
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];

    // when
    NSString *qsc = [NSString stringWithFormat:@"%@ %@", address, [arguments componentsJoinedByString:@" "]];
    F53OSCMessage *message = [F53OSCMessage messageWithString:qsc locale:nil];
    [self.testClient sendPacket:message];

    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:2.0];
    XCTAssert(result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address);

    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil(message);
    XCTAssertNotNil(messageReceived);
    XCTAssertNil(message.userData);
    XCTAssertNil(messageReceived.userData);
    XCTAssertEqualObjects(message.addressPattern, address);
    XCTAssertEqualObjects(messageReceived.addressPattern, address);
    XCTAssertEqualObjects(message.typeTagString, typeTagString);
    XCTAssertEqualObjects(messageReceived.typeTagString, typeTagString);

    NSUInteger argIndex = 0;
    for (NSUInteger t = 0; t < messageReceived.typeTagString.length; t++)
    {
        NSString *typeTag = [messageReceived.typeTagString substringWithRange:NSMakeRange(t, 1)];
        if ([typeTag isEqualToString:@","])
            continue;

        NSString *argStr = arguments[argIndex];
        id arg = [self oscMessageArgumentFromString:argStr typeTag:typeTag];
        XCTAssertEqualObjects(messageReceived.arguments[argIndex], arg, @"arg index %ld not equal - %@", (unsigned long)argIndex, arg);

        argIndex++;
    }
}

- (void)testThat_messageCanSendQSCArgumentNull
{
    // given
    NSString *address = @"/thump";
    NSArray<id> *arguments = @[@"\\N"];
    NSString *typeTagString = @",N";
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];

    // when
    NSString *qsc = [NSString stringWithFormat:@"%@ %@", address, [arguments componentsJoinedByString:@" "]];
    F53OSCMessage *message = [F53OSCMessage messageWithString:qsc locale:nil];
    [self.testClient sendPacket:message];

    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:2.0];
    XCTAssert(result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address);

    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil(message);
    XCTAssertNotNil(messageReceived);
    XCTAssertNil(message.userData);
    XCTAssertNil(messageReceived.userData);
    XCTAssertEqualObjects(message.addressPattern, address);
    XCTAssertEqualObjects(messageReceived.addressPattern, address);
    XCTAssertEqualObjects(message.typeTagString, typeTagString);
    XCTAssertEqualObjects(messageReceived.typeTagString, typeTagString);

    NSUInteger argIndex = 0;
    for (NSUInteger t = 0; t < messageReceived.typeTagString.length; t++)
    {
        NSString *typeTag = [messageReceived.typeTagString substringWithRange:NSMakeRange(t, 1)];
        if ([typeTag isEqualToString:@","])
            continue;

        NSString *argStr = arguments[argIndex];
        id arg = [self oscMessageArgumentFromString:argStr typeTag:typeTag];
        XCTAssertEqualObjects(messageReceived.arguments[argIndex], arg, @"arg index %ld not equal - %@", (unsigned long)argIndex, arg);

        argIndex++;
    }
}

- (void)testThat_messageCanSendQSCArgumentImpluse
{
    // given
    NSString *address = @"/thump";
    NSArray<id> *arguments = @[@"\\I"];
    NSString *typeTagString = @",I";
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];

    // when
    NSString *qsc = [NSString stringWithFormat:@"%@ %@", address, [arguments componentsJoinedByString:@" "]];
    F53OSCMessage *message = [F53OSCMessage messageWithString:qsc locale:nil];
    [self.testClient sendPacket:message];

    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:2.0];
    XCTAssert(result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address);

    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil(message);
    XCTAssertNotNil(messageReceived);
    XCTAssertNil(message.userData);
    XCTAssertNil(messageReceived.userData);
    XCTAssertEqualObjects(message.addressPattern, address);
    XCTAssertEqualObjects(messageReceived.addressPattern, address);
    XCTAssertEqualObjects(message.typeTagString, typeTagString);
    XCTAssertEqualObjects(messageReceived.typeTagString, typeTagString);

    NSUInteger argIndex = 0;
    for (NSUInteger t = 0; t < messageReceived.typeTagString.length; t++)
    {
        NSString *typeTag = [messageReceived.typeTagString substringWithRange:NSMakeRange(t, 1)];
        if ([typeTag isEqualToString:@","])
            continue;

        NSString *argStr = arguments[argIndex];
        id arg = [self oscMessageArgumentFromString:argStr typeTag:typeTag];
        XCTAssertEqualObjects(messageReceived.arguments[argIndex], arg, @"arg index %ld not equal - %@", (unsigned long)argIndex, arg);

        argIndex++;
    }
}

- (void)testThat_messageCanSendMultipleArguments
{
    // given
    NSString *address = @"/thump";
    NSArray<id> *arguments = @[
        @"thump",
        [@"thump" dataUsingEncoding:NSUTF8StringEncoding],
        @(INT32_MAX),
        @(FLT_MAX),
        [F53OSCValue oscTrue],
        [F53OSCValue oscFalse],
        [F53OSCValue oscNull],
        [F53OSCValue oscImpulse],
    ];
    NSString *typeTagString = @",sbifTFNI";
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];

    // when
    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:address arguments:arguments];
    [self.testClient sendPacket:message];

    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:2.0];
    XCTAssert(result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address);

    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil(message);
    XCTAssertNotNil(messageReceived);
    XCTAssertNil(message.userData);
    XCTAssertNil(messageReceived.userData);
    XCTAssertEqualObjects(message.addressPattern, address);
    XCTAssertEqualObjects(messageReceived.addressPattern, address);
    XCTAssertEqualObjects(message.typeTagString, typeTagString);
    XCTAssertEqualObjects(messageReceived.typeTagString, typeTagString);
    XCTAssertEqual(message.arguments.count, arguments.count);
    XCTAssertEqual(messageReceived.arguments.count, arguments.count);
    for (NSUInteger i = 0; i < arguments.count; i++)
    {
        id arg = arguments[i];
        XCTAssertEqualObjects(messageReceived.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg);
    }
}

- (void)testThat_messageCanSendMultipleQSCArguments
{
    // given
    NSString *address = @"/thump";
    NSArray<id> *arguments = @[
        @"thump",
        [NSString stringWithFormat:@"#blob%@", [[@"thump" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0]],
        [NSString stringWithFormat:@"%d", INT32_MAX],
        [NSString stringWithFormat:@"%F", FLT_MAX],
        @"\\T",
        @"\\F",
        @"\\N",
        @"\\I",
    ];
    NSString *typeTagString = @",sbifTFNI";
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];

    // when
    NSString *qsc = [NSString stringWithFormat:@"%@ %@", address, [arguments componentsJoinedByString:@" "]];
    F53OSCMessage *message = [F53OSCMessage messageWithString:qsc locale:nil];
    [self.testClient sendPacket:message];

    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:2.0];
    XCTAssert(result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address);

    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil(message);
    XCTAssertNotNil(messageReceived);
    XCTAssertNil(message.userData);
    XCTAssertNil(messageReceived.userData);
    XCTAssertEqualObjects(message.addressPattern, address);
    XCTAssertEqualObjects(messageReceived.addressPattern, address);
    XCTAssertEqualObjects(message.typeTagString, typeTagString);
    XCTAssertEqualObjects(messageReceived.typeTagString, typeTagString);

    NSUInteger argIndex = 0;
    for (NSUInteger t = 0; t < messageReceived.typeTagString.length; t++)
    {
        NSString *typeTag = [messageReceived.typeTagString substringWithRange:NSMakeRange(t, 1)];
        if ([typeTag isEqualToString:@","])
            continue;

        NSString *argStr = arguments[argIndex];
        id arg = [self oscMessageArgumentFromString:argStr typeTag:typeTag];
        XCTAssertEqualObjects(messageReceived.arguments[argIndex], arg, @"arg index %ld not equal - %@", (unsigned long)argIndex, arg);

        argIndex++;
    }
}

- (void)testThat_messageCanSendMultipleStringArguments
{
    // given
    NSString *address = @"/thump";
    NSArray<id> *arguments = @[
        @"thumpthumpthumpy",
        @"thumpthumpthump",
        @"thumpthumpthum",
        @"thumpthumpthu",
        @"thumpthumpth",
        @"thumpthumpt",
        @"thumpthump",
        @"thumpthum",
        @"thumpthu",
        @"thumpth",
        @"thumpt",
        @"thump",
        @"thum",
        @"thu",
        @"th",
        @"t",
    ];
    NSString *typeTagString = @",ssssssssssssssss";
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];

    // when
    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:address arguments:arguments];
    [self.testClient sendPacket:message];

    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:2.0];
    XCTAssert(result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address);

    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil(message);
    XCTAssertNotNil(messageReceived);
    XCTAssertNil(message.userData);
    XCTAssertNil(messageReceived.userData);
    XCTAssertEqualObjects(message.addressPattern, address);
    XCTAssertEqualObjects(messageReceived.addressPattern, address);
    XCTAssertEqualObjects(message.typeTagString, typeTagString);
    XCTAssertEqualObjects(messageReceived.typeTagString, typeTagString);
    XCTAssertEqual(message.arguments.count, arguments.count);
    XCTAssertEqual(messageReceived.arguments.count, arguments.count);
    for (NSUInteger i = 0; i < arguments.count; i++)
    {
        id arg = arguments[i];
        XCTAssertEqualObjects(messageReceived.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg);
    }
}

- (void)testThat_messageCanSendMultipleQSCStringArguments
{
    // given
    NSString *address = @"/thump";
    NSArray<id> *arguments = @[
        @"thumpthumpthumpy",
        @"thumpthumpthump",
        @"thumpthumpthum",
        @"thumpthumpthu",
        @"thumpthumpth",
        @"thumpthumpt",
        @"thumpthump",
        @"thumpthum",
        @"thumpthu",
        @"thumpth",
        @"thumpt",
        @"thump",
        @"thum",
        @"thu",
        @"th",
        @"t",
    ];
    NSString *typeTagString = @",ssssssssssssssss";
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];

    // when
    NSString *qsc = [NSString stringWithFormat:@"%@ %@", address, [arguments componentsJoinedByString:@" "]];
    F53OSCMessage *message = [F53OSCMessage messageWithString:qsc locale:nil];
    [self.testClient sendPacket:message];

    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:2.0];
    XCTAssert(result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address);

    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil(message);
    XCTAssertNotNil(messageReceived);
    XCTAssertNil(message.userData);
    XCTAssertNil(messageReceived.userData);
    XCTAssertEqualObjects(message.addressPattern, address);
    XCTAssertEqualObjects(messageReceived.addressPattern, address);
    XCTAssertEqualObjects(message.typeTagString, typeTagString);
    XCTAssertEqualObjects(messageReceived.typeTagString, typeTagString);

    NSUInteger argIndex = 0;
    for (NSUInteger t = 0; t < messageReceived.typeTagString.length; t++)
    {
        NSString *typeTag = [messageReceived.typeTagString substringWithRange:NSMakeRange(t, 1)];
        if ([typeTag isEqualToString:@","])
            continue;

        NSString *argStr = arguments[argIndex];
        id arg = [self oscMessageArgumentFromString:argStr typeTag:typeTag];
        XCTAssertEqualObjects(messageReceived.arguments[argIndex], arg, @"arg index %ld not equal - %@", (unsigned long)argIndex, arg);

        argIndex++;
    }
}

- (void)testThat_messageCanSendMultipleBlobArguments
{
    // given
    NSString *address = @"/thump";
    NSArray<id> *arguments = @[
        [@"thumpthumpthumpy" dataUsingEncoding:NSUTF8StringEncoding],
        [@"thumpthumpthump" dataUsingEncoding:NSUTF8StringEncoding],
        [@"thumpthumpthum" dataUsingEncoding:NSUTF8StringEncoding],
        [@"thumpthumpthu" dataUsingEncoding:NSUTF8StringEncoding],
        [@"thumpthumpth" dataUsingEncoding:NSUTF8StringEncoding],
        [@"thumpthumpt" dataUsingEncoding:NSUTF8StringEncoding],
        [@"thumpthump" dataUsingEncoding:NSUTF8StringEncoding],
        [@"thumpthum" dataUsingEncoding:NSUTF8StringEncoding],
        [@"thumpthu" dataUsingEncoding:NSUTF8StringEncoding],
        [@"thumpth" dataUsingEncoding:NSUTF8StringEncoding],
        [@"thumpt" dataUsingEncoding:NSUTF8StringEncoding],
        [@"thump" dataUsingEncoding:NSUTF8StringEncoding],
        [@"thum" dataUsingEncoding:NSUTF8StringEncoding],
        [@"thu" dataUsingEncoding:NSUTF8StringEncoding],
        [@"th" dataUsingEncoding:NSUTF8StringEncoding],
        [@"t" dataUsingEncoding:NSUTF8StringEncoding],
    ];
    NSString *typeTagString = @",bbbbbbbbbbbbbbbb";
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];

    // when
    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:address arguments:arguments];
    [self.testClient sendPacket:message];

    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:2.0];
    XCTAssert(result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address);

    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil(message);
    XCTAssertNotNil(messageReceived);
    XCTAssertNil(message.userData);
    XCTAssertNil(messageReceived.userData);
    XCTAssertEqualObjects(message.addressPattern, address);
    XCTAssertEqualObjects(messageReceived.addressPattern, address);
    XCTAssertEqualObjects(message.typeTagString, typeTagString);
    XCTAssertEqualObjects(messageReceived.typeTagString, typeTagString);
    XCTAssertEqual(message.arguments.count, arguments.count);
    XCTAssertEqual(messageReceived.arguments.count, arguments.count);
    for (NSUInteger i = 0; i < arguments.count; i++)
    {
        id arg = arguments[i];
        XCTAssertEqualObjects(messageReceived.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg);
    }
}

- (void)testThat_messageCanSendMultipleQSCBlobArguments
{
    // given
    NSString *address = @"/thump";
    NSArray<id> *arguments = @[
        [NSString stringWithFormat:@"#blob%@", [[@"thumpthumpthumpy" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0]],
        [NSString stringWithFormat:@"#blob%@", [[@"thumpthumpthump" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0]],
        [NSString stringWithFormat:@"#blob%@", [[@"thumpthumpthum" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0]],
        [NSString stringWithFormat:@"#blob%@", [[@"thumpthumpthu" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0]],
        [NSString stringWithFormat:@"#blob%@", [[@"thumpthumpth" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0]],
        [NSString stringWithFormat:@"#blob%@", [[@"thumpthumpt" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0]],
        [NSString stringWithFormat:@"#blob%@", [[@"thumpthump" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0]],
        [NSString stringWithFormat:@"#blob%@", [[@"thumpthum" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0]],
        [NSString stringWithFormat:@"#blob%@", [[@"thumpthu" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0]],
        [NSString stringWithFormat:@"#blob%@", [[@"thumpth" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0]],
        [NSString stringWithFormat:@"#blob%@", [[@"thumpt" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0]],
        [NSString stringWithFormat:@"#blob%@", [[@"thump" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0]],
        [NSString stringWithFormat:@"#blob%@", [[@"thum" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0]],
        [NSString stringWithFormat:@"#blob%@", [[@"thu" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0]],
        [NSString stringWithFormat:@"#blob%@", [[@"th" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0]],
        [NSString stringWithFormat:@"#blob%@", [[@"t" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0]],
    ];
    NSString *typeTagString = @",bbbbbbbbbbbbbbbb";
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];

    // when
    NSString *qsc = [NSString stringWithFormat:@"%@ %@", address, [arguments componentsJoinedByString:@" "]];
    F53OSCMessage *message = [F53OSCMessage messageWithString:qsc locale:nil];
    [self.testClient sendPacket:message];

    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:2.0];
    XCTAssert(result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address);

    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil(message);
    XCTAssertNotNil(messageReceived);
    XCTAssertNil(message.userData);
    XCTAssertNil(messageReceived.userData);
    XCTAssertEqualObjects(message.addressPattern, address);
    XCTAssertEqualObjects(messageReceived.addressPattern, address);
    XCTAssertEqualObjects(message.typeTagString, typeTagString);
    XCTAssertEqualObjects(messageReceived.typeTagString, typeTagString);
    XCTAssertEqual(message.arguments.count, arguments.count);
    XCTAssertEqual(messageReceived.arguments.count, arguments.count);
    for (NSUInteger i = 0; i < arguments.count; i++)
    {
        NSUInteger argIndex = 0;
        for (NSUInteger t = 0; t < messageReceived.typeTagString.length; t++)
        {
            NSString *typeTag = [messageReceived.typeTagString substringWithRange:NSMakeRange(t, 1)];
            if ([typeTag isEqualToString:@","])
                continue;

            NSString *argStr = arguments[argIndex];
            id arg = [self oscMessageArgumentFromString:argStr typeTag:typeTag];
            XCTAssertEqualObjects(messageReceived.arguments[argIndex], arg, @"arg index %ld not equal - %@", (unsigned long)argIndex, arg);

            argIndex++;
        }
    }
}

- (void)testThat_messageCanSendOSCBundle
{
    // given
    F53OSCTimeTag *timeTag = [F53OSCTimeTag immediateTimeTag];

    NSString *address1 = @"/thump";
    NSArray<id> *arguments1 = @[@"thump"];
    NSString *typeTagString1 = @",s";
    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:address1 arguments:arguments1];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address1];
    [self.messageExpectations addObject:expectation];

    NSArray<NSData *> *elements = @[message.packetData];

    // when
    F53OSCBundle *bundle = [F53OSCBundle bundleWithTimeTag:timeTag elements:elements];
    [self.testClient sendPacket:bundle];

    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:2.0];
    XCTAssert(result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", self.name);

    XCTAssertNotNil(bundle);
    XCTAssertEqualObjects(bundle.timeTag, timeTag);
    XCTAssertEqual(bundle.elements.count, elements.count);
    XCTAssertEqualObjects(bundle.elements, elements);

    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil(message);
    XCTAssertNotNil(messageReceived);
    XCTAssertNil(message.userData);
    XCTAssertNil(messageReceived.userData);
    XCTAssertEqualObjects(message.addressPattern, address1);
    XCTAssertEqualObjects(messageReceived.addressPattern, address1);
    XCTAssertEqualObjects(message.typeTagString, typeTagString1);
    XCTAssertEqualObjects(messageReceived.typeTagString, typeTagString1);
    XCTAssertEqual(message.arguments.count, arguments1.count);
    XCTAssertEqual(messageReceived.arguments.count, arguments1.count);
    for (NSUInteger i = 0; i < arguments1.count; i++)
    {
        id arg = arguments1[i];
        XCTAssertEqualObjects(messageReceived.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg);
    }
}

- (void)testThat_messageCanSendOSCBundleMultipleArguments
{
    // given
    F53OSCTimeTag *timeTag = [F53OSCTimeTag immediateTimeTag];

    NSString *address1 = @"/thump";
    NSArray<id> *arguments1 = @[@"thump"];
    NSString *typeTagString1 = @",s";
    F53OSCMessage *message1 = [F53OSCMessage messageWithAddressPattern:address1 arguments:arguments1];
    XCTestExpectation *expectation1 = [[XCTestExpectation alloc] initWithDescription:address1];
    [self.messageExpectations addObject:expectation1];

    NSString *address2 = @"/thumpthump";
    NSArray<id> *arguments2 = @[@123];
    NSString *typeTagString2 = @",i";
    F53OSCMessage *message2 = [F53OSCMessage messageWithAddressPattern:address2 arguments:arguments2];
    XCTestExpectation *expectation2 = [[XCTestExpectation alloc] initWithDescription:address2];
    [self.messageExpectations addObject:expectation2];

    NSArray<NSData *> *elements = @[message1.packetData, message2.packetData];

    // when
    F53OSCBundle *bundle = [F53OSCBundle bundleWithTimeTag:timeTag elements:elements];
    [self.testClient sendPacket:bundle];

    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation1, expectation2] timeout:5.0];
    XCTAssert(result == XCTWaiterResultCompleted, @"OSC messages failed to arrive - %@", self.name);

    XCTAssertNotNil(bundle);
    XCTAssertEqualObjects(bundle.timeTag, timeTag);
    XCTAssertEqual(bundle.elements.count, elements.count);
    XCTAssertEqualObjects(bundle.elements, elements);

    F53OSCMessage *message1Received = self.matchedExpectations[expectation1.description];
    XCTAssertNotNil(message1);
    XCTAssertNotNil(message1Received);
    XCTAssertNil(message1.userData);
    XCTAssertNil(message1Received.userData);
    XCTAssertEqualObjects(message1.addressPattern, address1);
    XCTAssertEqualObjects(message1Received.addressPattern, address1);
    XCTAssertEqualObjects(message1.typeTagString, typeTagString1);
    XCTAssertEqualObjects(message1Received.typeTagString, typeTagString1);
    XCTAssertEqual(message1.arguments.count, arguments1.count);
    XCTAssertEqual(message1Received.arguments.count, arguments1.count);
    for (NSUInteger i = 0; i < arguments1.count; i++)
    {
        id arg = arguments1[i];
        XCTAssertEqualObjects(message1Received.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg);
    }

    F53OSCMessage *message2Received = self.matchedExpectations[expectation2.description];
    XCTAssertNotNil(message2);
    XCTAssertNotNil(message2Received);
    XCTAssertNil(message2.userData);
    XCTAssertNil(message2Received.userData);
    XCTAssertEqualObjects(message2.addressPattern, address2);
    XCTAssertEqualObjects(message2Received.addressPattern, address2);
    XCTAssertEqualObjects(message2.typeTagString, typeTagString2);
    XCTAssertEqualObjects(message2Received.typeTagString, typeTagString2);
    XCTAssertEqual(message2.arguments.count, arguments2.count);
    XCTAssertEqual(message2Received.arguments.count, arguments2.count);
    for (NSUInteger i = 0; i < arguments2.count; i++)
    {
        id arg = arguments2[i];
        XCTAssertEqualObjects(message2Received.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg);
    }
}

- (void)testThat_messageCanSendOSCRecursiveBundles
{
    // given
    F53OSCTimeTag *timeTag = [F53OSCTimeTag immediateTimeTag];

    NSString *address1 = @"/thump";
    NSArray<id> *arguments1 = @[@"thump"];
    NSString *typeTagString1 = @",s";
    F53OSCMessage *message1 = [F53OSCMessage messageWithAddressPattern:address1 arguments:arguments1];
    XCTestExpectation *expectation1 = [[XCTestExpectation alloc] initWithDescription:address1];
    [self.messageExpectations addObject:expectation1];

    NSString *address2 = @"/thumpthump";
    NSArray<id> *arguments2 = @[@123];
    NSString *typeTagString2 = @",i";
    F53OSCMessage *message2 = [F53OSCMessage messageWithAddressPattern:address2 arguments:arguments2];
    XCTestExpectation *expectation2 = [[XCTestExpectation alloc] initWithDescription:address2];
    [self.messageExpectations addObject:expectation2];

    NSString *address3 = @"/child/thump";
    NSArray<id> *arguments3 = @[[F53OSCValue oscTrue]];
    NSString *typeTagString3 = @",T";
    F53OSCMessage *message3 = [F53OSCMessage messageWithAddressPattern:address3 arguments:arguments3];
    XCTestExpectation *expectation3 = [[XCTestExpectation alloc] initWithDescription:address3];
    [self.messageExpectations addObject:expectation3];

    NSString *address4 = @"/child/complex/thump";
    NSArray<id> *arguments4 = @[[F53OSCValue oscFalse], [F53OSCValue oscImpulse], [@"thumpthumpthumpy" dataUsingEncoding:NSUTF8StringEncoding], @"thumpthumpthumpy"];
    NSString *typeTagString4 = @",FIbs";
    F53OSCMessage *message4 = [F53OSCMessage messageWithAddressPattern:address4 arguments:arguments4];
    XCTestExpectation *expectation4 = [[XCTestExpectation alloc] initWithDescription:address4];
    [self.messageExpectations addObject:expectation4];

    NSArray<NSData *> *childElements = @[message3.packetData, message4.packetData];
    F53OSCBundle *childBundle = [F53OSCBundle bundleWithTimeTag:timeTag elements:childElements];

    NSArray<NSData *> *elements = @[message1.packetData, childBundle.packetData, message2.packetData];

    // when
    F53OSCBundle *bundle = [F53OSCBundle bundleWithTimeTag:timeTag elements:elements];
    [self.testClient sendPacket:bundle];

    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation1, expectation2, expectation3, expectation4] timeout:5.0];
    XCTAssert(result == XCTWaiterResultCompleted, @"OSC messages failed to arrive - %@", self.name);

    XCTAssertNotNil(childBundle);
    XCTAssertEqualObjects(childBundle.timeTag, timeTag);
    XCTAssertEqual(childBundle.elements.count, childElements.count);
    XCTAssertEqualObjects(childBundle.elements, childElements);

    XCTAssertNotNil(bundle);
    XCTAssertEqualObjects(bundle.timeTag, timeTag);
    XCTAssertEqual(bundle.elements.count, elements.count);
    XCTAssertEqualObjects(bundle.elements, elements);

    F53OSCMessage *message1Received = self.matchedExpectations[expectation1.description];
    XCTAssertNotNil(message1);
    XCTAssertNotNil(message1Received);
    XCTAssertNil(message1.userData);
    XCTAssertNil(message1Received.userData);
    XCTAssertEqualObjects(message1.addressPattern, address1);
    XCTAssertEqualObjects(message1Received.addressPattern, address1);
    XCTAssertEqualObjects(message1.typeTagString, typeTagString1);
    XCTAssertEqualObjects(message1Received.typeTagString, typeTagString1);
    XCTAssertEqual(message1.arguments.count, arguments1.count);
    XCTAssertEqual(message1Received.arguments.count, arguments1.count);
    for (NSUInteger i = 0; i < arguments1.count; i++)
    {
        id arg = arguments1[i];
        XCTAssertEqualObjects(message1Received.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg);
    }

    F53OSCMessage *message2Received = self.matchedExpectations[expectation2.description];
    XCTAssertNotNil(message2);
    XCTAssertNotNil(message2Received);
    XCTAssertNil(message2.userData);
    XCTAssertNil(message2Received.userData);
    XCTAssertEqualObjects(message2.addressPattern, address2);
    XCTAssertEqualObjects(message2Received.addressPattern, address2);
    XCTAssertEqualObjects(message2.typeTagString, typeTagString2);
    XCTAssertEqualObjects(message2Received.typeTagString, typeTagString2);
    XCTAssertEqual(message2.arguments.count, arguments2.count);
    XCTAssertEqual(message2Received.arguments.count, arguments2.count);
    for (NSUInteger i = 0; i < arguments2.count; i++)
    {
        id arg = arguments2[i];
        XCTAssertEqualObjects(message2Received.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg);
    }

    F53OSCMessage *message3Received = self.matchedExpectations[expectation3.description];
    XCTAssertNotNil(message3);
    XCTAssertNotNil(message3Received);
    XCTAssertNil(message3.userData);
    XCTAssertNil(message3Received.userData);
    XCTAssertEqualObjects(message3.addressPattern, address3);
    XCTAssertEqualObjects(message3Received.addressPattern, address3);
    XCTAssertEqualObjects(message3.typeTagString, typeTagString3);
    XCTAssertEqualObjects(message3Received.typeTagString, typeTagString3);
    XCTAssertEqual(message3.arguments.count, arguments3.count);
    XCTAssertEqual(message3Received.arguments.count, arguments3.count);
    for (NSUInteger i = 0; i < arguments3.count; i++)
    {
        id arg = arguments3[i];
        XCTAssertEqualObjects(message3Received.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg);
    }

    F53OSCMessage *message4Received = self.matchedExpectations[expectation4.description];
    XCTAssertNotNil(message4);
    XCTAssertNotNil(message4Received);
    XCTAssertNil(message4.userData);
    XCTAssertNil(message4Received.userData);
    XCTAssertEqualObjects(message4.addressPattern, address4);
    XCTAssertEqualObjects(message4Received.addressPattern, address4);
    XCTAssertEqualObjects(message4.typeTagString, typeTagString4);
    XCTAssertEqualObjects(message4Received.typeTagString, typeTagString4);
    XCTAssertEqual(message4.arguments.count, arguments4.count);
    XCTAssertEqual(message4Received.arguments.count, arguments4.count);
    for (NSUInteger i = 0; i < arguments4.count; i++)
    {
        id arg = arguments4[i];
        XCTAssertEqualObjects(message4Received.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg);
    }
}


#pragma mark - F53OSCPacketDestination

- (void)takeMessage:(nullable F53OSCMessage *)message
{
    // NOTE: F53OSCMessages received without matching XCTestExpectations are discarded

    NSString *description = message.addressPattern;

    XCTestExpectation *foundExpectation = nil;
    for (XCTestExpectation *aMessageExpectation in self.messageExpectations)
    {
        if ([aMessageExpectation.expectationDescription isEqualToString:description] == NO)
            continue;

        foundExpectation = aMessageExpectation;
        break;
    }

    if (foundExpectation)
    {
        self.matchedExpectations[foundExpectation.expectationDescription] = message;
        [self.messageExpectations removeObject:foundExpectation];
        [foundExpectation fulfill];
    }
}


#pragma mark - F53OSCClientDelegate

- (void)clientDidConnect:(F53OSCClient *)client
{
    if (client.isConnected)
        [self.clientConnectExpectation fulfill];
}

@end

NS_ASSUME_NONNULL_END
