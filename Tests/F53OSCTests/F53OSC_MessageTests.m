//
//  F53OSC_MessageTests.m
//  F53OSC
//
//  Created by Brent Lord on 2/14/20.
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

#import "F53OSCClient.h"
#import "F53OSCMessage.h"
#import "F53OSCServer.h"
#import "F53OSCValue.h"


NS_ASSUME_NONNULL_BEGIN

#define PORT_BASE   9200

static NSString *legalAddressCharacters = @"\"$%&'()+-.0123456789:;<=>@ABCDEFGHIJKLMNOPQRSTUVWXYZ\\^_`abcdefghijklmnopqrstuvwxyz|~!";
static NSString *legalWildcardCharacters = @"/*?[]{,}";


@interface F53OSC_MessageTests : XCTestCase <F53OSCServerDelegate, F53OSCClientDelegate>

@property (nonatomic, strong) F53OSCServer *testServer;
@property (nonatomic, strong) F53OSCClient *testClient;

@property (nonatomic, strong) XCTestExpectation *clientConnectExpectation;
@property (nonatomic, strong) NSMutableArray<XCTestExpectation *> *messageExpectations;
@property (nonatomic, strong) NSMutableDictionary<NSString *, F53OSCMessage *> *matchedExpectations;

- (nullable id)oscMessageArgumentFromString:(NSString *)qsc typeTag:(NSString *)typeTag;

@end


@implementation F53OSC_MessageTests

- (void)setUp
{
    [super setUp];

    // set up
    self.clientConnectExpectation = [[XCTestExpectation alloc] initWithDescription:@"F53OSCClient connect"];
    self.messageExpectations = [NSMutableArray array];
    self.matchedExpectations = [NSMutableDictionary dictionary];

    // Avoid port conflicts.
    UInt16 port = PORT_BASE + 10;

    dispatch_queue_t oscQueue = dispatch_queue_create("com.figure53.testServer", DISPATCH_QUEUE_SERIAL);
    F53OSCServer *testServer = [[F53OSCServer alloc] initWithDelegateQueue:oscQueue];
    testServer.delegate = self;
    testServer.port = port;
    testServer.udpReplyPort = port + 1;
    self.testServer = testServer;

    BOOL isListening = [testServer startListening];
    XCTAssertTrue(isListening, @"F53OSCServer was unable to start listening on port %hu", testServer.port);

    F53OSCClient *testClient = [[F53OSCClient alloc] init];
    testClient.useTcp = YES;
    testClient.host = @"localhost";
    testClient.port = port;
    testClient.delegate = self;
    self.testClient = testClient;

    [self connectOSCClientAndVerify];
}

- (void)tearDown
{
    self.testClient.delegate = nil;
    [self.testClient disconnect];

    self.testServer.delegate = nil;
    [self.testServer stopListening];

    [super tearDown];
}

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

- (void)testThat_messageHasCorrectDefaults
{
    F53OSCMessage *message = [[F53OSCMessage alloc] init];

    XCTAssertNotNil(message, @"Message should not be nil");
    XCTAssertNil(message.replySocket, @"Default replySocket should be nil");
    XCTAssertNotNil([message packetData], @"Default packetData should not be nil");
    XCTAssertEqualObjects([message asQSC], @"/", @"Default asQSC should be '/'");
    XCTAssertEqualObjects(message.addressPattern, @"/", @"Default addressPattern should be '/'");
    XCTAssertNotNil(message.typeTagString, @"Default typeTagString should not be nil");
    XCTAssertEqualObjects(message.typeTagString, @",", @"Default typeTagString should be ','");
    XCTAssertNotNil(message.arguments, @"Default arguments should not be nil");
    XCTAssertEqual(message.arguments.count, 0, @"Default arguments should be empty");
    XCTAssertNil(message.userData, @"Default userData should be nil");
    XCTAssertNotNil(message.addressParts, @"Default addressParts should not be nil");
    XCTAssertEqual(message.addressParts.count, 1, @"Default addressParts should have 1 item");
    XCTAssertEqualObjects(message.addressParts[0], @"", @"Default addressParts item should be ''");
}

- (void)testThat_messageCanConfigureProperties
{
    F53OSCMessage *message = [[F53OSCMessage alloc] init];

    GCDAsyncUdpSocket *rawReplySocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:nil delegateQueue:nil];
    F53OSCSocket *replySocket = [F53OSCSocket socketWithUdpSocket:rawReplySocket];
    message.replySocket = replySocket;
    XCTAssertEqualObjects(message.replySocket, replySocket, @"Message replySocket should be %@", replySocket);

    NSString *testAddressPattern = @"/test/address";
    message.addressPattern = testAddressPattern;
    XCTAssertEqualObjects(message.addressPattern, testAddressPattern, @"Message addressPattern should be '%@'", testAddressPattern);

    NSString *testTypeTagString = @",if";
    message.typeTagString = testTypeTagString;
    XCTAssertEqualObjects(message.typeTagString, testTypeTagString, @"Message typeTagString should be '%@'", testTypeTagString);

    NSArray<id> *testArguments = @[@42, @3.14f];
    message.arguments = testArguments;
    XCTAssertEqualObjects(message.arguments, testArguments, @"Message arguments should be %@", testArguments);

    id testUserData = @{@"key": @"value"};
    message.userData = testUserData;
    XCTAssertEqualObjects(message.userData, testUserData, @"Message userData should be %@", testUserData);

    // Equivalent formatter to NSString format methods.
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.roundingMode = NSNumberFormatterRoundHalfUp;
    formatter.numberStyle = NSNumberFormatterDecimalStyle;

    NSMutableString *expectedAsQSC = [NSMutableString stringWithString:testAddressPattern];
    formatter.allowsFloats = ([[testTypeTagString substringWithRange:NSMakeRange(1, 1)] isEqual:@"f"]); // should be NO
    [expectedAsQSC appendFormat:@" %@", [formatter stringFromNumber:testArguments[0]]];
    formatter.allowsFloats = ([[testTypeTagString substringWithRange:NSMakeRange(2, 1)] isEqual:@"f"]); // should be YES
    [expectedAsQSC appendFormat:@" %@", [formatter stringFromNumber:testArguments[1]]];
    XCTAssertEqualObjects(expectedAsQSC, @"/test/address 42 3.14", @"expectedAsQSC should be '/test/address 42 3.14'");
    XCTAssertNotNil([message asQSC], @"Message asQSC should not be nil");
    XCTAssertEqualObjects([message asQSC], expectedAsQSC, @"Message userData should be '%@'", expectedAsQSC);
}

- (void)testThat_messageCanBeCopied
{
    F53OSCMessage *original = [[F53OSCMessage alloc] init];

    GCDAsyncUdpSocket *rawReplySocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:nil delegateQueue:nil];
    F53OSCSocket *replySocket = [F53OSCSocket socketWithUdpSocket:rawReplySocket];
    original.replySocket = replySocket;

    original.addressPattern = @"/test/copy";
    original.arguments = @[@123, @"test string", @2.5f];
    original.userData = @{@"copy": @"test"};

    NSString *expectedTypeTagString = @",isf";
    XCTAssertEqualObjects(original.typeTagString, expectedTypeTagString, @"typeTagString should be '%@'", expectedTypeTagString);

    F53OSCMessage *copy = [original copy];

    XCTAssertNotNil(copy, @"Copy should not be nil");
    XCTAssertNotEqual(copy, original, @"Copy should be a different object");
    XCTAssertEqualObjects(copy.replySocket, original.replySocket, @"replySocket should be copied");
    XCTAssertEqualObjects(copy.addressPattern, original.addressPattern, @"addressPattern should be copied");
    XCTAssertEqualObjects(copy.typeTagString, original.typeTagString, @"typeTagString should be copied");
    XCTAssertEqualObjects(copy.arguments, original.arguments, @"arguments should be copied");
    XCTAssertEqualObjects(copy.userData, original.userData, @"userData should be copied");
    XCTAssertEqualObjects([copy asQSC], [original asQSC], @"asQSC should be equal");
}

- (void)testThat_messageSupportsNSSecureCoding
{
    F53OSCMessage *message = [[F53OSCMessage alloc] init];

    // Configure message with non-default values.
    GCDAsyncUdpSocket *rawReplySocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:nil delegateQueue:nil];
    F53OSCSocket *replySocket = [F53OSCSocket socketWithUdpSocket:rawReplySocket];
    message.replySocket = replySocket;

    message.addressPattern = @"/test/secure/coding";
    message.arguments = @[@"secure test", @3.14f, @42];
    message.userData = @{@"secure": @"coding"};

    NSString *expectedTypeTagString = @",sfi";
    XCTAssertEqualObjects(message.typeTagString, expectedTypeTagString, @"typeTagString should be '%@'", expectedTypeTagString);

    NSError *error = nil;

    // Encode and decode.
    NSData *archivedData = [NSKeyedArchiver archivedDataWithRootObject:message requiringSecureCoding:YES error:&error];
    XCTAssertNotNil(archivedData, @"Should be able to archive message as data");
    XCTAssertNil(error, @"Should be able to archive message without error");

    F53OSCMessage *unarchivedMessage = [NSKeyedUnarchiver unarchivedObjectOfClass:[F53OSCMessage class] fromData:archivedData error:&error];
    XCTAssertNotNil(unarchivedMessage, @"Should be able to unarchive message from data");
    XCTAssertNil(error, @"Should be able to unarchive message without error");

    // Verify all properties were preserved.
    XCTAssertNotNil(unarchivedMessage, @"Unarchived message should not be nil");
    XCTAssertNotEqual(unarchivedMessage, message, @"Unarchived message should be a different object");
    XCTAssertNil(unarchivedMessage.replySocket, @"replySocket should be nil"); // transient, not archived
    XCTAssertEqualObjects([unarchivedMessage packetData], [message packetData], @"addressPattern should be preserved");
    XCTAssertEqualObjects(unarchivedMessage.addressPattern, message.addressPattern, @"addressPattern should be preserved");
    XCTAssertEqualObjects(unarchivedMessage.typeTagString, message.typeTagString, @"typeTagString should be preserved");
    XCTAssertEqualObjects(unarchivedMessage.arguments, message.arguments, @"arguments should be preserved");
    XCTAssertNil(unarchivedMessage.userData, @"userData should be nil");// transient, not archived
}

- (void)testThat_messageIsEqualComparesCorrectly
{
    F53OSCMessage *message1 = [F53OSCMessage messageWithAddressPattern:@"/test" arguments:@[@"arg1", @(42)]];
    F53OSCMessage *message2 = [F53OSCMessage messageWithAddressPattern:@"/test" arguments:@[@"arg1", @(42)]];
    F53OSCMessage *message3 = [F53OSCMessage messageWithAddressPattern:@"/different" arguments:@[@"arg1", @(42)]];
    F53OSCMessage *message4 = [F53OSCMessage messageWithAddressPattern:@"/test" arguments:@[@"different", @(42)]];

    // Test equality.
    XCTAssertTrue([message1 isEqual:message2], @"Messages with same address and arguments should be equal");
    XCTAssertTrue([message2 isEqual:message1], @"Equality should be symmetric");

    // Test inequality.
    XCTAssertFalse([message1 isEqual:message3], @"Messages with different addresses should not be equal");
    XCTAssertFalse([message1 isEqual:message4], @"Messages with different arguments should not be equal");

    // Test with non-message object.
    XCTAssertFalse([message1 isEqual:@"not a message"], @"Message should not equal non-message object");
    XCTAssertFalse([message1 isEqual:nil], @"Message should not equal nil");
}

- (void)testThat_messageDescriptionWorks
{
    // Test data: [address, arguments, expected description]
    NSArray<NSArray<id> *> *testCases = @[
        // No arguments
        @[@"/test", @[], @"/test"],

        // Single arguments of each type
        @[@"/string", @[@"hello"], @"/string \"hello\""],
        @[@"/int", @[@42], @"/int 42"],
        @[@"/float", @[@3.14f], @"/float 3.14"],
        @[@"/float_whole", @[@5.0], @"/float_whole 5"],
        @[@"/blob", @[[@"data" dataUsingEncoding:NSUTF8StringEncoding]], @"/blob {length = 4, bytes = 0x64617461}"],
        @[@"/true", @[[F53OSCValue oscTrue]], @"/true \\T"],
        @[@"/false", @[[F53OSCValue oscFalse]], @"/false \\F"],
        @[@"/null", @[[F53OSCValue oscNull]], @"/null \\N"],
        @[@"/impulse", @[[F53OSCValue oscImpulse]], @"/impulse \\I"],

        // Multiple arguments
        @[@"/mixed", @[@"hello", @42, @3.14f, [F53OSCValue oscTrue]], @"/mixed \"hello\" 42 3.14 \\T"],
        @[@"/all_types", @[@"s", @123, @4.56f, [@"b" dataUsingEncoding:NSUTF8StringEncoding], [F53OSCValue oscTrue], [F53OSCValue oscFalse], [F53OSCValue oscNull], [F53OSCValue oscImpulse]], @"/all_types \"s\" 123 4.56 {length = 1, bytes = 0x62} \\T \\F \\N \\I"],

        // Edge cases
        @[@"/empty_string", @[@""], @"/empty_string \"\""],
        @[@"/quotes", @[@"say \"hi\""], @"/quotes \"say \"hi\"\""],
        @[@"/floats", @[@1.0f, @2.5f, @0.0f, @-3.14f], @"/floats 1 2.5 0 -3.14"],
    ];
    for (NSArray<id> *testCase in testCases)
    {
        NSString *address = testCase[0];
        NSArray<id> *arguments = testCase[1];
        NSString *expected = testCase[2];

        F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:address arguments:arguments];
        XCTAssertEqualObjects([message description], expected, @"Failed for address: %@", address);
    }

    // Type tag mismatch cases
    F53OSCMessage *fewerArgs = [F53OSCMessage messageWithAddressPattern:@"/fewer" arguments:@[@"hello"]];
    fewerArgs.typeTagString = @",sif";
    XCTAssertEqualObjects([fewerArgs description], @"/fewer \"hello\"");

    F53OSCMessage *moreArgs = [F53OSCMessage messageWithAddressPattern:@"/more" arguments:@[@"hello", @42, @3.14f]];
    moreArgs.typeTagString = @",s";
    XCTAssertEqualObjects([moreArgs description], @"/more \"hello\" 42 3.14");
}

- (void)testThat_messageArgumentsFiltersInvalidArguments
{
    F53OSCMessage *message = [[F53OSCMessage alloc] init];
    message.addressPattern = @"/test";

    // Create array with mix of valid and invalid arguments.
    NSArray *mixedArgs = @[
        @"valid string",           // valid
        @(42),                     // valid
        [NSDate date],             // invalid - should be filtered out
        @(3.14f),                  // valid
        [F53OSCValue oscTrue],     // valid
        [NSNull null]              // invalid - should be filtered out
    ];

    [message setArguments:mixedArgs];

    // Should only have the valid arguments.
    XCTAssertEqual(message.arguments.count, 4, @"Should filter out invalid arguments");
    XCTAssertEqualObjects(message.arguments[0], @"valid string", @"First valid argument should remain");
    XCTAssertEqualObjects(message.arguments[1], @(42), @"Second valid argument should remain");
    XCTAssertEqualObjects(message.arguments[2], @(3.14f), @"Third valid argument should remain");
    XCTAssertEqualObjects(message.arguments[3], [F53OSCValue oscTrue], @"Fourth valid argument should remain");

    // Check type tag string is updated correctly.
    XCTAssertEqualObjects(message.typeTagString, @",sifT", @"Type tag should reflect filtered arguments");
}

- (void)testThat_messageAddressPatternParsesVariousAddresses
{
    // Test normal OSC address.
    F53OSCMessage *message1 = [[F53OSCMessage alloc] init];
    message1.addressPattern = @"/one/two/three";
    NSArray *parts1 = [message1 addressParts];
    NSArray *expected1 = @[@"one", @"two", @"three"];
    XCTAssertEqualObjects(parts1, expected1, @"Should correctly parse normal address parts");

    // Test single part address.
    F53OSCMessage *message2 = [[F53OSCMessage alloc] init];
    message2.addressPattern = @"/single";
    NSArray *parts2 = [message2 addressParts];
    NSArray *expected2 = @[@"single"];
    XCTAssertEqualObjects(parts2, expected2, @"Should correctly parse single part address");

    // Test root address.
    F53OSCMessage *message3 = [[F53OSCMessage alloc] init];
    message3.addressPattern = @"/";
    NSArray *parts3 = [message3 addressParts];
    NSArray *expected3 = @[@""];
    XCTAssertEqualObjects(parts3, expected3, @"Root address should return empty string part");

    // Test caching - second call should return same object.
    NSArray *parts1Again = [message1 addressParts];
    XCTAssertTrue(parts1 == parts1Again, @"Pointer equality, address parts should be cached");

    // Test control message (starts with !).
    F53OSCMessage *controlMessage = [[F53OSCMessage alloc] init];
    controlMessage.addressPattern = @"!control/message";
    NSArray *controlParts = [controlMessage addressParts];
    // This should log an error but still return parts.
    XCTAssertNotNil(controlParts, @"Control message should still return address parts");
}

- (void)testThat_messageTagForArgumentHandlesAllArgumentTypes
{
    NSString *tag;

    // Test NSString argument.
    tag = [F53OSCMessage tagForArgument:@"test string"];
    XCTAssertEqualObjects(tag, @"s", @"String argument should return 's' tag");

    // Test integer NSNumber arguments.
    tag = [F53OSCMessage tagForArgument:@(42)];
    XCTAssertEqualObjects(tag, @"i", @"Integer argument should return 'i' tag");

    tag = [F53OSCMessage tagForArgument:[NSNumber numberWithChar:'A']];
    XCTAssertEqualObjects(tag, @"i", @"Char argument should return 'i' tag");

    tag = [F53OSCMessage tagForArgument:[NSNumber numberWithShort:123]];
    XCTAssertEqualObjects(tag, @"i", @"Short argument should return 'i' tag");

    tag = [F53OSCMessage tagForArgument:[NSNumber numberWithLong:1234567L]];
    XCTAssertEqualObjects(tag, @"i", @"Long argument should return 'i' tag");

    tag = [F53OSCMessage tagForArgument:[NSNumber numberWithLongLong:1234567890123456789LL]];
    XCTAssertEqualObjects(tag, @"i", @"Long long argument should return 'i' tag");

    // Test float/double NSNumber arguments.
    tag = [F53OSCMessage tagForArgument:@(3.14f)];
    XCTAssertEqualObjects(tag, @"f", @"Float argument should return 'f' tag");

    tag = [F53OSCMessage tagForArgument:@(2.71828)];
    XCTAssertEqualObjects(tag, @"f", @"Double argument should return 'f' tag");

    // Test all CFNumberType enum values.
    // Fixed-width types.
    int8_t sint8Value = -42;
    NSNumber *sint8Number = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt8Type, &sint8Value);
    tag = [F53OSCMessage tagForArgument:sint8Number];
    XCTAssertEqualObjects(tag, @"i", @"SInt8 should return 'i' tag");

    int16_t sint16Value = -1234;
    NSNumber *sint16Number = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt16Type, &sint16Value);
    tag = [F53OSCMessage tagForArgument:sint16Number];
    XCTAssertEqualObjects(tag, @"i", @"SInt16 should return 'i' tag");

    int32_t sint32Value = -123456;
    NSNumber *sint32Number = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &sint32Value);
    tag = [F53OSCMessage tagForArgument:sint32Number];
    XCTAssertEqualObjects(tag, @"i", @"SInt32 should return 'i' tag");

    int64_t sint64Value = 876543210987654321LL;
    NSNumber *sint64Number = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt64Type, &sint64Value);
    tag = [F53OSCMessage tagForArgument:sint64Number];
    XCTAssertEqualObjects(tag, @"i", @"SInt64 should return 'i' tag");

    float float32Value = 3.14159f;
    NSNumber *float32Number = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberFloat32Type, &float32Value);
    tag = [F53OSCMessage tagForArgument:float32Number];
    XCTAssertEqualObjects(tag, @"f", @"Float32 should return 'f' tag");

    double float64Value = 2.718281828;
    NSNumber *float64Number = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberFloat64Type, &float64Value);
    tag = [F53OSCMessage tagForArgument:float64Number];
    XCTAssertEqualObjects(tag, @"f", @"Float64 should return 'f' tag");

    // Basic C types.
    char charValue = 'A';
    NSNumber *charNumber = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberCharType, &charValue);
    tag = [F53OSCMessage tagForArgument:charNumber];
    XCTAssertEqualObjects(tag, @"i", @"Char should return 'i' tag");

    short shortValue = 12345;
    NSNumber *shortNumber = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberShortType, &shortValue);
    tag = [F53OSCMessage tagForArgument:shortNumber];
    XCTAssertEqualObjects(tag, @"i", @"Short should return 'i' tag");

    int intValue = 987654321;
    NSNumber *intNumber = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &intValue);
    tag = [F53OSCMessage tagForArgument:intNumber];
    XCTAssertEqualObjects(tag, @"i", @"Int should return 'i' tag");

    long longValue = 1234567890L;
    NSNumber *longNumber = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberLongType, &longValue);
    tag = [F53OSCMessage tagForArgument:longNumber];
    XCTAssertEqualObjects(tag, @"i", @"Long should return 'i' tag");

    long long longLongValue = 876543210987654321LL;
    NSNumber *longLongNumber = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberLongLongType, &longLongValue);
    tag = [F53OSCMessage tagForArgument:longLongNumber];
    XCTAssertEqualObjects(tag, @"i", @"Long long should return 'i' tag");

    float floatValue = 1.414213f;
    NSNumber *floatNumber = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberFloatType, &floatValue);
    tag = [F53OSCMessage tagForArgument:floatNumber];
    XCTAssertEqualObjects(tag, @"f", @"Float should return 'f' tag");

    double doubleValue = 1.732050808;
    NSNumber *doubleNumber = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberDoubleType, &doubleValue);
    tag = [F53OSCMessage tagForArgument:doubleNumber];
    XCTAssertEqualObjects(tag, @"f", @"Double should return 'f' tag");

    // Other types.
    CFIndex cfIndexValue = 54321;
    NSNumber *cfIndexNumber = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberCFIndexType, &cfIndexValue);
    tag = [F53OSCMessage tagForArgument:cfIndexNumber];
    XCTAssertEqualObjects(tag, @"i", @"CFIndex should return 'i' tag");

    NSInteger nsIntegerValue = 246810;
    NSNumber *nsIntegerNumber = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberNSIntegerType, &nsIntegerValue);
    tag = [F53OSCMessage tagForArgument:nsIntegerNumber];
    XCTAssertEqualObjects(tag, @"i", @"NSInteger should return 'i' tag");

    CGFloat cgFloatValue = 1.61803398875;
    NSNumber *cgFloatNumber = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberCGFloatType, &cgFloatValue);
    tag = [F53OSCMessage tagForArgument:cgFloatNumber];
    XCTAssertEqualObjects(tag, @"f", @"CGFloat should return 'f' tag");

    // Test NSData argument.
    NSData *blobData = [@"test blob" dataUsingEncoding:NSUTF8StringEncoding];
    tag = [F53OSCMessage tagForArgument:blobData];
    XCTAssertEqualObjects(tag, @"b", @"Data argument should return 'b' tag");

    // Test F53OSCValue arguments.
    tag = [F53OSCMessage tagForArgument:[F53OSCValue oscTrue]];
    XCTAssertEqualObjects(tag, @"T", @"OSC True should return 'T' tag");

    tag = [F53OSCMessage tagForArgument:[F53OSCValue oscFalse]];
    XCTAssertEqualObjects(tag, @"F", @"OSC False should return 'F' tag");

    tag = [F53OSCMessage tagForArgument:[F53OSCValue oscNull]];
    XCTAssertEqualObjects(tag, @"N", @"OSC Null should return 'N' tag");

    tag = [F53OSCMessage tagForArgument:[F53OSCValue oscImpulse]];
    XCTAssertEqualObjects(tag, @"I", @"OSC Impulse should return 'I' tag");

    // Test unknown argument type.
    tag = [F53OSCMessage tagForArgument:[NSDate date]];
    XCTAssertNil(tag, @"Unknown argument type should return nil");
}


#pragma mark - Message string parsing tests

- (void)testThat_messageWithStringHandlesValidInputs
{
    // Test simple message.
    F53OSCMessage *message1 = [F53OSCMessage messageWithString:@"/test"];
    XCTAssertNotNil(message1, @"Should parse simple address");
    XCTAssertEqualObjects(message1.addressPattern, @"/test", @"Should set correct address");
    XCTAssertEqual(message1.arguments.count, 0, @"Should have no arguments");

    // Test message with arguments.
    F53OSCMessage *message2 = [F53OSCMessage messageWithString:@"/test 42 \"hello\" 3.14"];
    XCTAssertNotNil(message2, @"Should parse message with arguments");
    XCTAssertEqualObjects(message2.addressPattern, @"/test", @"Should set correct address");
    XCTAssertEqual(message2.arguments.count, 3, @"Should have three arguments");

    // Test message with leading/trailing whitespace.
    F53OSCMessage *message3 = [F53OSCMessage messageWithString:@"  /test 42  "];
    XCTAssertNotNil(message3, @"Should handle whitespace");
    XCTAssertEqualObjects(message3.addressPattern, @"/test", @"Should trim whitespace");
}

- (void)testThat_messageWithStringHandlesInvalidInputs
{
    // Test nil input.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    F53OSCMessage *message1 = [F53OSCMessage messageWithString:nil];
#pragma clang diagnostic pop
    XCTAssertNil(message1, @"Should return nil for nil input");

    // Test empty string.
    F53OSCMessage *message2 = [F53OSCMessage messageWithString:@""];
    XCTAssertNil(message2, @"Should return nil for empty string");

    // Test whitespace only.
    F53OSCMessage *message3 = [F53OSCMessage messageWithString:@"   "];
    XCTAssertNil(message3, @"Should return nil for whitespace only");

    // Test invalid address.
    F53OSCMessage *message4 = [F53OSCMessage messageWithString:@"invalid"];
    XCTAssertNil(message4, @"Should return nil for invalid address");

    // Test bundle string (starts with #).
    F53OSCMessage *message5 = [F53OSCMessage messageWithString:@"#bundle"];
    XCTAssertNil(message5, @"Should return nil for bundle string");

    // Test #blob with no content.
    F53OSCMessage *message6 = [F53OSCMessage messageWithString:@"/test #blob"];
    XCTAssertNotNil(message6, @"Should handle #blob with no content");
    XCTAssertEqual(message6.arguments.count, 0, @"Should skip empty blob argument");

    // Test #blob with invalid base64 data.
    F53OSCMessage *message7 = [F53OSCMessage messageWithString:@"/test #blob!@#$%"];
    XCTAssertNotNil(message7, @"Should handle #blob with invalid base64");
    XCTAssertEqual(message7.arguments.count, 0, @"Should skip invalid blob argument");
}

- (void)testThat_messageWithStringParsesQuotationMarks
{
    // given
    NSDictionary<NSString *, NSArray<id> *> *stringsAndExpectedArgs = @{
        // QUOTATION MARK (plain) U+0022
        @"/test/1a \"a\"" : @[@"a"],
        @"/test/1b \"a b\"" : @[@"a b"],
        @"/test/1c \"a\" \"b\"" : @[@"a", @"b"],
        @"/test/1d \"a\" 1 \"b\"" : @[@"a", @1, @"b"],
        @"/test/1e \"a b\" 1 \"c d\"" : @[@"a b", @1, @"c d"],
        @"/test/1f \"a b\" 1.2 \"c d\"" : @[@"a b", @1.2, @"c d"],
        // interior quotes with improper spacing around arg 2, malformed - fails
        @"/test/1g \"a \"b\" c\"" : @[],
        // interior non-escaped quotes with proper spacing around arg 2, valid - A and C args include extra spaces
        @"/test/1h \"a \" b \" c\"" : @[@"a ", @"b", @" c"],
        // interior escaped quotes, valid - single string arg includes quote characters
        @"/test/1i \"a \\\"b\\\" c\"" : @[@"a \"b\" c"],
        @"/test/1j \\\"" : @[@"\""],

        // LEFT/RIGHT DOUBLE QUOTATION MARK (curly) U+201C U+201D
        @"/test/2a “a”" : @[@"a"],
        @"/test/2b \u201ca b\u201d" : @[@"a b"],
        @"/test/2c “a” “b”" : @[@"a", @"b"],
        @"/test/2d “a” 1 “b”" : @[@"a", @1, @"b"],
        @"/test/2e “a b” 1 “c d”" : @[@"a b", @1, @"c d"],
        @"/test/2f “a b” 1.2 “c d”" : @[@"a b", @1.2, @"c d"],

        // QUOTES INSIDE QUOTES
        @"/test/2g \"a “b” c\"" : @[], // no spaces to delineate arg 2, invalid
        @"/test/2h \"normal\" \"\u201Cproblematic\u201D\" \"final\"" : @[], // no spaces to delineate args, invalid
        @"/test/2i \"\\\\\" \"\u201D \\u201C\" \"end\"" : @[], // invalid escaping
        @"/test/2j \"a “ b ” c\"" : @[@"a ", @"b", @" c"], // non-escaped quotes with proper spacing, valid
        @"/test/2k \"normal\" \"\u201C okay \u201D\" \"final\"" : @[@"normal", @"", @"okay", @"", @"final"], // Unicode quotes with proper spacing, valid
        @"/test/2l \"normal\" \"\u201D okay \u201C\" \"final\"" : @[@"normal", @"", @"okay", @"", @"final"], // Flipped Unicode quotes with proper spacing, valid

        // interior escaped quotes, valid - single string arg includes quote characters
        @"/test/2m \"a \\“b\\” c\"" : @[@"a “b” c"],
        @"/test/2m \"a \\\\u201Cb\\\\u201D c\"" : @[@"a \\\\u201Cb\\\\u201D c"], // unicode is not rendered
        @"/test/2n \\“" : @[@"“"],
        @"/test/2o \\”" : @[@"”"],
        @"/test/2p \"first\" \"\\u201C\\\"nested\\\"\\u201D\" \"last\"" : @[@"first", @"\\u201C\"nested\"\\u201D", @"last"],

        // MISMATCHED QUOTES should cause parsing to fail
        @"/test/3a \"unmatched" : @[], // unmatched opening quote
        @"/test/3b unmatched\"" : @[], // unmatched closing quote
        @"/test/3c \"one\" \"two" : @[], // unmatched quotes in multiple arguments
    };

    for (NSString *string in stringsAndExpectedArgs)
    {
        // when
        F53OSCMessage *message = [F53OSCMessage messageWithString:string];

        // then
        NSArray<id> *expectedArgs = stringsAndExpectedArgs[string];
        if (expectedArgs.count == 0) // signals expected error condition
            XCTAssertNil(message, @"%@", string);
        else
        {
            XCTAssertNotNil(message, @"%@", string);
            XCTAssertEqual(message.arguments.count, expectedArgs.count, @"%@", string);
            XCTAssertEqualObjects(message.arguments, expectedArgs, @"%@", string);
        }
    }
}

- (void)testThat_messagePacketDataHandlesAllArgumentTypes
{
    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:@"/test" arguments:@[
        @"string",                    // string
        @(42),                       // integer
        @(3.14f),                    // float
        [@"blob" dataUsingEncoding:NSUTF8StringEncoding], // blob
        [F53OSCValue oscTrue],       // true
        [F53OSCValue oscFalse],      // false
        [F53OSCValue oscNull],       // null
        [F53OSCValue oscImpulse]     // impulse
    ]];

    NSData *packetData = [message packetData];
    XCTAssertNotNil(packetData, @"Should generate packet data for all argument types");
    XCTAssertGreaterThan(packetData.length, 0, @"Packet data should not be empty");

    // Verify it starts with address pattern.
    NSData *addressData = [@"/test" oscStringData];
    NSData *addressPrefix = [packetData subdataWithRange:NSMakeRange(0, addressData.length)];
    XCTAssertEqualObjects(addressPrefix, addressData, @"Packet should start with address data");
}

- (void)testThat_messageAsQSCHandlesAllArgumentTypes
{
    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:@"/test" arguments:@[
        @"string with \"quotes\"",  // string with quotes
        @(42),                      // integer
        @(-17),                     // negative integer
        @(3.14f),                   // float
        [@"test" dataUsingEncoding:NSUTF8StringEncoding], // blob
        [F53OSCValue oscTrue],      // true
        [F53OSCValue oscFalse],     // false
        [F53OSCValue oscNull],      // null
        [F53OSCValue oscImpulse]    // impulse
    ]];

    NSString *qscString = [message asQSC];
    XCTAssertNotNil(qscString, @"Should generate QSC string");

    // Verify it starts with address.
    XCTAssertTrue([qscString hasPrefix:@"/test"], @"QSC string should start with address");

    // Verify quoted string with escaped quotes.
    XCTAssertTrue([qscString containsString:@"\"string with \\\"quotes\\\"\""], @"Should escape quotes in strings");

    // Verify integer.
    XCTAssertTrue([qscString containsString:@" 42"], @"Should include integer argument");
    XCTAssertTrue([qscString containsString:@" -17"], @"Should include negative integer");

    // Verify float.
    XCTAssertTrue([qscString containsString:@"3.14"], @"Should include float argument");

    // Verify blob.
    XCTAssertTrue([qscString containsString:@"#blob"], @"Should include blob argument");

    // Verify OSC values.
    XCTAssertTrue([qscString containsString:@" \\T"], @"Should include true value");
    XCTAssertTrue([qscString containsString:@" \\F"], @"Should include false value");
    XCTAssertTrue([qscString containsString:@" \\N"], @"Should include null value");
    XCTAssertTrue([qscString containsString:@" \\I"], @"Should include impulse value");
}

- (void)testThat_messageWithAddressPatternHandlesAllCFNumberTypeArguments
{
    // Test all CFNumberType enum values with message formatting.

    // Fixed-width types.
    int8_t sint8Value = -42;
    NSNumber *sint8Number = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt8Type, &sint8Value);
    F53OSCMessage *sint8Message = [F53OSCMessage messageWithAddressPattern:@"/test" arguments:@[sint8Number]];
    XCTAssertEqual(sint8Message.typeTagString.length, 2, @"SInt8 message typeTagString should have 2 characters");
    XCTAssertEqualObjects([sint8Message.typeTagString substringWithRange:NSMakeRange(1, 1)], @"i", @"SInt8 should be tagged as integer");
    XCTAssertNotNil([sint8Message packetData], @"SInt8 message should generate valid packet data");
    XCTAssertTrue([[sint8Message asQSC] containsString:@"-42"], @"SInt8 QSC should contain value");

    int16_t sint16Value = -1234;
    NSNumber *sint16Number = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt16Type, &sint16Value);
    F53OSCMessage *sint16Message = [F53OSCMessage messageWithAddressPattern:@"/test" arguments:@[sint16Number]];
    XCTAssertEqual(sint16Message.typeTagString.length, 2, @"SInt16 message typeTagString should have 2 characters");
    XCTAssertEqualObjects([sint16Message.typeTagString substringWithRange:NSMakeRange(1, 1)], @"i", @"SInt16 should be tagged as integer");
    XCTAssertNotNil([sint16Message packetData], @"SInt16 message should generate valid packet data");
    XCTAssertTrue([[sint16Message asQSC] containsString:@"-1234"], @"SInt16 QSC should contain value");

    int32_t sint32Value = -123456;
    NSNumber *sint32Number = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &sint32Value);
    F53OSCMessage *sint32Message = [F53OSCMessage messageWithAddressPattern:@"/test" arguments:@[sint32Number]];
    XCTAssertEqual(sint32Message.typeTagString.length, 2, @"SInt32 message typeTagString should have 2 characters");
    XCTAssertEqualObjects([sint32Message.typeTagString substringWithRange:NSMakeRange(1, 1)], @"i", @"SInt32 should be tagged as integer");
    XCTAssertNotNil([sint32Message packetData], @"SInt32 message should generate valid packet data");
    XCTAssertTrue([[sint32Message asQSC] containsString:@"-123456"], @"SInt32 QSC should contain value");

    int64_t sint64Value = 876543210987654321LL;
    NSNumber *sint64Number = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt64Type, &sint64Value);
    F53OSCMessage *sint64Message = [F53OSCMessage messageWithAddressPattern:@"/test" arguments:@[sint64Number]];
    XCTAssertEqual(sint64Message.typeTagString.length, 2, @"SInt64 message typeTagString should have 2 characters");
    XCTAssertEqualObjects([sint64Message.typeTagString substringWithRange:NSMakeRange(1, 1)], @"i", @"SInt64 should be tagged as integer");
    XCTAssertNotNil([sint64Message packetData], @"SInt64 message should generate valid packet data");
    // QSC will show truncated 32-bit value.
    NSString *sint64QSC = [sint64Message asQSC];
    XCTAssertNotNil(sint64QSC, @"SInt64 QSC should be generated");

    float float32Value = 3.14159f;
    NSNumber *float32Number = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberFloat32Type, &float32Value);
    F53OSCMessage *float32Message = [F53OSCMessage messageWithAddressPattern:@"/test" arguments:@[float32Number]];
    XCTAssertEqual(float32Message.typeTagString.length, 2, @"Float32 message typeTagString should have 2 characters");
    XCTAssertEqualObjects([float32Message.typeTagString substringWithRange:NSMakeRange(1, 1)], @"f", @"Float32 should be tagged as float");
    XCTAssertNotNil([float32Message packetData], @"Float32 message should generate valid packet data");
    XCTAssertTrue([[float32Message asQSC] containsString:@"3.14"], @"Float32 QSC should contain value");

    double float64Value = 2.718281828;
    NSNumber *float64Number = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberFloat64Type, &float64Value);
    F53OSCMessage *float64Message = [F53OSCMessage messageWithAddressPattern:@"/test" arguments:@[float64Number]];
    XCTAssertEqual(float64Message.typeTagString.length, 2, @"Float64 message typeTagString should have 2 characters");
    XCTAssertEqualObjects([float64Message.typeTagString substringWithRange:NSMakeRange(1, 1)], @"f", @"Float64 should be tagged as float");
    XCTAssertNotNil([float64Message packetData], @"Float64 message should generate valid packet data");
    XCTAssertTrue([[float64Message asQSC] containsString:@"2.71"], @"Float64 QSC should contain truncated value");

    // Basic C types.
    char charValue = 'A';
    NSNumber *charNumber = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberCharType, &charValue);
    F53OSCMessage *charMessage = [F53OSCMessage messageWithAddressPattern:@"/test" arguments:@[charNumber]];
    XCTAssertEqual(charMessage.typeTagString.length, 2, @"Char message typeTagString should have 2 characters");
    XCTAssertEqualObjects([charMessage.typeTagString substringWithRange:NSMakeRange(1, 1)], @"i", @"Char should be tagged as integer");
    XCTAssertNotNil([charMessage packetData], @"Char message should generate valid packet data");
    XCTAssertTrue([[charMessage asQSC] containsString:@"65"], @"Char QSC should contain ASCII value");

    short shortValue = 12345;
    NSNumber *shortNumber = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberShortType, &shortValue);
    F53OSCMessage *shortMessage = [F53OSCMessage messageWithAddressPattern:@"/test" arguments:@[shortNumber]];
    XCTAssertEqual(shortMessage.typeTagString.length, 2, @"Short message typeTagString should have 2 characters");
    XCTAssertEqualObjects([shortMessage.typeTagString substringWithRange:NSMakeRange(1, 1)], @"i", @"Short should be tagged as integer");
    XCTAssertNotNil([shortMessage packetData], @"Short message should generate valid packet data");
    XCTAssertTrue([[shortMessage asQSC] containsString:@"12345"], @"Short QSC should contain value");

    int intValue = 987654321;
    NSNumber *intNumber = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &intValue);
    F53OSCMessage *intMessage = [F53OSCMessage messageWithAddressPattern:@"/test" arguments:@[intNumber]];
    XCTAssertEqual(intMessage.typeTagString.length, 2, @"Int message typeTagString should have 2 characters");
    XCTAssertEqualObjects([intMessage.typeTagString substringWithRange:NSMakeRange(1, 1)], @"i", @"Int should be tagged as integer");
    XCTAssertNotNil([intMessage packetData], @"Int message should generate valid packet data");
    XCTAssertTrue([[intMessage asQSC] containsString:@"987654321"], @"Int QSC should contain value");

    long longValue = 1234567890L;
    NSNumber *longNumber = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberLongType, &longValue);
    F53OSCMessage *longMessage = [F53OSCMessage messageWithAddressPattern:@"/test" arguments:@[longNumber]];
    XCTAssertEqual(longMessage.typeTagString.length, 2, @"Long message typeTagString should have 2 characters");
    XCTAssertEqualObjects([longMessage.typeTagString substringWithRange:NSMakeRange(1, 1)], @"i", @"Long should be tagged as integer");
    XCTAssertNotNil([longMessage packetData], @"Long message should generate valid packet data");
    XCTAssertTrue([[longMessage asQSC] containsString:@"1234567890"], @"Long QSC should contain value");

    long long longLongValue = 876543210987654321LL;
    NSNumber *longLongNumber = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberLongLongType, &longLongValue);
    F53OSCMessage *longLongMessage = [F53OSCMessage messageWithAddressPattern:@"/test" arguments:@[longLongNumber]];
    XCTAssertEqual(longLongMessage.typeTagString.length, 2, @"Long long message typeTagString should have 2 characters");
    XCTAssertEqualObjects([longLongMessage.typeTagString substringWithRange:NSMakeRange(1, 1)], @"i", @"Long long should be tagged as integer");
    XCTAssertNotNil([longLongMessage packetData], @"Long long message should generate valid packet data");
    // QSC will show truncated 32-bit value.
    NSString *longLongQSC = [longLongMessage asQSC];
    XCTAssertNotNil(longLongQSC, @"Long long QSC should be generated");

    float floatValue = 1.414213f;
    NSNumber *floatNumber = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberFloatType, &floatValue);
    F53OSCMessage *floatMessage = [F53OSCMessage messageWithAddressPattern:@"/test" arguments:@[floatNumber]];
    XCTAssertEqual(floatMessage.typeTagString.length, 2, @"Float message typeTagString should have 2 characters");
    XCTAssertEqualObjects([floatMessage.typeTagString substringWithRange:NSMakeRange(1, 1)], @"f", @"Float should be tagged as float");
    XCTAssertNotNil([floatMessage packetData], @"Float message should generate valid packet data");
    XCTAssertTrue([[floatMessage asQSC] containsString:@"1.41"], @"Float QSC should contain value");

    double doubleValue = 1.732050808;
    NSNumber *doubleNumber = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberDoubleType, &doubleValue);
    F53OSCMessage *doubleMessage = [F53OSCMessage messageWithAddressPattern:@"/test" arguments:@[doubleNumber]];
    XCTAssertEqual(doubleMessage.typeTagString.length, 2, @"Double message typeTagString should have 2 characters");
    XCTAssertEqualObjects([doubleMessage.typeTagString substringWithRange:NSMakeRange(1, 1)], @"f", @"Double should be tagged as float");
    XCTAssertNotNil([doubleMessage packetData], @"Double message should generate valid packet data");
    XCTAssertTrue([[doubleMessage asQSC] containsString:@"1.73"], @"Double QSC should contain truncated value");

    // Other types.
    CFIndex cfIndexValue = 54321;
    NSNumber *cfIndexNumber = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberCFIndexType, &cfIndexValue);
    F53OSCMessage *cfIndexMessage = [F53OSCMessage messageWithAddressPattern:@"/test" arguments:@[cfIndexNumber]];
    XCTAssertEqual(cfIndexMessage.typeTagString.length, 2, @"CFIndex message typeTagString should have 2 characters");
    XCTAssertEqualObjects([cfIndexMessage.typeTagString substringWithRange:NSMakeRange(1, 1)], @"i", @"CFIndex should be tagged as integer");
    XCTAssertNotNil([cfIndexMessage packetData], @"CFIndex message should generate valid packet data");
    XCTAssertTrue([[cfIndexMessage asQSC] containsString:@"54321"], @"CFIndex QSC should contain value");

    NSInteger nsIntegerValue = 246810;
    NSNumber *nsIntegerNumber = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberNSIntegerType, &nsIntegerValue);
    F53OSCMessage *nsIntegerMessage = [F53OSCMessage messageWithAddressPattern:@"/test" arguments:@[nsIntegerNumber]];
    XCTAssertEqual(nsIntegerMessage.typeTagString.length, 2, @"NSInteger message typeTagString should have 2 characters");
    XCTAssertEqualObjects([nsIntegerMessage.typeTagString substringWithRange:NSMakeRange(1, 1)], @"i", @"NSInteger should be tagged as integer");
    XCTAssertNotNil([nsIntegerMessage packetData], @"NSInteger message should generate valid packet data");
    XCTAssertTrue([[nsIntegerMessage asQSC] containsString:@"246810"], @"NSInteger QSC should contain value");

    CGFloat cgFloatValue = 1.61803398875;
    NSNumber *cgFloatNumber = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberCGFloatType, &cgFloatValue);
    F53OSCMessage *cgFloatMessage = [F53OSCMessage messageWithAddressPattern:@"/test" arguments:@[cgFloatNumber]];
    XCTAssertEqual(cgFloatMessage.typeTagString.length, 2, @"CGFloat message typeTagString should have 2 characters");
    XCTAssertEqualObjects([cgFloatMessage.typeTagString substringWithRange:NSMakeRange(1, 1)], @"f", @"CGFloat should be tagged as float");
    XCTAssertNotNil([cgFloatMessage packetData], @"CGFloat message should generate valid packet data");
    XCTAssertTrue([[cgFloatMessage asQSC] containsString:@"1.61"], @"CGFloat QSC should contain value");
}

- (void)testThat_messageWithAddressPatternRoundTripsAllCFNumberTypesArguments
{
    // Test round-trip functionality for all CFNumberType enum values through OSC messages.

    // Create a message with all number types.
    int8_t sint8Value = -42;
    NSNumber *sint8Number = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt8Type, &sint8Value);

    int32_t sint32Value = -123456;
    NSNumber *sint32Number = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &sint32Value);

    float float32Value = 3.14159f;
    NSNumber *float32Number = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberFloat32Type, &float32Value);

    double float64Value = 2.718281828;
    NSNumber *float64Number = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberFloat64Type, &float64Value);

    char charValue = 'Z';
    NSNumber *charNumber = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberCharType, &charValue);

    short shortValue = 12345;
    NSNumber *shortNumber = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberShortType, &shortValue);

    long longValue = 1234567890L;
    NSNumber *longNumber = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberLongType, &longValue);

    long long longLongValue = 876543210987654321LL;
    NSNumber *longLongNumber = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberLongLongType, &longLongValue);

    CGFloat cgFloatValue = 1.61803398875;
    NSNumber *cgFloatNumber = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberCGFloatType, &cgFloatValue);

    // Create message with mixed number types.
    NSArray *mixedArguments = @[sint8Number, sint32Number, float32Number, float64Number, charNumber, shortNumber, longNumber, longLongNumber, cgFloatNumber];
    F53OSCMessage *mixedMessage = [F53OSCMessage messageWithAddressPattern:@"/mixed" arguments:mixedArguments];

    // Verify type tags are correct.
    // sint8, sint32, float32, float64, char, short, long, long long, cgFloat
    NSString *expectedTypeTag = @",iiffiiiif";
    XCTAssertEqualObjects(mixedMessage.typeTagString, expectedTypeTag, @"Mixed message should have correct type tag string");

    // Verify packet data can be generated.
    NSData *packetData = [mixedMessage packetData];
    XCTAssertNotNil(packetData, @"Mixed message should generate valid packet data");

    // Address pattern + type tag string + arguments (9 * 4 bytes each)
    NSUInteger expectedLength = 8 + 12 + 36;
    XCTAssertEqual(packetData.length, expectedLength, @"Packet data should be expected length");

    // Verify QSC string format.
    NSString *qscString = [mixedMessage asQSC];
    XCTAssertNotNil(qscString, @"Mixed message should generate QSC string");
    XCTAssertTrue([qscString hasPrefix:@"/mixed"], @"QSC should start with address pattern");
    XCTAssertTrue([qscString containsString:@"-42"], @"QSC should contain sint8 value");
    XCTAssertTrue([qscString containsString:@"-123456"], @"QSC should contain sint32 value");
    XCTAssertTrue([qscString containsString:@"3.14"], @"QSC should contain float32 value");
    XCTAssertTrue([qscString containsString:@"2.71"], @"QSC should contain float64 value");
    XCTAssertTrue([qscString containsString:@"90"], @"QSC should contain char ASCII value");
    XCTAssertTrue([qscString containsString:@"12345"], @"QSC should contain short value");
    XCTAssertTrue([qscString containsString:@"1234567890"], @"QSC should contain long value");
    XCTAssertTrue([qscString containsString:@"876543210987654321"], @"QSC should contain long long value");
    XCTAssertTrue([qscString containsString:@"1.61"], @"QSC should contain CGFloat value");

    // Verify message equality works with CFNumber types.
    F53OSCMessage *duplicateMessage = [F53OSCMessage messageWithAddressPattern:@"/mixed" arguments:mixedArguments];
    XCTAssertNotEqual(mixedMessage, duplicateMessage, @"Messages with identical CFNumber arguments should be different objects");
    XCTAssertEqualObjects(mixedMessage, duplicateMessage, @"Messages with identical CFNumber arguments should be equal");
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
    F53OSCMessage *message = [F53OSCMessage messageWithString:address];
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
    F53OSCMessage *message = [F53OSCMessage messageWithString:qsc];
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
    F53OSCMessage *message = [F53OSCMessage messageWithString:qsc];
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
    F53OSCMessage *message = [F53OSCMessage messageWithString:qsc];
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
    F53OSCMessage *message = [F53OSCMessage messageWithString:qsc];
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
    F53OSCMessage *message = [F53OSCMessage messageWithString:qsc];
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
    F53OSCMessage *message = [F53OSCMessage messageWithString:qsc];
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
    F53OSCMessage *message = [F53OSCMessage messageWithString:qsc];
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
    F53OSCMessage *message = [F53OSCMessage messageWithString:qsc];
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
    F53OSCMessage *message = [F53OSCMessage messageWithString:qsc];
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
    F53OSCMessage *message = [F53OSCMessage messageWithString:qsc];
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
    F53OSCMessage *message = [F53OSCMessage messageWithString:qsc];
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


#pragma mark - Message string validation tests

- (void)testThat_legalAddressCharactersForTestCaseMatchesServerValidChars
{
    NSString *validCharsForOSCMethod = [F53OSCServer validCharsForOSCMethod];
    XCTAssertNotNil(validCharsForOSCMethod);
    XCTAssertEqual(validCharsForOSCMethod.length, legalAddressCharacters.length);

    // Test membership, order of actual characters may be different.
    for (NSUInteger i = 0; i < validCharsForOSCMethod.length; i++)
        XCTAssertTrue([legalAddressCharacters containsString:[validCharsForOSCMethod substringWithRange:NSMakeRange(i, 1)]]);
    for (NSUInteger i = 0; i < legalAddressCharacters.length; i++)
        XCTAssertTrue([validCharsForOSCMethod containsString:[legalAddressCharacters substringWithRange:NSMakeRange(i, 1)]]);
}

- (void)testThat_legalAddressComponentWorks
{
    XCTAssertTrue([F53OSCMessage legalAddressComponent:@"test"], @"Basic component should be valid");
    XCTAssertTrue([F53OSCMessage legalAddressComponent:@"hello"], @"Basic component should be valid");
    XCTAssertTrue([F53OSCMessage legalAddressComponent:@"world1"], @"Component with a number should be valid");
    XCTAssertTrue([F53OSCMessage legalAddressComponent:@"world123"], @"Component with numbers should be valid");
    XCTAssertTrue([F53OSCMessage legalAddressComponent:@"Component1"], @"Component starting with uppercase should be valid");
    XCTAssertTrue([F53OSCMessage legalAddressComponent:@"component1"], @"Component starting with lowercase should be valid");
    XCTAssertTrue([F53OSCMessage legalAddressComponent:@"COMPONENT"], @"All uppercase component should be valid");
    XCTAssertTrue([F53OSCMessage legalAddressComponent:@"cOMPONENT"], @"Mixed case component should be valid");
    XCTAssertTrue([F53OSCMessage legalAddressComponent:@"getOscillator4Frequency"], @"Complex component should be valid");

    XCTAssertTrue([F53OSCMessage legalAddressComponent:@"cue"], @"cue component should be valid");
    XCTAssertTrue([F53OSCMessage legalAddressComponent:@"track"], @"track component should be valid");
    XCTAssertTrue([F53OSCMessage legalAddressComponent:@"ch01"], @"ch01 component should be valid");
    XCTAssertTrue([F53OSCMessage legalAddressComponent:@"osc1"], @"osc1 component should be valid");

    XCTAssertTrue([F53OSCMessage legalAddressComponent:@"123"], @"Numeric component should be valid");
    XCTAssertTrue([F53OSCMessage legalAddressComponent:@"0"], @"Single digit component should be valid");
    XCTAssertTrue([F53OSCMessage legalAddressComponent:@"1test"], @"Component starting with a number should be valid");

    NSString *validCharacters = [legalAddressCharacters stringByAppendingString:legalWildcardCharacters];

    // Test full ASCII range: 0-127 (0x00-0x7F)
    // TODO: Test that extended characters are rejected.
    for (unichar c = 0; c < 127; c++)
    {
        NSString *character = [NSString stringWithCharacters:&c length:1];
        BOOL valid = [validCharacters containsString:character];

        NSString *address;

        address = [NSString stringWithFormat:@"test%@character", character];
        if (valid)
            XCTAssertTrue([F53OSCMessage legalAddressComponent:address], @"Component containing '%@' should be valid", character);
        else
            XCTAssertFalse([F53OSCMessage legalAddressComponent:address], @"Component containing '%@' should not be valid", character);
    }

    // OSC spec prohibits certain characters.
    XCTAssertFalse([F53OSCMessage legalAddressComponent:@"test space"], @"Component with a space should be invalid");
    XCTAssertFalse([F53OSCMessage legalAddressComponent:@"test#hash"], @"Component with a hash should be invalid");

    // Test edge ASCII characters.
    XCTAssertFalse([F53OSCMessage legalAddressComponent:@"test\t"], @"Component with a tab should be invalid");
    XCTAssertFalse([F53OSCMessage legalAddressComponent:@"test\n"], @"Component with a newline should be invalid");
    XCTAssertFalse([F53OSCMessage legalAddressComponent:@"test\r"], @"Component with a carriage return should be invalid");
    XCTAssertFalse([F53OSCMessage legalAddressComponent:@"test\0"], @"Component with a null character should be invalid");

    XCTAssertFalse([F53OSCMessage legalAddressComponent:nil], @"nil component should be invalid");
    XCTAssertFalse([F53OSCMessage legalAddressComponent:@""], @"Empty component should be invalid");

    // Test various Unicode characters.
    XCTAssertFalse([F53OSCMessage legalAddressComponent:@"tëst"], @"Component with accented characters should be invalid");
    XCTAssertFalse([F53OSCMessage legalAddressComponent:@"тест"], @"Component with Cyrillic characters should be invalid");
    XCTAssertFalse([F53OSCMessage legalAddressComponent:@"测试"], @"Component with Chinese characters should be invalid");
    XCTAssertFalse([F53OSCMessage legalAddressComponent:@"🎵"], @"Component with emoji should be invalid");
    XCTAssertFalse([F53OSCMessage legalAddressComponent:@"café"], @"Component with accented e should be invalid");

    // Very long component should be valid (no length limit).
    NSMutableString *longComponent = [NSMutableString string];
    for (int i = 0; i < 10000; i++)
        [longComponent appendString:@"a"];
    XCTAssertTrue([F53OSCMessage legalAddressComponent:longComponent], @"Long component (10000 chars) should be valid");
}

- (void)testThat_legalAddressWorks
{
    XCTAssertTrue([F53OSCMessage legalAddress:@"/test"], @"Simple address should be valid");
    XCTAssertTrue([F53OSCMessage legalAddress:@"/test/path"], @"Multi-part address should be valid");
    XCTAssertTrue([F53OSCMessage legalAddress:@"/test/deep/path/structure"], @"Deep address should be valid");
    XCTAssertTrue([F53OSCMessage legalAddress:@"/1/2/3"], @"Numeric address parts should be valid");
    XCTAssertTrue([F53OSCMessage legalAddress:@"/test_path"], @"Address with underscore should be valid");
    XCTAssertTrue([F53OSCMessage legalAddress:@"/test-path"], @"Address with hyphen should be valid");

    XCTAssertTrue([F53OSCMessage legalAddress:@"/cue/1/start"], @"QLab-style address should be valid");
    XCTAssertTrue([F53OSCMessage legalAddress:@"/mixer/ch01/fader"], @"Mixer-style address should be valid");
    XCTAssertTrue([F53OSCMessage legalAddress:@"/synth/osc*/freq"], @"Synthesizer wildcard address should be valid");

    XCTAssertTrue([F53OSCMessage legalAddress:@"/"], @"Root address alone should be valid");
    XCTAssertTrue([F53OSCMessage legalAddress:@"//test"], @"Address with double slash should be valid");
    XCTAssertTrue([F53OSCMessage legalAddress:@"/test/"], @"Address ending with slash should be valid");
    XCTAssertTrue([F53OSCMessage legalAddress:@"/test//path"], @"Address with double slash in middle should be valid");

    NSString *validCharacters = [legalAddressCharacters stringByAppendingString:legalWildcardCharacters];

    // Test full ASCII range: 0-127 (0x00-0x7F)
    // TODO: Test that extended characters are rejected.
    for (unichar c = 0; c < 127; c++)
    {
        NSString *character = [NSString stringWithCharacters:&c length:1];
        BOOL valid = [validCharacters containsString:character];

        NSString *address;

        address = [NSString stringWithFormat:@"/test%@character", character];
        if (valid)
            XCTAssertTrue([F53OSCMessage legalAddress:address], @"Address containing '%@' should be valid", character);
        else
            XCTAssertFalse([F53OSCMessage legalAddress:address], @"Address containing '%@' should not be valid", character);

        address = [NSString stringWithFormat:@"/test%@character/path", character];
        if (valid)
            XCTAssertTrue([F53OSCMessage legalAddress:address], @"Address containing '%@' should be valid", character);
        else
            XCTAssertFalse([F53OSCMessage legalAddress:address], @"Address containing '%@' should not be valid", character);

        address = [NSString stringWithFormat:@"/test/%@/character/path", character];
        if (valid)
            XCTAssertTrue([F53OSCMessage legalAddress:address], @"Address with '%@' component should be valid", character);
        else
            XCTAssertFalse([F53OSCMessage legalAddress:address], @"Address containing '%@' should not not be valid", character);
    }

    // Test OSC wildcard characters in address patterns.
    XCTAssertTrue([F53OSCMessage legalAddress:@"/test[abc]"], @"Address with character class should be valid");
    XCTAssertTrue([F53OSCMessage legalAddress:@"/test[0-9]"], @"Address with numeric range should be valid");
    XCTAssertTrue([F53OSCMessage legalAddress:@"/test{foo,bar}"], @"Address with string alternatives should be valid");
    XCTAssertTrue([F53OSCMessage legalAddress:@"/test*/path?"], @"Address with multiple wildcards should be valid");

    // The implementation doesn't validate wildcard structure - it just checks if characters are legal.
    // These are all valid from a character perspective, though they may not function as intended wildcards.
    XCTAssertTrue([F53OSCMessage legalAddress:@"/test["], @"Unclosed bracket should be valid (characters are legal)");
    XCTAssertTrue([F53OSCMessage legalAddress:@"/test]"], @"Unmatched closing bracket should be valid (characters are legal)");
    XCTAssertTrue([F53OSCMessage legalAddress:@"/test{"], @"Unclosed brace should be valid (characters are legal)");
    XCTAssertTrue([F53OSCMessage legalAddress:@"/test}"], @"Unmatched closing brace should be valid (characters are legal)");
    XCTAssertTrue([F53OSCMessage legalAddress:@"/test{foo"], @"Unclosed string alternative should be valid (characters are legal)");
    XCTAssertTrue([F53OSCMessage legalAddress:@"/test{foo,}"], @"Empty string alternative should be valid (characters are legal)");

    // OSC specification examples.
    XCTAssertTrue([F53OSCMessage legalAddress:@"/oscillator/4/frequency"], @"Typical OSC address should be valid");
    XCTAssertTrue([F53OSCMessage legalAddress:@"/mixer/channel*/volume"], @"Channel wildcard should be valid");
    XCTAssertTrue([F53OSCMessage legalAddress:@"/synth/osc[1-8]/waveform"], @"Numeric range wildcard should be valid");

    XCTAssertFalse([F53OSCMessage legalAddress:nil], @"nil address should be invalid");
    XCTAssertFalse([F53OSCMessage legalAddress:@""], @"Empty address should be invalid");
    XCTAssertFalse([F53OSCMessage legalAddress:@"test"], @"Address without leading slash should be invalid");

    // Test various Unicode characters.
    XCTAssertFalse([F53OSCMessage legalAddress:@"/tëst"], @"Address with accented characters should be invalid");
    XCTAssertFalse([F53OSCMessage legalAddress:@"/тест/path"], @"Address with Cyrillic should be invalid");
    XCTAssertFalse([F53OSCMessage legalAddress:@"/测试"], @"Address with Chinese characters should be invalid");
    XCTAssertFalse([F53OSCMessage legalAddress:@"/🎵/test"], @"Address with emoji should be invalid");
    XCTAssertFalse([F53OSCMessage legalAddress:@"/café/menu"], @"Address with accented characters should be invalid");

    // Very long address should be valid (no length limit).
    NSMutableString *longAddress = [NSMutableString stringWithString:@"/"];
    for (int i = 0; i < 10000; i++)
        [longAddress appendFormat:@"component%d/", i];
    [longAddress appendString:@"end"];
    XCTAssertTrue([F53OSCMessage legalAddress:longAddress], @"Long address (10000 components) should be valid");

    // Test very long single component.
    NSMutableString *longComponentAddress = [NSMutableString stringWithString:@"/"];
    for (int i = 0; i < 10000; i++)
        [longComponentAddress appendString:@"a"];
    XCTAssertTrue([F53OSCMessage legalAddress:longComponentAddress], @"Long address (10000 chars) should be valid");
}

- (void)testThat_legalMethodWorks
{
    XCTAssertTrue([F53OSCMessage legalMethod:@"play"], @"Simple method should be valid");
    XCTAssertTrue([F53OSCMessage legalMethod:@"stop"], @"Simple method should be valid");
    XCTAssertTrue([F53OSCMessage legalMethod:@"volume1"], @"Method with a number should be valid");
    XCTAssertTrue([F53OSCMessage legalMethod:@"volume123"], @"Method with numbers should be valid");
    XCTAssertTrue([F53OSCMessage legalMethod:@"Method1"], @"Method starting with uppercase should be valid");
    XCTAssertTrue([F53OSCMessage legalMethod:@"method1"], @"Method starting with lowercase should be valid");
    XCTAssertTrue([F53OSCMessage legalMethod:@"METHOD"], @"All uppercase method should be valid");
    XCTAssertTrue([F53OSCMessage legalMethod:@"mETHOD"], @"Mixed case method should be valid");
    XCTAssertTrue([F53OSCMessage legalMethod:@"getOscillator4Frequency"], @"Complex method name should be valid");

    // Methods with numbers.
    XCTAssertTrue([F53OSCMessage legalMethod:@"123"], @"Numeric method should be valid");
    XCTAssertTrue([F53OSCMessage legalMethod:@"1"], @"Single digit method should be valid");
    XCTAssertTrue([F53OSCMessage legalMethod:@"0"], @"Zero method should be valid");

    // Methods that look like addresses (start with /).
    XCTAssertFalse([F53OSCMessage legalMethod:@"/play"], @"Method starting with slash should be invalid");
    XCTAssertFalse([F53OSCMessage legalMethod:@"/test/method"], @"Method with slashes should be invalid");

    NSString *validCharacters = legalAddressCharacters; // wildcards are not valid in method names

    // Test full ASCII range: 0-127 (0x00-0x7F)
    // TODO: Test that extended characters are rejected.
    for (unichar c = 0; c < 127; c++)
    {
        NSString *character = [NSString stringWithCharacters:&c length:1];
        BOOL valid = [validCharacters containsString:character];

        NSString *method;

        method = [NSString stringWithFormat:@"test%@character", character];
        if (valid)
            XCTAssertTrue([F53OSCMessage legalMethod:method], @"Method containing '%@' should be valid", character);
        else
            XCTAssertFalse([F53OSCMessage legalMethod:method], @"Method containing '%@' should not be valid", character);
    }

    // OSC spec prohibits certain characters.
    XCTAssertFalse([F53OSCMessage legalMethod:@"test space"], @"Method with a space should be invalid");
    XCTAssertFalse([F53OSCMessage legalMethod:@"test#hash"], @"Method with a hash should be invalid");

    // Test edge ASCII characters.
    XCTAssertFalse([F53OSCMessage legalMethod:@"test\t"], @"Method with a tab should be invalid");
    XCTAssertFalse([F53OSCMessage legalMethod:@"test\n"], @"Method with a newline should be invalid");
    XCTAssertFalse([F53OSCMessage legalMethod:@"test\r"], @"Method with a carriage return should be invalid");
    XCTAssertFalse([F53OSCMessage legalMethod:@"test\0"], @"Method with a null character should be invalid");

    XCTAssertFalse([F53OSCMessage legalMethod:nil], @"nil method should be invalid");
    XCTAssertTrue([F53OSCMessage legalMethod:@""], @"Empty method should be valid (implementation allows this)");

    // Test various Unicode characters.
    XCTAssertFalse([F53OSCMessage legalMethod:@"plây"], @"Method with accented characters should be invalid");
    XCTAssertFalse([F53OSCMessage legalMethod:@"играть"], @"Method with Cyrillic should be invalid");
    XCTAssertFalse([F53OSCMessage legalMethod:@"播放"], @"Method with Chinese characters should be invalid");
    XCTAssertFalse([F53OSCMessage legalMethod:@"play🎵"], @"Method with emoji should be invalid");

    // Very long method name should be valid (no length limit).
    NSMutableString *longMethod = [NSMutableString string];
    for (int i = 0; i < 10000; i++)
        [longMethod appendString:@"a"];
    XCTAssertTrue([F53OSCMessage legalMethod:longMethod], @"Long method (10000 chars) should be valid");
}

- (void)testThat_validationMethodsAreConsistent
{
    // Ensure that truly invalid components make invalid addresses.
    NSArray<NSString *> *invalidComponents = @[@"test space", @"test#hash"];  // Only space and hash are invalid

    for (NSString *component in invalidComponents)
    {
        XCTAssertFalse([F53OSCMessage legalAddressComponent:component], @"Component '%@' should be invalid", component);

        NSString *addressWithInvalidComponent = [NSString stringWithFormat:@"/%@", component];
        XCTAssertFalse([F53OSCMessage legalAddress:addressWithInvalidComponent], @"Address with invalid component '%@' should be invalid", component);
    }

    // Test that wildcard characters are valid in components and addresses.
    NSArray<NSString *> *wildcardComponents = @[@"test*", @"test?", @"test[", @"test{"];

    for (NSString *component in wildcardComponents)
    {
        XCTAssertTrue([F53OSCMessage legalAddressComponent:component], @"Component '%@' should be valid (wildcard)", component);

        NSString *addressWithWildcardComponent = [NSString stringWithFormat:@"/%@", component];
        XCTAssertTrue([F53OSCMessage legalAddress:addressWithWildcardComponent], @"Address with wildcard component '%@' should be valid", component);
    }

    // Ensure that valid components make valid addresses.
    NSArray<NSString *> *validComponents = @[@"test", @"hello", @"world123", @"test_component", @"test-component"];

    for (NSString *component in validComponents)
    {
        XCTAssertTrue([F53OSCMessage legalAddressComponent:component], @"Component '%@' should be valid", component);

        NSString *addressWithValidComponent = [NSString stringWithFormat:@"/%@", component];
        XCTAssertTrue([F53OSCMessage legalAddress:addressWithValidComponent], @"Address with valid component '%@' should be valid", component);
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
