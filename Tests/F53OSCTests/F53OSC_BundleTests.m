//
//  F53OSC_BundleTests.m
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
#import "F53OSCMessage.h"
#import "F53OSCSocket.h"
#import "F53OSCTimeTag.h"

#import "NSData+F53OSCBlob.h"


NS_ASSUME_NONNULL_BEGIN

@interface F53OSC_BundleTests : XCTestCase
@end


@implementation F53OSC_BundleTests

//- (void)setUp
//{
//    [super setUp];
//}

//- (void)tearDown
//{
//    [super tearDown];
//}


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

- (void)testThat_bundleHasCorrectDefaults
{
    F53OSCBundle *bundle = [[F53OSCBundle alloc] init];

    XCTAssertNotNil(bundle, @"Bundle should not be nil");
    XCTAssertNil(bundle.replySocket, @"Default replySocket should be nil");
    XCTAssertNotNil([bundle packetData], @"Default packetData should not be nil");
    XCTAssertNil([bundle asQSC], @"Default asQSC should be nil");
    XCTAssertEqual(bundle.timeTag.seconds, [F53OSCTimeTag immediateTimeTag].seconds, @"Default timeTag should be immediateTimeTag"); // F53OSCTimeTag does not implement `isEqual:`
    XCTAssertEqual(bundle.timeTag.fraction, [F53OSCTimeTag immediateTimeTag].fraction, @"Default timeTag should be immediateTimeTag"); // F53OSCTimeTag does not implement `isEqual:`
    XCTAssertEqualObjects(bundle.timeTag.oscTimeTagData, [F53OSCTimeTag immediateTimeTag].oscTimeTagData, @"Default timeTag should be immediateTimeTag"); // F53OSCTimeTag does not implement `isEqual:`
    XCTAssertNotNil(bundle.elements, @"Default elements should not be nil");
    XCTAssertEqual(bundle.elements.count, 0, @"Default elements should be empty");
}

- (void)testThat_bundleCanConfigureProperties
{
    F53OSCBundle *bundle = [[F53OSCBundle alloc] init];

    GCDAsyncUdpSocket *rawReplySocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:nil delegateQueue:nil];
    F53OSCSocket *replySocket = [F53OSCSocket socketWithUdpSocket:rawReplySocket];
    bundle.replySocket = replySocket;
    XCTAssertEqualObjects(bundle.replySocket, replySocket, @"Bundle replySocket should be %@", replySocket);

    F53OSCTimeTag *timeTag = [F53OSCTimeTag timeTagWithDate:[NSDate now]];
    bundle.timeTag = timeTag;
    XCTAssertEqualObjects(bundle.timeTag, timeTag, @"Bundle timeTag should be %@", timeTag);

    F53OSCMessage *message1 = [F53OSCMessage messageWithString:@"/message1"];
    F53OSCMessage *message2 = [F53OSCMessage messageWithString:@"/message2"];
    NSArray<NSData *> *elements = @[[message1 packetData], [message2 packetData]];
    bundle.elements = elements;
    XCTAssertEqualObjects(bundle.elements, elements, @"Bundle elements should be %@", elements);

    NSString *description = [bundle description];
    NSString *expectedDescription = [elements description];

    XCTAssertNotNil(description, @"Bundle description should not be nil");
    XCTAssertEqualObjects(description, expectedDescription, @"Bundle description should match elements description");

    XCTAssertNil([bundle asQSC], @"Bundle asQSC should be nil");
}

- (void)testThat_bundleCanBeCopied
{
    F53OSCBundle *original = [[F53OSCBundle alloc] init];

    // Configure original bundle with test data.
    GCDAsyncUdpSocket *rawReplySocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:nil delegateQueue:nil];
    F53OSCSocket *replySocket = [F53OSCSocket socketWithUdpSocket:rawReplySocket];
    original.replySocket = replySocket;

    F53OSCTimeTag *timeTag = [F53OSCTimeTag timeTagWithDate:[NSDate dateWithTimeIntervalSince1970:1609459200]]; // Jan 1, 2021 UTC
    original.timeTag = timeTag;

    F53OSCMessage *message1 = [F53OSCMessage messageWithString:@"/copy/test1"];
    F53OSCMessage *message2 = [F53OSCMessage messageWithString:@"/copy/test2"];
    NSArray<NSData *> *elements = @[[message1 packetData], [message2 packetData]];
    original.elements = elements;

    F53OSCBundle *copy = [original copy];

    XCTAssertNotNil(copy, @"Copy should not be nil");
    XCTAssertNotEqual(copy, original, @"Copy should be a different object");
    XCTAssertEqual(copy.replySocket, original.replySocket, @"replySocket should be same objects");
    XCTAssertNotEqual(copy.timeTag, original.timeTag, @"timeTag should be different objects");
    XCTAssertEqual(copy.timeTag.seconds, original.timeTag.seconds, @"timeTag should be copied"); // F53OSCTimeTag does not implement `isEqual:`
    XCTAssertEqual(copy.timeTag.fraction, original.timeTag.fraction, @"timeTag should be copied"); // F53OSCTimeTag does not implement `isEqual:`
    XCTAssertEqualObjects(copy.timeTag.oscTimeTagData, original.timeTag.oscTimeTagData, @"timeTag should be copied"); // F53OSCTimeTag does not implement `isEqual:`
    XCTAssertEqualObjects(copy.elements, original.elements, @"elements should be copied");

    XCTAssertNil([copy asQSC], @"Copy asQSC should be nil");
}

- (void)testThat_bundleWithStringReturnsNil
{
    F53OSCBundle *bundle = [F53OSCBundle bundleWithString:@"#bundle somejunk"];
    XCTAssertNil(bundle, @"Bundle does not support initializing from a string");
}

- (void)testThat_bundleWithTimeTagElementsWorks
{
    F53OSCTimeTag *timeTag = [F53OSCTimeTag timeTagWithDate:[NSDate now]];

    F53OSCMessage *message1 = [F53OSCMessage messageWithString:@"/message1"];
    F53OSCMessage *message2 = [F53OSCMessage messageWithString:@"/message2"];
    NSArray<NSData *> *elements = @[[message1 packetData], [message2 packetData]];

    NSMutableData *expectedData = [[@"#bundle" oscStringData] mutableCopy];
    [expectedData appendData:[timeTag oscTimeTagData]];
    [expectedData appendData:[elements[0] oscBlobData]];
    [expectedData appendData:[elements[1] oscBlobData]];

    F53OSCBundle *bundle = [F53OSCBundle bundleWithTimeTag:timeTag elements:elements];
    XCTAssertNotNil(bundle, @"Bundle should initialize");

    XCTAssertNil(bundle.replySocket, @"Bundle replySocket should be nil");
    XCTAssertEqualObjects(bundle.timeTag, timeTag, @"Bundle timeTag should be %@", timeTag);
    XCTAssertEqualObjects(bundle.elements, elements, @"Bundle elements should be %@", elements);
    XCTAssertEqualObjects([bundle packetData], expectedData, @"Bundle packetData should be %@", expectedData);
    XCTAssertNil([bundle asQSC], @"Bundle asQSC should be nil");
}

- (void)testThat_bundleSkipsNonNSDataElements
{
    // Test that bundle handles mixed elements where some are not NSData objects.
    F53OSCTimeTag *timeTag = [F53OSCTimeTag timeTagWithDate:[NSDate now]];

    F53OSCMessage *message1 = [F53OSCMessage messageWithString:@"/valid/message1"];
    F53OSCMessage *message2 = [F53OSCMessage messageWithString:@"/valid/message2"];
    NSData *validElement1 = [message1 packetData];
    NSData *validElement2 = [message2 packetData];

    // Create elements array that includes non-NSData objects.
    NSArray *mixedElements = @[
        validElement1,      // Valid NSData
        @"InvalidString",   // NSString - should be skipped
        validElement2,      // Valid NSData
        @123,               // NSNumber - should be skipped
        [NSDate now],       // NSDate - should be skipped
    ];

    // Create expected data with only the valid NSData elements.
    NSArray<NSData *> *expectedElements = @[
        validElement1,      // Valid NSData
        validElement2,      // Valid NSData
    ];

    NSMutableData *expectedData = [[@"#bundle" oscStringData] mutableCopy];
    [expectedData appendData:[timeTag oscTimeTagData]];
    [expectedData appendData:[validElement1 oscBlobData]];
    [expectedData appendData:[validElement2 oscBlobData]];

    F53OSCBundle *bundle = [F53OSCBundle bundleWithTimeTag:timeTag elements:mixedElements];
    XCTAssertEqual(bundle.timeTag, timeTag, @"Bundle timeTag should be the same object");

    // When setting `mixedElements`, non-NSData elements should be skipped.
    XCTAssertNotNil(bundle.elements, @"Bundle elements should not be nil");
    XCTAssertEqualObjects(bundle.elements, expectedElements, @"Bundle elements should only include valid elements");

    NSData *packetData = [bundle packetData];

    XCTAssertNotNil(packetData, @"packetData should not be nil");
    XCTAssertEqualObjects(packetData, expectedData, @"packetData should only include data for valid elements");

    NSString *description = [bundle description];
    NSString *expectedDescription = [expectedElements description];

    XCTAssertNotNil(description, @"Bundle description should not be nil");
    XCTAssertEqualObjects(description, expectedDescription, @"Bundle description should match expected elements description");
}

@end

NS_ASSUME_NONNULL_END
