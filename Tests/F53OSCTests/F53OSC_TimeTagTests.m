//
//  F53OSC_TimeTagTests.m
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

#import "F53OSCTimeTag.h"
#import "NSDate+F53OSCTimeTag.h"


NS_ASSUME_NONNULL_BEGIN

@interface F53OSC_TimeTagTests : XCTestCase
@end


@implementation F53OSC_TimeTagTests

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

- (void)testThat_timeTagHasCorrectDefaults
{
    F53OSCTimeTag *timeTag = [[F53OSCTimeTag alloc] init];

    NSData *expectedData = [[NSData alloc] initWithBase64EncodedString:@"AAAAAAAAAAA=" options:0]; // <00000000 00000000>

    XCTAssertNotNil(timeTag, @"Time tag should not be nil");
    XCTAssertEqual(timeTag.seconds, 0, @"Default seconds should be 0");
    XCTAssertEqual(timeTag.fraction, 0, @"Default fraction should be 0");
    XCTAssertEqualObjects(timeTag.oscTimeTagData, expectedData, @"Default oscTimeTagData should be '<00000000 00000000>");
}

- (void)testThat_timeTagCanConfigureProperties
{
    F53OSCTimeTag *timeTag = [[F53OSCTimeTag alloc] init];

    timeTag.seconds = 3692217600; // Jan 1, 2017 relative to 1900 epoch
    XCTAssertEqual(timeTag.seconds, 3692217600, @"Time tag seconds should be 3692217600");

    timeTag.fraction = 2147483648; // 0.5 seconds in OSC time format
    XCTAssertEqual(timeTag.fraction, 2147483648, @"Time tag fraction should be 2147483648");
}

- (void)testThat_timeTagCanBeCopied
{
    F53OSCTimeTag *original = [[F53OSCTimeTag alloc] init];
    original.seconds = 3755289600;    // Jan 1, 2019 relative to 1900 epoch
    original.fraction = 3221225472;   // 0.75 in OSC time format

    F53OSCTimeTag *copy = [original copy];

    XCTAssertNotNil(copy, @"Copy should not be nil");
    XCTAssertNotEqual(copy, original, @"Copy should be a different object");
    XCTAssertEqual(copy.seconds, original.seconds, @"seconds should be copied");
    XCTAssertEqual(copy.fraction, original.fraction, @"fraction should be copied");
    XCTAssertEqualObjects(copy.oscTimeTagData, original.oscTimeTagData, @"oscTimeTagData should be copied");
}

- (void)testThat_timeTagWithDateIsCorrect
{
    NSDate *date = [NSDate now];
    F53OSCTimeTag *timeTag = [F53OSCTimeTag timeTagWithDate:date];

    NSTimeInterval secondsSince1900 = [date timeIntervalSince1970] + 2208988800;          // Relative to the 1900 epoch
    UInt32 expectedSeconds = ((UInt64)secondsSince1900) & 0xffffffff;                     // cast as integer, keeping lower 32 bits only
    UInt32 expectedFraction = (UInt32)(fmod(secondsSince1900, 1.0) * (double)0xffffffff); // decimal portion of `secondsSince1900` * 32-bit unsigned integer max "ticks"

    NSMutableData *expectedData = [NSMutableData data];
    uint32_t bigEndianInt1 = CFSwapInt32HostToBig(expectedSeconds);
    uint32_t bigEndianInt2 = CFSwapInt32HostToBig(expectedFraction);
    [expectedData appendBytes:&bigEndianInt1 length:sizeof(uint32_t)];
    [expectedData appendBytes:&bigEndianInt2 length:sizeof(uint32_t)];

    XCTAssertNotNil(timeTag, @"Time tag should not be nil");
    XCTAssertEqual(timeTag.seconds, expectedSeconds, @"immediateTimeTag seconds should be 0");
    XCTAssertEqual(timeTag.fraction, expectedFraction, @"immediateTimeTag fraction should be 1");
    XCTAssertEqualObjects(timeTag.oscTimeTagData, expectedData, @"immediateTimeTag oscTimeTagData should be '<00000000 00000001>");
}

- (void)testThat_timeTagImmediateTimeTagIsCorrect
{
    F53OSCTimeTag *timeTag = [F53OSCTimeTag immediateTimeTag];

    NSData *expectedData = [[NSData alloc] initWithBase64EncodedString:@"AAAAAAAAAAE=" options:0]; // <00000000 00000001>

    XCTAssertNotNil(timeTag, @"Time tag should not be nil");
    XCTAssertEqual(timeTag.seconds, 0, @"immediateTimeTag seconds should be 0");
    XCTAssertEqual(timeTag.fraction, 1, @"immediateTimeTag fraction should be 1");
    XCTAssertEqualObjects(timeTag.oscTimeTagData, expectedData, @"immediateTimeTag oscTimeTagData should be '<00000000 00000001>");
}

- (void)testThat_timeTagWithOSCTimeBytesIsCorrect
{
    // Create test data with known seconds and fraction values in big-endian format.
    NSMutableData *oscTimeBytes = [NSMutableData data];
    UInt32 testSeconds = 3723753600;    // Jan 1, 2018 relative to 1900 epoch
    UInt32 testFraction = 1073741824;   // 0.25 seconds in OSC time format
    uint32_t bigEndianSeconds = CFSwapInt32HostToBig(testSeconds);
    uint32_t bigEndianFraction = CFSwapInt32HostToBig(testFraction);
    [oscTimeBytes appendBytes:&bigEndianSeconds length:sizeof(uint32_t)];
    [oscTimeBytes appendBytes:&bigEndianFraction length:sizeof(uint32_t)];

    F53OSCTimeTag *timeTag = [F53OSCTimeTag timeTagWithOSCTimeBytes:(char *)oscTimeBytes.bytes];

    XCTAssertNotNil(timeTag, @"Time tag should not be nil");
    XCTAssertEqual(timeTag.seconds, testSeconds, @"Time tag seconds should be %u", testSeconds);
    XCTAssertEqual(timeTag.fraction, testFraction, @"Time tag fraction should be %u", testFraction);
    XCTAssertEqualObjects(timeTag.oscTimeTagData, oscTimeBytes, @"Time tag oscTimeTagData should match original bytes");
}

- (void)testThat_timeTagWithOSCTimeByteHandlesNilBytes
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    F53OSCTimeTag *timeTag = [F53OSCTimeTag timeTagWithOSCTimeBytes:nil];
#pragma clang diagnostic pop

    XCTAssertNil(timeTag, @"Time tag should be nil for nil bytes");
}


#pragma mark - NSDate+F53OSCTimeTag tests

- (void)testThat_oscTimeTagWorks
{
    // Test current date.
    NSDate *now = [NSDate now];
    F53OSCTimeTag *timeTag = [now oscTimeTag];

    XCTAssertNotNil(timeTag, @"oscTimeTag should not return nil");

    // Verify the time tag represents the same date by comparing with F53OSCTimeTag's direct method.
    F53OSCTimeTag *directTimeTag = [F53OSCTimeTag timeTagWithDate:now];
    XCTAssertEqual(timeTag.seconds, directTimeTag.seconds, @"oscTimeTag seconds should match direct creation");
    XCTAssertEqual(timeTag.fraction, directTimeTag.fraction, @"oscTimeTag fraction should match direct creation");
    XCTAssertEqualObjects(timeTag.oscTimeTagData, directTimeTag.oscTimeTagData, @"oscTimeTag data should match direct creation");

    // Test with a specific date to ensure consistency.
    NSDateComponents *components = [[NSDateComponents alloc] init];
    components.year = 2023;
    components.month = 6;
    components.day = 15;
    components.hour = 12;
    components.minute = 30;
    components.second = 45;
    components.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];

    NSCalendar *calendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    NSDate *specificDate = [calendar dateFromComponents:components];
    XCTAssertNotNil(specificDate, @"Specific date should be created");

    F53OSCTimeTag *specificTimeTag = [specificDate oscTimeTag];
    F53OSCTimeTag *specificDirectTimeTag = [F53OSCTimeTag timeTagWithDate:specificDate];

    XCTAssertNotNil(specificTimeTag, @"Specific date oscTimeTag should not be nil");
    XCTAssertEqual(specificTimeTag.seconds, specificDirectTimeTag.seconds, @"Specific date seconds should match");
    XCTAssertEqual(specificTimeTag.fraction, specificDirectTimeTag.fraction, @"Specific date fraction should match");
}

- (void)testThat_oscTimeTagHandlesNSDateTimeZones
{
    // Create the same moment in time using different time zones.
    NSDateComponents *utcComponents = [[NSDateComponents alloc] init];
    utcComponents.year = 2023;
    utcComponents.month = 12;
    utcComponents.day = 25;
    utcComponents.hour = 15;
    utcComponents.minute = 0;
    utcComponents.second = 0;
    utcComponents.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];

    NSDateComponents *pstComponents = [[NSDateComponents alloc] init];
    pstComponents.year = 2023;
    pstComponents.month = 12;
    pstComponents.day = 25;
    pstComponents.hour = 7;  // 15:00 UTC = 07:00 PST
    pstComponents.minute = 0;
    pstComponents.second = 0;
    pstComponents.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"PST"];

    NSCalendar *calendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    NSDate *utcDate = [calendar dateFromComponents:utcComponents];
    NSDate *pstDate = [calendar dateFromComponents:pstComponents];

    XCTAssertNotNil(utcDate, @"UTC date should be created");
    XCTAssertNotNil(pstDate, @"PST date should be created");

    // These should represent the same moment in time.
    XCTAssertEqualWithAccuracy([utcDate timeIntervalSince1970], [pstDate timeIntervalSince1970], 1.0, @"Dates should represent same moment");

    // Their OSC representations should be identical.
    F53OSCTimeTag *utcTimeTag = [utcDate oscTimeTag];
    F53OSCTimeTag *pstTimeTag = [pstDate oscTimeTag];
    NSData *utcData = [utcDate oscTimeTagData];
    NSData *pstData = [pstDate oscTimeTagData];

    XCTAssertEqual(utcTimeTag.seconds, pstTimeTag.seconds, @"Time tag seconds should be equal regardless of timezone");
    XCTAssertEqual(utcTimeTag.fraction, pstTimeTag.fraction, @"Time tag fractions should be equal regardless of timezone");
    XCTAssertEqualObjects(utcData, pstData, @"OSC time tag data should be equal regardless of timezone");
}

- (void)testThat_oscTimeTagDataWorks
{
    // Test current date.
    NSDate *now = [NSDate now];
    NSData *timeTagData = [now oscTimeTagData];

    XCTAssertNotNil(timeTagData, @"oscTimeTagData should not return nil");
    XCTAssertEqual(timeTagData.length, 8, @"OSC time tag data should be 8 bytes");

    // Verify the data matches what we get from the time tag's data.
    F53OSCTimeTag *timeTag = [now oscTimeTag];
    NSData *directData = [timeTag oscTimeTagData];
    XCTAssertEqualObjects(timeTagData, directData, @"oscTimeTagData should match time tag's data");

    // Test with epoch date.
    NSDate *epoch = [NSDate dateWithTimeIntervalSince1970:0];
    NSData *epochData = [epoch oscTimeTagData];

    XCTAssertNotNil(epochData, @"Epoch date oscTimeTagData should not be nil");
    XCTAssertEqual(epochData.length, 8, @"Epoch OSC time tag data should be 8 bytes");

    // Test with future date.
    NSDate *future = [NSDate dateWithTimeIntervalSinceNow:3600]; // 1 hour from now
    NSData *futureData = [future oscTimeTagData];

    XCTAssertNotNil(futureData, @"Future date oscTimeTagData should not be nil");
    XCTAssertEqual(futureData.length, 8, @"Future OSC time tag data should be 8 bytes");

    // Verify round trip consistency.
    F53OSCTimeTag *futureTimeTag = [future oscTimeTag];
    NSData *futureDirectData = [futureTimeTag oscTimeTagData];
    XCTAssertEqualObjects(futureData, futureDirectData, @"Future date data should match");
}

@end

NS_ASSUME_NONNULL_END
