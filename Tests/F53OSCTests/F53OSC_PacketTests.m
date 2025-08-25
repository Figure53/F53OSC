//
//  F53OSC_PacketTests.m
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

#import "F53OSCPacket.h"
#import "F53OSCSocket.h"


NS_ASSUME_NONNULL_BEGIN

@interface F53OSC_PacketTests : XCTestCase
@end


@implementation F53OSC_PacketTests

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

- (void)testThat_packetHasCorrectDefaults
{
    F53OSCPacket *packet = [[F53OSCPacket alloc] init];

    XCTAssertNotNil(packet, @"Packet should not be nil");
    XCTAssertNil(packet.replySocket, @"Default replySocket should be nil");
    XCTAssertNil([packet packetData], @"Default packetData should be nil");
    XCTAssertNil([packet asQSC], @"Default asQSC should be nil");
}

- (void)testThat_packetCanConfigureProperties
{
    F53OSCPacket *packet = [[F53OSCPacket alloc] init];

    GCDAsyncUdpSocket *rawReplySocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:nil delegateQueue:nil];
    F53OSCSocket *replySocket = [F53OSCSocket socketWithUdpSocket:rawReplySocket];
    packet.replySocket = replySocket;
    XCTAssertEqualObjects(packet.replySocket, replySocket, @"Packet replySocket should be %@", replySocket);

    XCTAssertNil([packet packetData], @"Bundle packetData should be nil");
    XCTAssertNil([packet asQSC], @"Bundle asQSC should be nil");
}

- (void)testThat_packetCanBeCopied
{
    F53OSCPacket *original = [[F53OSCPacket alloc] init];
    GCDAsyncUdpSocket *rawReplySocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:nil delegateQueue:nil];
    F53OSCSocket *replySocket = [F53OSCSocket socketWithUdpSocket:rawReplySocket];
    original.replySocket = replySocket;

    F53OSCPacket *copy = [original copy];

    XCTAssertNotNil(copy, @"Copy should not be nil");
    XCTAssertNotEqual(copy, original, @"Copy should be a different object");
    XCTAssertEqualObjects(copy.replySocket, original.replySocket, @"replySocket should be copied");
    XCTAssertNil([copy packetData], @"packetData should be nil");
    XCTAssertNil([copy asQSC], @"asQSC should be nil");
}

@end

NS_ASSUME_NONNULL_END
