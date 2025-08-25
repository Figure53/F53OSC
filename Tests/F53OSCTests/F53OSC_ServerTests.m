//
//  F53OSC_ServerTests.m
//  F53OSC
//
//  Created by Brent Lord on 2/24/20.
//  Copyright (c) 2020-2025 Figure 53, LLC. All rights reserved.
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

#import "F53OSCServer.h"

@class F53OSCEncrypt; // forward declaration of Swift class


NS_ASSUME_NONNULL_BEGIN

@interface F53OSCServer (F53OSC_ServerTestsAccess)
@property (atomic, strong) dispatch_queue_t queue;
@end


#pragma - mark

@interface F53OSC_ServerTests : XCTestCase <F53OSCServerDelegate>
@end

@implementation F53OSC_ServerTests

//- (void) setUp
//{
//    [super setUp];
//
//    // set up
//}

- (NSPredicate *)stringTestPredicateWithOSCPattern:(NSString *)oscPattern
{
    NSPredicate *predicate = [F53OSCServer predicateForAttribute:@"SELF" matchingOSCPattern:oscPattern];
    XCTAssertNotNil(predicate);

    // hack around passing reserved word to `predicateWithFormat:`
    predicate = [NSPredicate predicateWithFormat:[predicate.predicateFormat stringByReplacingOccurrencesOfString:@"#SELF" withString:@"SELF"]];
    XCTAssertNotNil(predicate);

    return predicate;
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

- (void)testThat_serverHasCorrectDefaults
{
    F53OSCServer *server = [[F53OSCServer alloc] init];

    XCTAssertNotNil(server, @"Server should not be nil");
    XCTAssertNil(server.delegate, @"Default delegate should be nil");
    XCTAssertNotNil(server.udpSocket, @"Default udpSocket should not be nil");
    XCTAssertNotNil(server.tcpSocket, @"Default tcpSocket should not be nil");
    XCTAssertEqual(server.port, 0, @"Default port should be 0");
    XCTAssertEqual(server.udpReplyPort, 0, @"Default udpReplyPort should be 0");
    XCTAssertFalse(server.isIPv6Enabled, @"Default IPv6Enabled should be NO");
    XCTAssertNil(server.keyPair, @"Default keyPair should be nil");
}

- (void)testThat_serverWithDelegateHasCorrectDefaults
{
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    XCTAssertNotNil(queue);

    F53OSCServer *server = [[F53OSCServer alloc] initWithDelegateQueue:queue];

    XCTAssertNotNil(server, @"Server should not be nil");
    XCTAssertNil(server.delegate, @"Default delegate should be nil");
    XCTAssertNotNil(server.udpSocket, @"Default udpSocket should not be nil");
    XCTAssertNotNil(server.tcpSocket, @"Default tcpSocket should not be nil");
    XCTAssertEqual(server.port, 0, @"Default port should be 0");
    XCTAssertEqual(server.udpReplyPort, 0, @"Default udpReplyPort should be 0");
    XCTAssertFalse(server.isIPv6Enabled, @"Default IPv6Enabled should be NO");
    XCTAssertNil(server.keyPair, @"Default keyPair should be nil");
}

- (void)testThat_serverCanConfigureProperties
{
    F53OSCServer *server = [[F53OSCServer alloc] init];

    server.delegate = self;
    XCTAssertEqualObjects(server.delegate, self, @"Server delegate should be self");

    server.port = 9999;
    XCTAssertEqual(server.port, 9999, @"Server port should be 9999");

    server.udpReplyPort = 10000;
    XCTAssertEqual(server.udpReplyPort, 10000, @"Server udpReplyPort should be 10000");

    server.IPv6Enabled = YES;
    XCTAssertTrue(server.isIPv6Enabled, @"Server IPv6Enabled should be YES");

    NSData *testKeyPair = [@"test_key_pair_data" dataUsingEncoding:NSUTF8StringEncoding];
    server.keyPair = testKeyPair;
    XCTAssertEqualObjects(server.keyPair, testKeyPair, @"Server keyPair should be %@", testKeyPair);
}

- (void)testThat_serverCannotBeCopied
{
    F53OSCServer *server = [[F53OSCServer alloc] init];

    XCTAssertThrows(server.copy, "Server does not conform to NSCopying");
}

- (void)testThat_serverHandlesIPv6Configuration
{
    F53OSCServer *server = [[F53OSCServer alloc] init];
    server.port = 9506;

    XCTAssertFalse(server.isIPv6Enabled, @"Default IPv6Enabled should be NO");

    server.IPv6Enabled = YES;
    XCTAssertTrue(server.isIPv6Enabled, @"Server IPv6Enabled should be YES");

    // Test that server can still start with IPv6 enabled
    BOOL started = [server startListening];
    XCTAssertTrue(started, @"Server should start listening with IPv6 enabled");

    [server stopListening];
}


#pragma mark - Control message handling tests

- (void)testThat_serverHandlesControlMessageWithValidMessage
{
    F53OSCServer *server = [[F53OSCServer alloc] init];

    // Test with valid control message
    F53OSCMessage *controlMessage = [F53OSCMessage messageWithAddressPattern:@"!/server/control" arguments:@[@"control_arg"]];
    XCTAssertNoThrow([server handleF53OSCControlMessage:controlMessage], @"Should handle valid control message gracefully");

    // Test with complex control message
    F53OSCMessage *complexControl = [F53OSCMessage messageWithAddressPattern:@"!/complex/control/path" arguments:@[@"arg1", @42, @3.14f]];
    XCTAssertNoThrow([server handleF53OSCControlMessage:complexControl], @"Should handle complex control message gracefully");
}

- (void)testThat_serverHandlesControlMessageWithEncryptHandshakeMessage
{
    F53OSCServer *server = [[F53OSCServer alloc] init];

    F53OSCEncrypt *encrypter = [[F53OSCEncrypt alloc] init];
    NSData *keyPairData = [encrypter generateKeyPair];
    XCTAssertNotNil(keyPairData, @"keyPairData should not be nil");
    server.keyPair = keyPairData;
    XCTAssertNotNil(server.keyPair, @"Server keyPair should not be nil");
    XCTAssertEqualObjects(server.keyPair, keyPairData, @"Server keyPair should equal keyPairData");

    // NOTE: Full handshake testing is in F53OSC_EncryptTests.m.
    // We are only testing the F53OSCServer requirements here.

    F53OSCEncryptHandshake *handshake = [F53OSCEncryptHandshake handshakeWithEncrypter:encrypter];

    GCDAsyncUdpSocket *rawReplySocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:nil delegateQueue:nil];
    F53OSCSocket *replySocket = [F53OSCSocket socketWithUdpSocket:rawReplySocket];

    F53OSCMessage *message;

    message = [handshake requestEncryptionMessage];
    message.replySocket = replySocket;
    XCTAssertEqualObjects(message.replySocket, replySocket, @"Message replySocket should be %@", replySocket);

    XCTAssertNoThrow([server handleF53OSCControlMessage:message], @"Should handle valid request message gracefully");
    XCTAssertNotNil(replySocket.encrypter, @"Message replySocket encrypter should not be nil after handling request message");
    XCTAssertEqualObjects(replySocket.encrypter.keyPairData, keyPairData, @"Message replySocket encrypter keyPairData should be equal to keyPairData after handling request message");

    message = [handshake beginEncryptionMessage];
    message.replySocket = replySocket;
    XCTAssertEqualObjects(message.replySocket, replySocket, @"Message replySocket should be %@", replySocket);

    XCTAssertNoThrow([server handleF53OSCControlMessage:message], @"Should handle valid begin message gracefully");
    XCTAssertTrue(replySocket.isEncrypting, @"Message replySocket should be encrypting after handling begin message");
    XCTAssertEqualObjects(replySocket.encrypter.keyPairData, keyPairData, @"Message replySocket encrypter keyPairData should be unchanged after handling begin message");
}

- (void)testThat_serverHandlesNilControlMessage
{
    F53OSCServer *server = [[F53OSCServer alloc] init];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertNoThrow([server handleF53OSCControlMessage:nil], @"Should handle nil control message gracefully");
#pragma clang diagnostic pop
}


#pragma mark -

- (void)testThat_serverValidCharsForOSCMethodExists
{
    NSString *validCharsForOSCMethod = [F53OSCServer validCharsForOSCMethod];

    XCTAssertNotNil(validCharsForOSCMethod, @"Server validCharsForOSCMethod should not be nil");
    XCTAssertGreaterThan(validCharsForOSCMethod.length, 0, @"Default validCharsForOSCMethod should be non-zero length");
}


#pragma mark - NSPredicate creation tests

- (void)testThat_stringMatchesPredicateWithString
{
    // given
    // - match character '1'
    NSString *oscPattern = @"1";

    // when
    NSPredicate *predicate = [self stringTestPredicateWithOSCPattern:oscPattern];

    // then
    XCTAssertNotNil(predicate);
    XCTAssertFalse([predicate evaluateWithObject:nil]);
    XCTAssertThrows([predicate evaluateWithObject:@NO]); // can't do regex matching on an object
    XCTAssertThrows([predicate evaluateWithObject:@YES]); // can't do regex matching on an object
    XCTAssertFalse([predicate evaluateWithObject:@""]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"21"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1."]);
    XCTAssertFalse([predicate evaluateWithObject:@"13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1.3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1?3"]); // ? invalid in OSC address
    XCTAssertFalse([predicate evaluateWithObject:@"1 3"]); // space invalid in OSC address
    XCTAssertFalse([predicate evaluateWithObject:@"1.2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2-13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12-34"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1A"]);
    XCTAssertFalse([predicate evaluateWithObject:@"B2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"!3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"6/1"]); // slash invalid in OSC address
}

- (void)testThat_stringMatchesPredicateWithOSCWildcardAsterisk
{
    // given
    // - match any sequence of zero or more characters
    NSString *oscPattern = @"*";

    // when
    NSPredicate *predicate = [self stringTestPredicateWithOSCPattern:oscPattern];

    // then
    XCTAssertNotNil(predicate);
    XCTAssertFalse([predicate evaluateWithObject:nil]);
    XCTAssertThrows([predicate evaluateWithObject:@NO]); // can't do regex matching on an object
    XCTAssertThrows([predicate evaluateWithObject:@YES]); // can't do regex matching on an object
    XCTAssertTrue( [predicate evaluateWithObject:@""]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"3"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"21"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1."]);
    XCTAssertTrue( [predicate evaluateWithObject:@"13"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1.3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1?3"]); // ? invalid in OSC address
    XCTAssertFalse([predicate evaluateWithObject:@"1 3"]); // space invalid in OSC address
    XCTAssertTrue( [predicate evaluateWithObject:@"1.2"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1-2"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1-3"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1-12"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"2-13"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"10-1"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"10-2"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"10-3"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"12-34"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1A"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"B2"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"!3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"6/1"]); // slash invalid in OSC address
}

- (void)testThat_stringMatchesPredicateWithOSCWildcardAsteriskPrefix
{
    // given
    // - match any sequence of zero or more characters, followed by character '3'
    NSString *oscPattern = @"*3";

    // when
    NSPredicate *predicate = [self stringTestPredicateWithOSCPattern:oscPattern];

    // then
    XCTAssertNotNil(predicate);
    XCTAssertFalse([predicate evaluateWithObject:nil]);
    XCTAssertThrows([predicate evaluateWithObject:@NO]); // can't do regex matching on an object
    XCTAssertThrows([predicate evaluateWithObject:@YES]); // can't do regex matching on an object
    XCTAssertFalse([predicate evaluateWithObject:@""]);
    XCTAssertFalse([predicate evaluateWithObject:@"1"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"21"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1."]);
    XCTAssertTrue( [predicate evaluateWithObject:@"13"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1.3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1?3"]); // ? invalid in OSC address
    XCTAssertFalse([predicate evaluateWithObject:@"1 3"]); // space invalid in OSC address
    XCTAssertFalse([predicate evaluateWithObject:@"1.2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-2"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-12"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"2-13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-2"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"10-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12-34"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1A"]);
    XCTAssertFalse([predicate evaluateWithObject:@"B2"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"!3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"6/1"]); // slash invalid in OSC address
}

- (void)testThat_stringMatchesPredicateWithOSCWildcardAsteriskSuffix
{
    // given
    // - match character '1', followed by any sequence of zero or more characters
    NSString *oscPattern = @"1*";

    // when
    NSPredicate *predicate = [self stringTestPredicateWithOSCPattern:oscPattern];

    // then
    XCTAssertNotNil(predicate);
    XCTAssertFalse([predicate evaluateWithObject:nil]);
    XCTAssertThrows([predicate evaluateWithObject:@NO]); // can't do regex matching on an object
    XCTAssertThrows([predicate evaluateWithObject:@YES]); // can't do regex matching on an object
    XCTAssertFalse([predicate evaluateWithObject:@""]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"21"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1."]);
    XCTAssertTrue( [predicate evaluateWithObject:@"13"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1.3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1?3"]); // ? invalid in OSC address
    XCTAssertFalse([predicate evaluateWithObject:@"1 3"]); // space invalid in OSC address
    XCTAssertTrue( [predicate evaluateWithObject:@"1.2"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1-2"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1-3"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1-12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2-13"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"10-1"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"10-2"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"10-3"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"12-34"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1A"]);
    XCTAssertFalse([predicate evaluateWithObject:@"B2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"!3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"6/1"]); // slash invalid in OSC address
}

- (void)testThat_stringMatchesPredicateWithOSCWildcardAsteriskMiddle
{
    // given
    // - match character '1', followed by any sequence of zero or more characters, followed by character '3'
    NSString *oscPattern = @"1*3";

    // when
    NSPredicate *predicate = [self stringTestPredicateWithOSCPattern:oscPattern];

    // then
    XCTAssertNotNil(predicate);
    XCTAssertFalse([predicate evaluateWithObject:nil]);
    XCTAssertThrows([predicate evaluateWithObject:@NO]); // can't do regex matching on an object
    XCTAssertThrows([predicate evaluateWithObject:@YES]); // can't do regex matching on an object
    XCTAssertFalse([predicate evaluateWithObject:@""]);
    XCTAssertFalse([predicate evaluateWithObject:@"1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"21"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1."]);
    XCTAssertTrue( [predicate evaluateWithObject:@"13"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1.3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1?3"]); // ? invalid in OSC address
    XCTAssertFalse([predicate evaluateWithObject:@"1 3"]); // space invalid in OSC address
    XCTAssertFalse([predicate evaluateWithObject:@"1.2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-2"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2-13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-2"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"10-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12-34"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1A"]);
    XCTAssertFalse([predicate evaluateWithObject:@"B2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"!3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"6/1"]); // slash invalid in OSC address
}

- (void)testThat_stringMatchesPredicateWithOSCWildcardQuestionMark
{
    // given
    // - match any single character
    NSString *oscPattern = @"?";

    // when
    NSPredicate *predicate = [self stringTestPredicateWithOSCPattern:oscPattern];

    // then
    XCTAssertNotNil(predicate);
    XCTAssertFalse([predicate evaluateWithObject:nil]);
    XCTAssertThrows([predicate evaluateWithObject:@NO]); // can't do regex matching on an object
    XCTAssertThrows([predicate evaluateWithObject:@YES]); // can't do regex matching on an object
    XCTAssertFalse([predicate evaluateWithObject:@""]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"21"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1."]);
    XCTAssertFalse([predicate evaluateWithObject:@"13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1.3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1?3"]); // ? invalid in OSC address
    XCTAssertFalse([predicate evaluateWithObject:@"1 3"]); // space invalid in OSC address
    XCTAssertFalse([predicate evaluateWithObject:@"1.2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2-13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12-34"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1A"]);
    XCTAssertFalse([predicate evaluateWithObject:@"B2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"!3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"6/1"]); // slash invalid in OSC address
}

- (void)testThat_stringMatchesPredicateWithOSCWildcardTwoQuestionMarks
{
    // given
    // - match any two characters
    NSString *oscPattern = @"??";

    // when
    NSPredicate *predicate = [self stringTestPredicateWithOSCPattern:oscPattern];

    // then
    XCTAssertNotNil(predicate);
    XCTAssertFalse([predicate evaluateWithObject:nil]);
    XCTAssertThrows([predicate evaluateWithObject:@NO]); // can't do regex matching on an object
    XCTAssertThrows([predicate evaluateWithObject:@YES]); // can't do regex matching on an object
    XCTAssertFalse([predicate evaluateWithObject:@""]);
    XCTAssertFalse([predicate evaluateWithObject:@"1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"3"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"21"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1."]);
    XCTAssertTrue( [predicate evaluateWithObject:@"13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1.3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1?3"]); // ? invalid in OSC address
    XCTAssertFalse([predicate evaluateWithObject:@"1 3"]); // space invalid in OSC address
    XCTAssertFalse([predicate evaluateWithObject:@"1.2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2-13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12-34"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1A"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"B2"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"!3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"6/1"]); // slash invalid in OSC address
}

- (void)testThat_stringMatchesPredicateWithOSCWildcardThreeQuestionMarks
{
    // given
    // - match any three characters
    NSString *oscPattern = @"???";

    // when
    NSPredicate *predicate = [self stringTestPredicateWithOSCPattern:oscPattern];

    // then
    XCTAssertNotNil(predicate);
    XCTAssertFalse([predicate evaluateWithObject:nil]);
    XCTAssertThrows([predicate evaluateWithObject:@NO]); // can't do regex matching on an object
    XCTAssertThrows([predicate evaluateWithObject:@YES]); // can't do regex matching on an object
    XCTAssertFalse([predicate evaluateWithObject:@""]);
    XCTAssertFalse([predicate evaluateWithObject:@"1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"21"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1."]);
    XCTAssertFalse([predicate evaluateWithObject:@"13"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1.3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1?3"]); // ? invalid in OSC address
    XCTAssertFalse([predicate evaluateWithObject:@"1 3"]); // space invalid in OSC address
    XCTAssertTrue( [predicate evaluateWithObject:@"1.2"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1-2"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2-13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12-34"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1A"]);
    XCTAssertFalse([predicate evaluateWithObject:@"B2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"!3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"6/1"]); // slash invalid in OSC address
}

- (void)testThat_stringMatchesPredicateWithOSCWildcardQuestionMarkPrefix
{
    // given
    // - match any single character, followed by character '.'
    NSString *oscPattern = @"?.";

    // when
    NSPredicate *predicate = [self stringTestPredicateWithOSCPattern:oscPattern];

    // then
    XCTAssertNotNil(predicate);
    XCTAssertFalse([predicate evaluateWithObject:nil]);
    XCTAssertThrows([predicate evaluateWithObject:@NO]); // can't do regex matching on an object
    XCTAssertThrows([predicate evaluateWithObject:@YES]); // can't do regex matching on an object
    XCTAssertFalse([predicate evaluateWithObject:@""]);
    XCTAssertFalse([predicate evaluateWithObject:@"1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"21"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1."]);
    XCTAssertFalse([predicate evaluateWithObject:@"13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1.3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1?3"]); // ? invalid in OSC address
    XCTAssertFalse([predicate evaluateWithObject:@"1 3"]); // space invalid in OSC address
    XCTAssertFalse([predicate evaluateWithObject:@"1.2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2-13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12-34"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1A"]);
    XCTAssertFalse([predicate evaluateWithObject:@"B2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"!3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"6/1"]); // slash invalid in OSC address
}

- (void)testThat_stringMatchesPredicateWithOSCWildcardQuestionMarkSuffix
{
    // given
    // - match character '1', followed by any single character
    NSString *oscPattern = @"1?";

    // when
    NSPredicate *predicate = [self stringTestPredicateWithOSCPattern:oscPattern];

    // then
    XCTAssertNotNil(predicate);
    XCTAssertFalse([predicate evaluateWithObject:nil]);
    XCTAssertThrows([predicate evaluateWithObject:@NO]); // can't do regex matching on an object
    XCTAssertThrows([predicate evaluateWithObject:@YES]); // can't do regex matching on an object
    XCTAssertFalse([predicate evaluateWithObject:@""]);
    XCTAssertFalse([predicate evaluateWithObject:@"1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"21"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1."]);
    XCTAssertTrue( [predicate evaluateWithObject:@"13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1.3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1?3"]); // ? invalid in OSC address
    XCTAssertFalse([predicate evaluateWithObject:@"1 3"]); // space invalid in OSC address
    XCTAssertFalse([predicate evaluateWithObject:@"1.2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2-13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12-34"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1A"]);
    XCTAssertFalse([predicate evaluateWithObject:@"B2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"!3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"6/1"]); // slash invalid in OSC address
}

- (void)testThat_stringMatchesPredicateWithOSCWildcardQuestionMarkMiddle
{
    // given
    // - match character '1', followed by any single character, followed by character '3'
    NSString *oscPattern = @"1?3";

    // when
    NSPredicate *predicate = [self stringTestPredicateWithOSCPattern:oscPattern];

    // then
    XCTAssertNotNil(predicate);
    XCTAssertFalse([predicate evaluateWithObject:nil]);
    XCTAssertThrows([predicate evaluateWithObject:@NO]); // can't do regex matching on an object
    XCTAssertThrows([predicate evaluateWithObject:@YES]); // can't do regex matching on an object
    XCTAssertFalse([predicate evaluateWithObject:@""]);
    XCTAssertFalse([predicate evaluateWithObject:@"1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"21"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1."]);
    XCTAssertFalse([predicate evaluateWithObject:@"13"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1.3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1?3"]); // ? invalid in OSC address
    XCTAssertFalse([predicate evaluateWithObject:@"1 3"]); // space invalid in OSC address
    XCTAssertFalse([predicate evaluateWithObject:@"1.2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-2"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2-13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12-34"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1A"]);
    XCTAssertFalse([predicate evaluateWithObject:@"B2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"!3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"6/1"]); // slash invalid in OSC address
}

- (void)testThat_stringMatchesPredicateWithOSCWildcardStringRange
{
    NSString *oscPattern;
    NSPredicate *predicate;

    // given
    // when
    // then
    oscPattern = @"12"; // match exact string '12'
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil(predicate);
    XCTAssertFalse([predicate evaluateWithObject:nil]);
    XCTAssertThrows([predicate evaluateWithObject:@NO]); // can't do regex matching on an object
    XCTAssertThrows([predicate evaluateWithObject:@YES]); // can't do regex matching on an object
    XCTAssertFalse([predicate evaluateWithObject:@""]);
    XCTAssertFalse([predicate evaluateWithObject:@"1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"3"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1 3"]); // space invalid in OSC address
    XCTAssertFalse([predicate evaluateWithObject:@"1.2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2-13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12-34"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1A"]);
    XCTAssertFalse([predicate evaluateWithObject:@"B2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"!3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"6/1"]); // slash invalid in OSC address

    oscPattern = @"[12]"; // match either character '1' or character '2'
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil(predicate);
    XCTAssertFalse([predicate evaluateWithObject:nil]);
    XCTAssertThrows([predicate evaluateWithObject:@NO]); // can't do regex matching on an object
    XCTAssertThrows([predicate evaluateWithObject:@YES]); // can't do regex matching on an object
    XCTAssertFalse([predicate evaluateWithObject:@""]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1 3"]); // space invalid in OSC address
    XCTAssertFalse([predicate evaluateWithObject:@"1.2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2-13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12-34"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1A"]);
    XCTAssertFalse([predicate evaluateWithObject:@"B2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"!3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"6/1"]); // slash invalid in OSC address

    oscPattern = @"1-3"; // match exact string '1-3'
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil(predicate);
    XCTAssertFalse([predicate evaluateWithObject:nil]);
    XCTAssertThrows([predicate evaluateWithObject:@NO]); // can't do regex matching on an object
    XCTAssertThrows([predicate evaluateWithObject:@YES]); // can't do regex matching on an object
    XCTAssertFalse([predicate evaluateWithObject:@""]);
    XCTAssertFalse([predicate evaluateWithObject:@"1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"13"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1 3"]); // space invalid in OSC address
    XCTAssertFalse([predicate evaluateWithObject:@"1.2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2-13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12-34"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1A"]);
    XCTAssertFalse([predicate evaluateWithObject:@"B2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"!3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"6/1"]); // slash invalid in OSC address

    oscPattern = @"[1-3]"; // match any single character in range of '1' thru '3' inclusive
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil(predicate);
    XCTAssertFalse([predicate evaluateWithObject:nil]);
    XCTAssertThrows([predicate evaluateWithObject:@NO]); // can't do regex matching on an object
    XCTAssertThrows([predicate evaluateWithObject:@YES]); // can't do regex matching on an object
    XCTAssertFalse([predicate evaluateWithObject:@""]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"2"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1 3"]); // space invalid in OSC address
    XCTAssertFalse([predicate evaluateWithObject:@"1.2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2-13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12-34"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1A"]);
    XCTAssertFalse([predicate evaluateWithObject:@"B2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"!3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"6/1"]); // slash invalid in OSC address

    oscPattern = @"[1][2]"; // match character '1', followed by character '2'
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil(predicate);
    XCTAssertFalse([predicate evaluateWithObject:nil]);
    XCTAssertThrows([predicate evaluateWithObject:@NO]); // can't do regex matching on an object
    XCTAssertThrows([predicate evaluateWithObject:@YES]); // can't do regex matching on an object
    XCTAssertFalse([predicate evaluateWithObject:@""]);
    XCTAssertFalse([predicate evaluateWithObject:@"1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"3"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1 3"]); // space invalid in OSC address
    XCTAssertFalse([predicate evaluateWithObject:@"1.2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2-13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12-34"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1A"]);
    XCTAssertFalse([predicate evaluateWithObject:@"B2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"!3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"6/1"]); // slash invalid in OSC address

    oscPattern = @"[!1]"; // match any single character except for '1'
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil(predicate);
    XCTAssertFalse([predicate evaluateWithObject:nil]);
    XCTAssertThrows([predicate evaluateWithObject:@NO]); // can't do regex matching on an object
    XCTAssertThrows([predicate evaluateWithObject:@YES]); // can't do regex matching on an object
    XCTAssertFalse([predicate evaluateWithObject:@""]);
    XCTAssertFalse([predicate evaluateWithObject:@"1"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"2"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1 3"]); // space invalid in OSC address
    XCTAssertFalse([predicate evaluateWithObject:@"1.2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2-13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12-34"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1A"]);
    XCTAssertFalse([predicate evaluateWithObject:@"B2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"!3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"6/1"]); // slash invalid in OSC address

    oscPattern = @"{1,2,12}"; // match exact string '1', '2', or '12'
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil(predicate);
    XCTAssertFalse([predicate evaluateWithObject:nil]);
    XCTAssertThrows([predicate evaluateWithObject:@NO]); // can't do regex matching on an object
    XCTAssertThrows([predicate evaluateWithObject:@YES]); // can't do regex matching on an object
    XCTAssertFalse([predicate evaluateWithObject:@""]);
    XCTAssertFalse([predicate evaluateWithObject:@"1,2,12"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"3"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1 3"]); // space invalid in OSC address
    XCTAssertFalse([predicate evaluateWithObject:@"1.2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2-13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12-34"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1A"]);
    XCTAssertFalse([predicate evaluateWithObject:@"B2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"!3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"6/1"]); // slash invalid in OSC address

    oscPattern = @"{1,2,3}-{1,2,3}"; // match characters '1', '2', or '3', followed by minus sign, followed by characters '1', '2', or '3'
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil(predicate);
    XCTAssertFalse([predicate evaluateWithObject:nil]);
    XCTAssertThrows([predicate evaluateWithObject:@NO]); // can't do regex matching on an object
    XCTAssertThrows([predicate evaluateWithObject:@YES]); // can't do regex matching on an object
    XCTAssertFalse([predicate evaluateWithObject:@""]);
    XCTAssertFalse([predicate evaluateWithObject:@"{1,2,3}-{1,2,3}"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"123"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1 3"]); // space invalid in OSC address
    XCTAssertFalse([predicate evaluateWithObject:@"1.2"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2-13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12-34"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1A"]);
    XCTAssertFalse([predicate evaluateWithObject:@"B2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"!3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"6/1"]); // slash invalid in OSC address

    // NOTE: this pattern looks like "numbers 10-23", but it is not. (See below for the correct pattern.)
    oscPattern = @"[10-23]"; // match single character '1', a character in range of '0' thru '2' inclusive, or single character '3'
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil(predicate);
    XCTAssertFalse([predicate evaluateWithObject:nil]);
    XCTAssertThrows([predicate evaluateWithObject:@NO]); // can't do regex matching on an object
    XCTAssertThrows([predicate evaluateWithObject:@YES]); // can't do regex matching on an object
    XCTAssertFalse([predicate evaluateWithObject:@""]);
    XCTAssertTrue( [predicate evaluateWithObject:@"0"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"2"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"4"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1 3"]); // space invalid in OSC address
    XCTAssertFalse([predicate evaluateWithObject:@"1.2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2-13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12-34"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1A"]);
    XCTAssertFalse([predicate evaluateWithObject:@"B2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"!3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"6/1"]); // slash invalid in OSC address

    // NOTE: this pattern looks like "numbers 10-23", but it is not. (See below for the correct pattern.)
    oscPattern = @"[(10)-(23)]"; // match any single character '(', '1', or '0'; or any character in range ')' thru '(' inclusive (which is an invalid range); or any single character '2', '3', or ')'. NOTE: the range portion ")-(" is invalid because in ASCII, the character ")" does not come before character "(", and `evaluateWithObject:` throws an exception with error: "Can't do regex matching, reason: Can't open pattern U_REGEX_INVALID_RANGE".
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil(predicate);
    XCTAssertNoThrow([predicate evaluateWithObject:nil]);
    XCTAssertThrows([predicate evaluateWithObject:@NO]); // can't do regex matching on an object
    XCTAssertThrows([predicate evaluateWithObject:@YES]); // can't do regex matching on an object
    XCTAssertThrows([predicate evaluateWithObject:@""]);
    XCTAssertThrows([predicate evaluateWithObject:@"0"]);
    XCTAssertThrows([predicate evaluateWithObject:@"1"]);
    XCTAssertThrows([predicate evaluateWithObject:@"2"]);
    XCTAssertThrows([predicate evaluateWithObject:@"3"]);
    XCTAssertThrows([predicate evaluateWithObject:@"4"]);
    XCTAssertThrows([predicate evaluateWithObject:@"12"]);
    XCTAssertThrows([predicate evaluateWithObject:@"13"]);
    XCTAssertThrows([predicate evaluateWithObject:@"1-3"]);
    XCTAssertThrows([predicate evaluateWithObject:@"1 3"]);
    XCTAssertThrows([predicate evaluateWithObject:@"1.2"]);
    XCTAssertThrows([predicate evaluateWithObject:@"1-2"]);
    XCTAssertThrows([predicate evaluateWithObject:@"1-12"]);
    XCTAssertThrows([predicate evaluateWithObject:@"2-13"]);
    XCTAssertThrows([predicate evaluateWithObject:@"10-1"]);
    XCTAssertThrows([predicate evaluateWithObject:@"10-2"]);
    XCTAssertThrows([predicate evaluateWithObject:@"10-3"]);
    XCTAssertThrows([predicate evaluateWithObject:@"12-34"]);
    XCTAssertThrows([predicate evaluateWithObject:@"1A"]);
    XCTAssertThrows([predicate evaluateWithObject:@"B2"]);
    XCTAssertThrows([predicate evaluateWithObject:@"!3"]);
    XCTAssertThrows([predicate evaluateWithObject:@"6/1"]);

    // "numbers 10 thru 23" (the correct way)
    oscPattern = @"{1[0-9],2[0-3]}"; // match exact string '1' followed by a single character in the range of '0' thru '9' inclusive, or exact string '2' followed by a single character in the range of '0' thru '3' inclusive
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil(predicate);
    XCTAssertFalse([predicate evaluateWithObject:nil]);
    XCTAssertThrows([predicate evaluateWithObject:@NO]); // can't do regex matching on an object
    XCTAssertThrows([predicate evaluateWithObject:@YES]); // can't do regex matching on an object
    XCTAssertFalse([predicate evaluateWithObject:@""]);
    XCTAssertFalse([predicate evaluateWithObject:@"0"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"4"]);
    XCTAssertFalse([predicate evaluateWithObject:@"5"]);
    XCTAssertFalse([predicate evaluateWithObject:@"6"]);
    XCTAssertFalse([predicate evaluateWithObject:@"7"]);
    XCTAssertFalse([predicate evaluateWithObject:@"8"]);
    XCTAssertFalse([predicate evaluateWithObject:@"9"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"10"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"11"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"12"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"13"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"14"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"15"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"16"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"17"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"18"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"19"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"20"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"21"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"22"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"23"]);
    XCTAssertFalse([predicate evaluateWithObject:@"24"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1 3"]); // space invalid in OSC address
    XCTAssertFalse([predicate evaluateWithObject:@"1.2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2-13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12-34"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1A"]);
    XCTAssertFalse([predicate evaluateWithObject:@"B2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"!3"]);
}

- (void)testThat_stringMatchesPredicateWithOSCWildcardStringList
{
    NSString *oscPattern;
    NSPredicate *predicate;

    // given
    // when
    // then
    oscPattern = @"{12}"; // match exact string '12'
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil(predicate);
    XCTAssertFalse([predicate evaluateWithObject:nil]);
    XCTAssertThrows([predicate evaluateWithObject:@NO]); // can't do regex matching on an object
    XCTAssertThrows([predicate evaluateWithObject:@YES]); // can't do regex matching on an object
    XCTAssertFalse([predicate evaluateWithObject:@""]);
    XCTAssertFalse([predicate evaluateWithObject:@"{12}"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"11"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1.2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2-13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12-34"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1A"]);
    XCTAssertFalse([predicate evaluateWithObject:@"B2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"!3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"6/1"]); // slash invalid in OSC address

    oscPattern = @"{12,13}"; // match exact string '12' or '13'
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil(predicate);
    XCTAssertFalse([predicate evaluateWithObject:nil]);
    XCTAssertThrows([predicate evaluateWithObject:@NO]); // can't do regex matching on an object
    XCTAssertThrows([predicate evaluateWithObject:@YES]); // can't do regex matching on an object
    XCTAssertFalse([predicate evaluateWithObject:@""]);
    XCTAssertFalse([predicate evaluateWithObject:@"12,13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"{12,13}"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"11"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"12"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1.2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2-13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12-34"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1A"]);
    XCTAssertFalse([predicate evaluateWithObject:@"B2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"!3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"6/1"]); // slash invalid in OSC address

    oscPattern = @"{[1-3],[1][1-3]}"; // match (any single character in range of '1' thru '3' inclusive), or (character '1', followed by any single character in range of '1' thru '3' inclusive)
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil(predicate);
    XCTAssertFalse([predicate evaluateWithObject:nil]);
    XCTAssertThrows([predicate evaluateWithObject:@NO]); // can't do regex matching on an object
    XCTAssertThrows([predicate evaluateWithObject:@YES]); // can't do regex matching on an object
    XCTAssertFalse([predicate evaluateWithObject:@""]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"[1]"]);
    XCTAssertFalse([predicate evaluateWithObject:@"[1-3]"]);
    XCTAssertFalse([predicate evaluateWithObject:@"[1][1-3]"]);
    XCTAssertFalse([predicate evaluateWithObject:@"{[1-3],[1][1-3]}"]);
    XCTAssertFalse([predicate evaluateWithObject:@"0"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"2"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"4"]);
    XCTAssertFalse([predicate evaluateWithObject:@"01"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"11"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"12"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"14"]);
    XCTAssertFalse([predicate evaluateWithObject:@"111"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1.2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2-13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12-34"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1A"]);
    XCTAssertFalse([predicate evaluateWithObject:@"B2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"!3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"6/1"]); // slash invalid in OSC address

    oscPattern = @"{[1-3],[1][2-3]}"; // match (any single character in range of '1' thru '3' inclusive), or (character '1', followed by any single character in range of '2' thru '3' inclusive)
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil(predicate);
    XCTAssertFalse([predicate evaluateWithObject:nil]);
    XCTAssertThrows([predicate evaluateWithObject:@NO]); // can't do regex matching on an object
    XCTAssertThrows([predicate evaluateWithObject:@YES]); // can't do regex matching on an object
    XCTAssertFalse([predicate evaluateWithObject:@""]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"[1]"]);
    XCTAssertFalse([predicate evaluateWithObject:@"[2-3]"]);
    XCTAssertFalse([predicate evaluateWithObject:@"[1][2-3]"]);
    XCTAssertFalse([predicate evaluateWithObject:@"{[1-3],[1][2-3]}"]);
    XCTAssertFalse([predicate evaluateWithObject:@"0"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"2"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"4"]);
    XCTAssertFalse([predicate evaluateWithObject:@"01"]);
    XCTAssertFalse([predicate evaluateWithObject:@"11"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"12"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"14"]);
    XCTAssertFalse([predicate evaluateWithObject:@"111"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1.2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2-13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12-34"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1A"]);
    XCTAssertFalse([predicate evaluateWithObject:@"B2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"!3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"6/1"]); // slash invalid in OSC address

    oscPattern = @"{[!1-3],[1][1-3]}"; // match (any single character NOT in range of '1' thru '3' inclusive), or (character '1', followed by any single character in range of '1' thru '3' inclusive)
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil(predicate);
    XCTAssertFalse([predicate evaluateWithObject:nil]);
    XCTAssertThrows([predicate evaluateWithObject:@NO]); // can't do regex matching on an object
    XCTAssertThrows([predicate evaluateWithObject:@YES]); // can't do regex matching on an object
    XCTAssertFalse([predicate evaluateWithObject:@""]);
    XCTAssertFalse([predicate evaluateWithObject:@"1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"!1-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"[1]"]);
    XCTAssertFalse([predicate evaluateWithObject:@"[1-3]"]);
    XCTAssertFalse([predicate evaluateWithObject:@"[1][1-3]"]);
    XCTAssertFalse([predicate evaluateWithObject:@"{[!1-3],[1][1-3]}"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"0"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"3"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"4"]);
    XCTAssertFalse([predicate evaluateWithObject:@"01"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"11"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"12"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"14"]);
    XCTAssertFalse([predicate evaluateWithObject:@"111"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1.2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2-13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12-34"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1A"]);
    XCTAssertFalse([predicate evaluateWithObject:@"B2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"!3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"6/1"]); // slash invalid in OSC address

    oscPattern = @"{[!12],[1][A-C]}"; // match (any single character excluding '1' or '2'), or (character '1', followed by any single character in range of 'A' thru 'C' inclusive)
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil(predicate);
    XCTAssertFalse([predicate evaluateWithObject:nil]);
    XCTAssertThrows([predicate evaluateWithObject:@NO]); // can't do regex matching on an object
    XCTAssertThrows([predicate evaluateWithObject:@YES]); // can't do regex matching on an object
    XCTAssertFalse([predicate evaluateWithObject:@""]);
    XCTAssertFalse([predicate evaluateWithObject:@"!12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"[!12]"]);
    XCTAssertFalse([predicate evaluateWithObject:@"[2-3]"]);
    XCTAssertFalse([predicate evaluateWithObject:@"[1][2-3]"]);
    XCTAssertFalse([predicate evaluateWithObject:@"{[!12],[1][2-3]}"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"0"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"3"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"4"]);
    XCTAssertFalse([predicate evaluateWithObject:@"11"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1A"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1B"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1C"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1a"]); // matching is case-sensitive
    XCTAssertFalse([predicate evaluateWithObject:@"1b"]); // matching is case-sensitive
    XCTAssertFalse([predicate evaluateWithObject:@"1c"]); // matching is case-sensitive
    XCTAssertFalse([predicate evaluateWithObject:@"111"]);
    XCTAssertFalse([predicate evaluateWithObject:@"313"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1.2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2-13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12-34"]);
    XCTAssertFalse([predicate evaluateWithObject:@"B2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"!3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"6/1"]); // slash invalid in OSC address

    oscPattern = @"{2,?3}"; // match (character '2'), or (any single character, followed by '3')
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil(predicate);
    XCTAssertFalse([predicate evaluateWithObject:nil]);
    XCTAssertThrows([predicate evaluateWithObject:@NO]); // can't do regex matching on an object
    XCTAssertThrows([predicate evaluateWithObject:@YES]); // can't do regex matching on an object
    XCTAssertFalse([predicate evaluateWithObject:@""]);
    XCTAssertFalse([predicate evaluateWithObject:@"2,?3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"{2,?3}"]);
    XCTAssertFalse([predicate evaluateWithObject:@"0"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"4"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10"]);
    XCTAssertFalse([predicate evaluateWithObject:@"11"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"14"]);
    XCTAssertFalse([predicate evaluateWithObject:@"x0"]);
    XCTAssertFalse([predicate evaluateWithObject:@"x1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"x2"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"x3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"x4"]);
    XCTAssertFalse([predicate evaluateWithObject:@"213"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1.2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2-13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12-34"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1A"]);
    XCTAssertFalse([predicate evaluateWithObject:@"B2"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"!3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"6/1"]); // slash invalid in OSC address

    oscPattern = @"{1*,3}"; // match (character '1', followed by any sequence of zero or more characters), or (character '3')
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil(predicate);
    XCTAssertFalse([predicate evaluateWithObject:nil]);
    XCTAssertThrows([predicate evaluateWithObject:@NO]); // can't do regex matching on an object
    XCTAssertThrows([predicate evaluateWithObject:@YES]); // can't do regex matching on an object
    XCTAssertFalse([predicate evaluateWithObject:@""]);
    XCTAssertFalse([predicate evaluateWithObject:@"1*,3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"{1*,3}"]);
    XCTAssertFalse([predicate evaluateWithObject:@"0"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"4"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"10"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"11"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"12"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"13"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1A"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1B"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1C"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"111"]);
    XCTAssertFalse([predicate evaluateWithObject:@"222"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1.2"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1-2"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1-3"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1-12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2-13"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"10-1"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"10-2"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"10-3"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"12-34"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"1A"]);
    XCTAssertFalse([predicate evaluateWithObject:@"B2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"!3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"6/1"]); // slash invalid in OSC address

    oscPattern = @"[Q-c]"; // match any single character in range of 'Q' thru 'c' inclusive
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil(predicate);
    XCTAssertFalse([predicate evaluateWithObject:nil]);
    XCTAssertThrows([predicate evaluateWithObject:@NO]); // can't do regex matching on an object
    XCTAssertThrows([predicate evaluateWithObject:@YES]); // can't do regex matching on an object
    XCTAssertFalse([predicate evaluateWithObject:@""]);
    XCTAssertFalse([predicate evaluateWithObject:@"Q-c"]);
    XCTAssertFalse([predicate evaluateWithObject:@"[Q-c]"]);
    XCTAssertFalse([predicate evaluateWithObject:@"0"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"123"]);
    XCTAssertFalse([predicate evaluateWithObject:@"A"]);
    XCTAssertFalse([predicate evaluateWithObject:@"B"]);
    XCTAssertFalse([predicate evaluateWithObject:@"C"]);
    XCTAssertFalse([predicate evaluateWithObject:@"O"]);
    XCTAssertFalse([predicate evaluateWithObject:@"P"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"Q"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"R"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"X"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"Y"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"Z"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"a"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"b"]);
    XCTAssertTrue( [predicate evaluateWithObject:@"c"]);
    XCTAssertFalse([predicate evaluateWithObject:@"d"]);
    XCTAssertFalse([predicate evaluateWithObject:@"PP"]);
    XCTAssertFalse([predicate evaluateWithObject:@"PPP"]);
    XCTAssertFalse([predicate evaluateWithObject:@"QQ"]);
    XCTAssertFalse([predicate evaluateWithObject:@"QRS"]);
    XCTAssertFalse([predicate evaluateWithObject:@"XYZ"]);
    XCTAssertFalse([predicate evaluateWithObject:@"aa"]);
    XCTAssertFalse([predicate evaluateWithObject:@"abc"]);
}

- (void)testThat_stringDoesNotMatchPredicateWithMalformedOSCPattern
{
    NSString *oscPattern;
    NSPredicate *predicate;

    // given
    // when
    // then
    oscPattern = @"[12"; // malformed pattern, missing closing square bracket
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil(predicate);
    XCTAssertFalse([predicate evaluateWithObject:nil]);
    XCTAssertNoThrow([predicate evaluateWithObject:@NO]); // can do matching on an object with FALSEPREDICATE
    XCTAssertFalse([predicate evaluateWithObject:@NO]);
    XCTAssertNoThrow([predicate evaluateWithObject:@YES]); // can do matching on an object with FALSEPREDICATE
    XCTAssertFalse([predicate evaluateWithObject:@YES]);
    XCTAssertFalse([predicate evaluateWithObject:@""]);
    XCTAssertFalse([predicate evaluateWithObject:@"1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1 3"]); // space invalid in OSC address
    XCTAssertFalse([predicate evaluateWithObject:@"1.2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2-13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12-34"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1A"]);
    XCTAssertFalse([predicate evaluateWithObject:@"B2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"!3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"6/1"]); // slash invalid in OSC address

    oscPattern = @"[12["; // malformed pattern, two opening square brackets
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil(predicate);
    XCTAssertFalse([predicate evaluateWithObject:nil]);
    XCTAssertNoThrow([predicate evaluateWithObject:@NO]); // can do matching on an object with FALSEPREDICATE
    XCTAssertFalse([predicate evaluateWithObject:@NO]);
    XCTAssertNoThrow([predicate evaluateWithObject:@YES]); // can do matching on an object with FALSEPREDICATE
    XCTAssertFalse([predicate evaluateWithObject:@YES]);
    XCTAssertFalse([predicate evaluateWithObject:@""]);
    XCTAssertFalse([predicate evaluateWithObject:@"1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1 3"]); // space invalid in OSC address
    XCTAssertFalse([predicate evaluateWithObject:@"1.2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2-13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12-34"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1A"]);
    XCTAssertFalse([predicate evaluateWithObject:@"B2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"!3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"6/1"]); // slash invalid in OSC address

    oscPattern = @"1]2"; // malformed pattern, missing opening square bracket
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil(predicate);
    XCTAssertFalse([predicate evaluateWithObject:nil]);
    XCTAssertNoThrow([predicate evaluateWithObject:@NO]); // can do matching on an object with FALSEPREDICATE
    XCTAssertFalse([predicate evaluateWithObject:@NO]);
    XCTAssertNoThrow([predicate evaluateWithObject:@YES]); // can do matching on an object with FALSEPREDICATE
    XCTAssertFalse([predicate evaluateWithObject:@YES]);
    XCTAssertFalse([predicate evaluateWithObject:@""]);
    XCTAssertFalse([predicate evaluateWithObject:@"1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1 3"]); // space invalid in OSC address
    XCTAssertFalse([predicate evaluateWithObject:@"1.2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2-13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12-34"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1A"]);
    XCTAssertFalse([predicate evaluateWithObject:@"B2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"!3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"6/1"]); // slash invalid in OSC address

    oscPattern = @"]12]"; // malformed pattern, two closing square brackets
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil(predicate);
    XCTAssertFalse([predicate evaluateWithObject:nil]);
    XCTAssertNoThrow([predicate evaluateWithObject:@NO]); // can do matching on an object with FALSEPREDICATE
    XCTAssertFalse([predicate evaluateWithObject:@NO]);
    XCTAssertNoThrow([predicate evaluateWithObject:@YES]); // can do matching on an object with FALSEPREDICATE
    XCTAssertFalse([predicate evaluateWithObject:@YES]);
    XCTAssertFalse([predicate evaluateWithObject:@""]);
    XCTAssertFalse([predicate evaluateWithObject:@"1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1 3"]); // space invalid in OSC address
    XCTAssertFalse([predicate evaluateWithObject:@"1.2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2-13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12-34"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1A"]);
    XCTAssertFalse([predicate evaluateWithObject:@"B2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"!3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"6/1"]); // slash invalid in OSC address

    oscPattern = @"{1,2,12"; // malformed pattern, missing closing curly brace
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil(predicate);
    XCTAssertFalse([predicate evaluateWithObject:nil]);
    XCTAssertNoThrow([predicate evaluateWithObject:@NO]); // can do matching on an object with FALSEPREDICATE
    XCTAssertFalse([predicate evaluateWithObject:@NO]);
    XCTAssertNoThrow([predicate evaluateWithObject:@YES]); // can do matching on an object with FALSEPREDICATE
    XCTAssertFalse([predicate evaluateWithObject:@YES]);
    XCTAssertFalse([predicate evaluateWithObject:@""]);
    XCTAssertFalse([predicate evaluateWithObject:@"1,2,12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1 3"]); // space invalid in OSC address
    XCTAssertFalse([predicate evaluateWithObject:@"1.2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2-13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12-34"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1A"]);
    XCTAssertFalse([predicate evaluateWithObject:@"B2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"!3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"6/1"]); // slash invalid in OSC address

    oscPattern = @"{1,2,12{"; // malformed pattern, two opening curly braces
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil(predicate);
    XCTAssertFalse([predicate evaluateWithObject:nil]);
    XCTAssertNoThrow([predicate evaluateWithObject:@NO]); // can do matching on an object with FALSEPREDICATE
    XCTAssertFalse([predicate evaluateWithObject:@NO]);
    XCTAssertNoThrow([predicate evaluateWithObject:@YES]); // can do matching on an object with FALSEPREDICATE
    XCTAssertFalse([predicate evaluateWithObject:@YES]);
    XCTAssertFalse([predicate evaluateWithObject:@""]);
    XCTAssertFalse([predicate evaluateWithObject:@"1,2,12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1 3"]); // space invalid in OSC address
    XCTAssertFalse([predicate evaluateWithObject:@"1.2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2-13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12-34"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1A"]);
    XCTAssertFalse([predicate evaluateWithObject:@"B2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"!3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"6/1"]); // slash invalid in OSC address

    oscPattern = @"1,2,12}"; // malformed pattern, missing opening curly brace
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil(predicate);
    XCTAssertFalse([predicate evaluateWithObject:nil]);
    XCTAssertNoThrow([predicate evaluateWithObject:@NO]); // can do matching on an object with FALSEPREDICATE
    XCTAssertFalse([predicate evaluateWithObject:@NO]);
    XCTAssertNoThrow([predicate evaluateWithObject:@YES]); // can do matching on an object with FALSEPREDICATE
    XCTAssertFalse([predicate evaluateWithObject:@YES]);
    XCTAssertFalse([predicate evaluateWithObject:@""]);
    XCTAssertFalse([predicate evaluateWithObject:@"1,2,12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1 3"]); // space invalid in OSC address
    XCTAssertFalse([predicate evaluateWithObject:@"1.2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2-13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12-34"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1A"]);
    XCTAssertFalse([predicate evaluateWithObject:@"B2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"!3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"6/1"]); // slash invalid in OSC address

    oscPattern = @"}1,2,12}"; // malformed pattern, two closing curly braces
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil(predicate);
    XCTAssertFalse([predicate evaluateWithObject:nil]);
    XCTAssertNoThrow([predicate evaluateWithObject:@NO]); // can do matching on an object with FALSEPREDICATE
    XCTAssertFalse([predicate evaluateWithObject:@NO]);
    XCTAssertNoThrow([predicate evaluateWithObject:@YES]); // can do matching on an object with FALSEPREDICATE
    XCTAssertFalse([predicate evaluateWithObject:@YES]);
    XCTAssertFalse([predicate evaluateWithObject:@""]);
    XCTAssertFalse([predicate evaluateWithObject:@"1,2,12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1 3"]); // space invalid in OSC address
    XCTAssertFalse([predicate evaluateWithObject:@"1.2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1-12"]);
    XCTAssertFalse([predicate evaluateWithObject:@"2-13"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-1"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"10-3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"12-34"]);
    XCTAssertFalse([predicate evaluateWithObject:@"1A"]);
    XCTAssertFalse([predicate evaluateWithObject:@"B2"]);
    XCTAssertFalse([predicate evaluateWithObject:@"!3"]);
    XCTAssertFalse([predicate evaluateWithObject:@"6/1"]); // slash invalid in OSC address
}


#pragma mark - Socket delegate tests

- (void)testThat_serverHandlesSocketDelegateMethods
{
    F53OSCServer *server = [[F53OSCServer alloc] init];
    server.port = 9500;

    GCDAsyncSocket *tcpSocket = [[GCDAsyncSocket alloc] initWithDelegate:nil delegateQueue:dispatch_get_main_queue()];
    GCDAsyncUdpSocket *udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:nil delegateQueue:dispatch_get_main_queue()];

    // Test socket delegate methods that have 0% coverage
    XCTAssertNoThrow([server socket:tcpSocket didConnectToHost:@"localhost" port:9500], @"Should handle didConnectToHost gracefully");

    XCTAssertNoThrow([server socket:tcpSocket didReadPartialDataOfLength:100 tag:0], @"Should handle didReadPartialDataOfLength gracefully");

    XCTAssertNoThrow([server socket:tcpSocket didWriteDataWithTag:0], @"Should handle didWriteDataWithTag gracefully");

    XCTAssertNoThrow([server socket:tcpSocket didWritePartialDataOfLength:50 tag:0], @"Should handle didWritePartialDataOfLength gracefully");

    // Test timeout methods
    BOOL shouldTimeoutRead = [server socket:tcpSocket shouldTimeoutReadWithTag:0 elapsed:5.0 bytesDone:100];
    XCTAssertFalse(shouldTimeoutRead, @"Should not timeout read operations by default");

    BOOL shouldTimeoutWrite = [server socket:tcpSocket shouldTimeoutWriteWithTag:0 elapsed:5.0 bytesDone:50];
    XCTAssertFalse(shouldTimeoutWrite, @"Should not timeout write operations by default");

    XCTAssertNoThrow([server socketDidCloseReadStream:tcpSocket], @"Should handle socketDidCloseReadStream gracefully");

    XCTAssertNoThrow([server socketDidSecure:tcpSocket], @"Should handle socketDidSecure gracefully");

    // Test UDP socket delegate methods
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    addr.sin_port = htons(9500);
    NSData *addressData = [NSData dataWithBytes:&addr length:sizeof(addr)];

    XCTAssertNoThrow([server udpSocket:udpSocket didConnectToAddress:addressData], @"Should handle UDP didConnectToAddress gracefully");

    NSError *mockError = [NSError errorWithDomain:@"TestErrorDomain" code:100 userInfo:@{NSLocalizedDescriptionKey: @"Test error"}];
    XCTAssertNoThrow([server udpSocket:udpSocket didNotConnect:mockError], @"Should handle UDP didNotConnect gracefully");

    XCTAssertNoThrow([server udpSocket:udpSocket didSendDataWithTag:0], @"Should handle UDP didSendDataWithTag gracefully");

    XCTAssertNoThrow([server udpSocket:udpSocket didNotSendDataWithTag:0 dueToError:mockError], @"Should handle UDP didNotSendDataWithTag gracefully");
}

- (void)testThat_serverHandlesSocketAcceptance
{
    F53OSCServer *server = [[F53OSCServer alloc] init];
    server.port = 9501;

    // Start listening to initialize socket infrastructure
    BOOL started = [server startListening];
    XCTAssertTrue(started, @"Server should start listening on custom port");

    GCDAsyncSocket *socket = [[GCDAsyncSocket alloc] initWithDelegate:nil delegateQueue:dispatch_get_main_queue()];
    GCDAsyncSocket *newSocket = [[GCDAsyncSocket alloc] initWithDelegate:nil delegateQueue:dispatch_get_main_queue()];

    // Test socket acceptance - this should exercise the socket:didAcceptNewSocket: method
    XCTAssertNoThrow([server socket:socket didAcceptNewSocket:newSocket], @"Should handle socket acceptance gracefully");

    [server stopListening];
}

- (void)testThat_serverHandlesSocketDisconnection
{
    F53OSCServer *server = [[F53OSCServer alloc] init];
    server.port = 9502;

    // Start listening to initialize socket infrastructure
    BOOL started = [server startListening];
    XCTAssertTrue(started, @"Server should start listening");

    GCDAsyncSocket *socket = [[GCDAsyncSocket alloc] initWithDelegate:nil delegateQueue:dispatch_get_main_queue()];

    // Test disconnection without error
    XCTAssertNoThrow([server socketDidDisconnect:socket withError:nil], @"Should handle disconnection without error gracefully");

    // Test disconnection with error
    NSError *disconnectError = [NSError errorWithDomain:@"TestErrorDomain" code:200 userInfo:@{NSLocalizedDescriptionKey: @"Test disconnect error"}];
    XCTAssertNoThrow([server socketDidDisconnect:socket withError:disconnectError], @"Should handle disconnection with error gracefully");

    [server stopListening];
}

- (void)testThat_serverNewSocketQueueMethod
{
    F53OSCServer *server = [[F53OSCServer alloc] init];

    GCDAsyncSocket *tcpSocket = [[GCDAsyncSocket alloc] initWithDelegate:nil delegateQueue:dispatch_get_main_queue()];

    // Create an address
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    addr.sin_port = htons(9503);
    NSData *addressData = [NSData dataWithBytes:&addr length:sizeof(addr)];

    // Test new socket queue method
    dispatch_queue_t resultQueue = [server newSocketQueueForConnectionFromAddress:addressData onSocket:tcpSocket];

    XCTAssertNotNil(resultQueue, @"Should return a dispatch queue");
    // The method should return the server's delegate queue
    XCTAssertEqual(resultQueue, server.queue, @"Should return the server's delegate queue");
}


#pragma mark - F53OSCServerDelegate

- (void)takeMessage:(nullable F53OSCMessage *)message
{
}

@end

NS_ASSUME_NONNULL_END
