//
//  F53OSC_NSStringTests.m
//  F53OSC
//
//  Created by Brent Lord on 2/8/22.
//  Copyright (c) 2022 Figure 53. All rights reserved.
//

#if !__has_feature(objc_arc)
#error This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import "F53OSCMessage.h"
#import "F53OSCParser.h"
#import "NSString+F53OSCString.h"


NS_ASSUME_NONNULL_BEGIN

@interface F53OSC_NSStringTests : XCTestCase
@end


@implementation F53OSC_NSStringTests

- (void) setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void) tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

NS_INLINE NSUInteger fourBytePaddedInteger(NSUInteger value)
{
    return 4 * (ceil((value + 1) / 4.0));
}

- (void)testThat_oscStringDataLengthsAreCorrect
{
    // given
    // OSC strings are null-terminated and encoded as data in multiples of 4 bytes.
    // If the data is already a multiple of 4 bytes, it gets an additional four null bytes appended.
    NSDictionary<NSString *, NSNumber *> *testStrings = @{
        @"" : @4,    // 0 bytes + 4 null
        @"a" : @4,   // 1 bytes + 3 null
        @"ab" : @4,  // 2 bytes + 3 null
        @"abc" : @4, // 3 bytes + 1 null

        @"abcd" : @8, // 4 bytes + 4 null, etc.
        @"abcde" : @8,
        @"abcdef" : @8,
        @"abcdefg" : @8,

        @"abcdefgh" : @12,
        @"abcdefghi" : @12,
        @"abcdefghij" : @12,
        @"abcdefghijk" : @12,

        // two-byte composed characters encoded as NSUTF8StringEncoding
        @"å" : @4,      // 2 bytes + 2 null
        @"åb" : @4,     // 3 bytes + 1 null
        @"åbc" : @8,    // 4 bytes + 4 null
        @"åbcd" : @8,   // 5 bytes + 3 null
        @"åbcdé" : @8,  // 7 bytes + 1 null
        @"åéîøü" : @12, // 10 bytes + 2 null

        // three-byte composed characters encoded as NSUTF8StringEncoding
        @"郵" : @4, // 3 bytes + 1 null (U+90F5)
        @"郵政" : @8, // 6 bytes + 2 null
        @"MAIL ROOM 郵政" : @20, // 16 bytes + 4 null
    };

    NSData *oscStringData;
    NSString *decodedString;
    for (NSString *testString in testStrings)
    {
        // ENCODE
        // when
        oscStringData = [testString oscStringData];
        NSUInteger expectedDataLength = [testStrings[testString] unsignedIntegerValue];

        // then
        XCTAssertNotNil(oscStringData, "%@", testString);
        XCTAssertEqual(oscStringData.length, expectedDataLength, "%@", testString);

        // DECODE
        // when
        NSUInteger bytesRead = 0;
        decodedString = [NSString stringWithOSCStringBytes:oscStringData.bytes maxLength:oscStringData.length bytesRead:&bytesRead];

        // then
        XCTAssertNotNil(decodedString, "%@", testString);
        XCTAssertGreaterThanOrEqual(bytesRead, 4, "%@", testString); // empty string encodes as a minimum of 4 null bytes
        XCTAssertEqual(bytesRead % 4, 0, "%@", testString); // multiple of 4 bytes

        XCTAssertEqualObjects(testString, decodedString, "%@", testString);
        XCTAssertEqual([testString compare:decodedString options:NSDiacriticInsensitiveSearch], NSOrderedSame, "%@", testString);
        XCTAssertEqualObjects(testString.decomposedStringWithCanonicalMapping, decodedString.decomposedStringWithCanonicalMapping);

        XCTAssertEqual(testString.length, decodedString.length, "%@", testString);
        XCTAssertEqual([testString lengthOfBytesUsingEncoding:NSUTF8StringEncoding], [decodedString lengthOfBytesUsingEncoding:NSUTF8StringEncoding], "%@", testString);

        XCTAssertEqual(bytesRead, expectedDataLength, "%@", testString);

        XCTAssertEqual(fourBytePaddedInteger([testString lengthOfBytesUsingEncoding:NSUTF8StringEncoding]), bytesRead, "%@", testString);
        XCTAssertEqual(fourBytePaddedInteger([decodedString lengthOfBytesUsingEncoding:NSUTF8StringEncoding]), bytesRead, "%@", testString);

        NSString *escapedTestString = [testString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]];
        if ([testString isEqual:escapedTestString] == NO)
        {
            // NSString `-length` counts composed characters as 1, while `-lengthOfBytesUsingEncoding` & `bytesRead` counts the decomposed character length.
            XCTAssertLessThan(testString.length, [testString lengthOfBytesUsingEncoding:NSUTF8StringEncoding], "%@", testString);
            XCTAssertLessThan(decodedString.length, [decodedString lengthOfBytesUsingEncoding:NSUTF8StringEncoding], "%@", testString);
            XCTAssertLessThanOrEqual(fourBytePaddedInteger(testString.length), bytesRead, "%@", testString);
            XCTAssertLessThanOrEqual(fourBytePaddedInteger(decodedString.length), bytesRead, "%@", testString);
        }
        else
        {
            XCTAssertEqual(testString.length, [testString lengthOfBytesUsingEncoding:NSUTF8StringEncoding], "%@", testString);
            XCTAssertEqual(decodedString.length, [decodedString lengthOfBytesUsingEncoding:NSUTF8StringEncoding], "%@", testString);
            XCTAssertEqual(fourBytePaddedInteger(testString.length), bytesRead, "%@", testString);
            XCTAssertEqual(fourBytePaddedInteger(decodedString.length), bytesRead, "%@", testString);
        }
    }
}

- (void)testThat_oscStringArgumentsCanBeParsed
{
    // given
    NSArray<NSArray<NSString *> *> *allTestArgs = @[
        @[@"a"],
        @[@"a", @"ab"],
        @[@"a", @"ab", @"abc"],
        @[@"a", @"ab", @"abc", @"abcd"],

        // two-byte composed characters
        @[@"å", @"åb"],
        @[@"a", @"åb", @"abc"],
        @[@"å", @"åb", @"abc", @"abcd"],
        @[@"å", @"ab", @"åbc", @"åbcd", @"åbcdé"],
        @[@"å", @"ab", @"åbc", @"åbcd", @"åbcdé", @"åbcdéf"],

        // three-byte composed characters encoded as NSUTF8StringEncoding
        @[@"郵"],
        @[@"郵", @"政"],
        @[@"123", @"郵", @"456"],
        @[@"MAIL ROOM 郵政", @"123"],
        @[@"123", @"MAIL ROOM 郵政", @"456"],
    ];

    F53OSCMessage *testMessage;
    for (NSArray<NSString *> *testArgs in allTestArgs)
    {
        testMessage = [F53OSCMessage messageWithAddressPattern:@"/some/method" arguments:testArgs];
        XCTAssertNotNil(testMessage, "%@", testArgs);
        XCTAssertEqualObjects(testMessage.arguments, testArgs, "%@", testArgs);
        XCTAssertNotNil(testMessage.packetData, "%@", testArgs);

        // when
        NSData *packetData = testMessage.packetData; // encodes strings for OSC
        F53OSCMessage *parsedMessage = [F53OSCParser parseOscMessageData:packetData]; // decodes data

        // then
        XCTAssertNotNil(parsedMessage, "%@", testArgs);
        XCTAssertEqualObjects(parsedMessage.arguments, testArgs, "%@", testArgs);
        XCTAssertEqualObjects(testMessage, parsedMessage, "%@", testArgs);
        XCTAssertEqualObjects(testMessage.addressPattern, parsedMessage.addressPattern, "%@", testArgs);
        XCTAssertEqual(testMessage.arguments.count, parsedMessage.arguments.count, "%@", testArgs);
        XCTAssertTrue([testMessage.arguments isEqualToArray:parsedMessage.arguments], "%@", testArgs);
    }
}

@end

NS_ASSUME_NONNULL_END
