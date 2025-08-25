//
//  F53OSC_NSStringTests.m
//  F53OSC
//
//  Created by Brent Lord on 2/8/22.
//  Copyright (c) 2022-2025 Figure 53. All rights reserved.
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

#import "F53OSCMessage.h"
#import "F53OSCParser.h"
#import "NSString+F53OSCString.h"


NS_ASSUME_NONNULL_BEGIN

@interface F53OSC_NSStringTests : XCTestCase
@end


@implementation F53OSC_NSStringTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

NS_INLINE NSUInteger fourBytePaddedInteger(NSUInteger value)
{
    return 4 * (ceil((value + 1) / 4.0));
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


#pragma mark -

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

    F53OSCMessage *message;
    for (NSArray<NSString *> *testArgs in allTestArgs)
    {
        message = [F53OSCMessage messageWithAddressPattern:@"/some/method" arguments:testArgs];
        XCTAssertNotNil(message, "%@", testArgs);
        XCTAssertEqualObjects(message.arguments, testArgs, "%@", testArgs);
        XCTAssertNotNil(message.packetData, "%@", testArgs);

        // when
        NSData *packetData = message.packetData; // encodes strings for OSC
        F53OSCMessage *parsedMessage = [F53OSCParser parseOscMessageData:packetData]; // decodes data

        // then
        XCTAssertNotNil(parsedMessage, "%@", testArgs);
        XCTAssertEqualObjects(parsedMessage.arguments, testArgs, "%@", testArgs);
        XCTAssertEqualObjects(message, parsedMessage, "%@", testArgs);
        XCTAssertEqualObjects(message.addressPattern, parsedMessage.addressPattern, "%@", testArgs);
        XCTAssertEqual(message.arguments.count, parsedMessage.arguments.count, "%@", testArgs);
        XCTAssertTrue([message.arguments isEqualToArray:parsedMessage.arguments], "%@", testArgs);
    }
}


#pragma mark - F53OSCStringAdditions tests

- (void)testThat_oscStringDataHandlesEmptyAndNilStrings
{
    // Test empty string.
    NSString *emptyString = @"";
    NSData *emptyData = [emptyString oscStringData];

    XCTAssertNotNil(emptyData, @"Empty string should produce valid OSC data");
    XCTAssertEqual(emptyData.length, 4, @"Empty string should produce 4 null bytes");

    // Verify all bytes are null.
    const char *bytes = (const char *)emptyData.bytes;
    for (NSUInteger i = 0; i < emptyData.length; i++)
    {
        XCTAssertEqual(bytes[i], 0, @"All bytes should be null for empty string");
    }
}

- (void)testThat_oscStringDataHandlesSpecialCharacters
{
    // Test string with special characters.
    NSString *specialString = @"Hello\nWorld\t!@#$%^&*()";
    NSData *specialData = [specialString oscStringData];

    XCTAssertNotNil(specialData, @"Special characters should be handled correctly");
    XCTAssertEqual(specialData.length % 4, 0, @"Length should be multiple of 4");

    // Test round trip.
    NSUInteger bytesRead = 0;
    NSString *decoded = [NSString stringWithOSCStringBytes:specialData.bytes 
                                                 maxLength:specialData.length 
                                                 bytesRead:&bytesRead];
    XCTAssertEqualObjects(decoded, specialString, @"Round trip should preserve special characters");
}

- (void)testThat_stringWithOSCStringBytesHandlesNullInput
{
    // Test NULL buffer.
    NSUInteger bytesRead = 999; // Initialize to non-zero value
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    NSString *result1 = [NSString stringWithOSCStringBytes:NULL
                                                 maxLength:10 
                                                 bytesRead:&bytesRead];
#pragma clang diagnostic pop

    XCTAssertNil(result1, @"Should return nil for NULL buffer");
    XCTAssertEqual(bytesRead, 0, @"Should set bytesRead to 0 for NULL buffer");

    // Test with NULL bytesRead pointer.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    NSString *result2 = [NSString stringWithOSCStringBytes:NULL
                                                 maxLength:10 
                                                 bytesRead:NULL];
#pragma clang diagnostic pop
    XCTAssertNil(result2, @"Should return nil for NULL buffer even with NULL bytesRead pointer");
}

- (void)testThat_stringWithOSCStringBytesHandlesZeroLength
{
    // Test zero maxLength.
    char validBuffer[4] = {'a', 'b', 'c', '\0'};
    NSUInteger bytesRead = 999;
    NSString *result = [NSString stringWithOSCStringBytes:validBuffer 
                                                maxLength:0 
                                                bytesRead:&bytesRead];

    XCTAssertNil(result, @"Should return nil for zero maxLength");
    XCTAssertEqual(bytesRead, 0, @"Should set bytesRead to 0 for zero maxLength");
}

- (void)testThat_stringWithOSCStringBytesHandlesNonNullTerminatedBuffer
{
    // Test buffer without null terminator.
    char nonNullTerminated[4] = {'a', 'b', 'c', 'd'}; // No null terminator
    NSUInteger bytesRead = 999;
    NSString *result = [NSString stringWithOSCStringBytes:nonNullTerminated 
                                                maxLength:4 
                                                bytesRead:&bytesRead];

    XCTAssertNil(result, @"Should return nil for buffer without null terminator");
    XCTAssertEqual(bytesRead, 0, @"Should set bytesRead to 0 for invalid buffer");
}

- (void)testThat_stringWithOSCStringBytesCalculatesBytesReadCorrectly
{
    // Test various string lengths and verify bytesRead calculation.
    NSArray *testStrings = @[@"a", @"ab", @"abc", @"abcd", @"abcde"];

    for (NSString *testString in testStrings)
    {
        NSData *oscData = [testString oscStringData];
        NSUInteger bytesRead = 0;
        NSString *decoded = [NSString stringWithOSCStringBytes:oscData.bytes 
                                                     maxLength:oscData.length 
                                                     bytesRead:&bytesRead];

        XCTAssertNotNil(decoded, @"Should successfully decode string: %@", testString);
        XCTAssertEqualObjects(decoded, testString, @"Decoded string should match original: %@", testString);
        XCTAssertEqual(bytesRead, oscData.length, @"bytesRead should equal data length for: %@", testString);
        XCTAssertEqual(bytesRead % 4, 0, @"bytesRead should be multiple of 4 for: %@", testString);
    }
}

- (void)testThat_stringWithSpecialRegexCharactersEscapedHandlesAllSpecialChars
{
    // Test string with all special regex characters that should be escaped.
    // NOTE: Asterisk (*) should not be escaped by this method.
    NSString *input = @"test\\+-()*^$|.test";
    NSString *escaped = [NSString stringWithSpecialRegexCharactersEscaped:input];

    // Verify each special character is properly escaped.
    XCTAssertTrue([escaped containsString:@"\\\\"], @"Backslash should be escaped");
    XCTAssertTrue([escaped containsString:@"\\+"], @"Plus should be escaped");
    XCTAssertTrue([escaped containsString:@"\\-"], @"Minus should be escaped");
    XCTAssertTrue([escaped containsString:@"\\("], @"Open paren should be escaped");
    XCTAssertTrue([escaped containsString:@"\\)"], @"Close paren should be escaped");
    XCTAssertTrue([escaped containsString:@")*"], @"Asterisk should not be escaped");
    XCTAssertTrue([escaped containsString:@"\\^"], @"Caret should be escaped");
    XCTAssertTrue([escaped containsString:@"\\$"], @"Dollar should be escaped");
    XCTAssertTrue([escaped containsString:@"\\|"], @"Pipe should be escaped");
    XCTAssertTrue([escaped containsString:@"\\."], @"Dot should be escaped");

    // Verify the complete expected result (asterisk is NOT escaped).
    NSString *expected = @"test\\\\\\+\\-\\(\\)*\\^\\$\\|\\.test";
    XCTAssertEqualObjects(escaped, expected, @"All special characters should be properly escaped");
}

- (void)testThat_stringWithSpecialRegexCharactersEscapedHandlesEmptyAndNormalStrings
{
    // Test empty string.
    NSString *empty = @"";
    NSString *escapedEmpty = [NSString stringWithSpecialRegexCharactersEscaped:empty];
    XCTAssertEqualObjects(escapedEmpty, empty, @"Empty string should remain unchanged");

    // Test string with no special characters.
    NSString *normal = @"normalstring123_test";
    NSString *escapedNormal = [NSString stringWithSpecialRegexCharactersEscaped:normal];
    XCTAssertEqualObjects(escapedNormal, normal, @"Normal string should remain unchanged");

    // Test string with only one special character.
    NSString *singleSpecial = @"test.extension";
    NSString *escapedSingle = [NSString stringWithSpecialRegexCharactersEscaped:singleSpecial];
    XCTAssertEqualObjects(escapedSingle, @"test\\.extension", @"Single special character should be escaped");
}

- (void)testThat_stringWithSpecialRegexCharactersEscapedHandlesBackslashFirst
{
    // Verify that backslash escaping happens first to avoid double-escaping.
    NSString *input = @"\\+test";
    NSString *escaped = [NSString stringWithSpecialRegexCharactersEscaped:input];

    // Should become \\\\\\+test (backslash escaped first, then plus escaped)
    NSString *expected = @"\\\\\\+test";
    XCTAssertEqualObjects(escaped, expected, @"Backslash should be escaped first to avoid conflicts");
}

- (void)testThat_deprecatedStringWithOSCStringBytesWorks
{
    // Test the deprecated method to ensure it still works correctly.
    NSString *testString = @"test string";
    NSData *oscData = [testString oscStringData];

    NSUInteger length = 0;
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSString *decoded = [NSString stringWithOSCStringBytes:oscData.bytes 
                                                 maxLength:oscData.length 
                                                    length:&length];
    #pragma clang diagnostic pop

    XCTAssertNotNil(decoded, @"Deprecated method should still work");
    XCTAssertEqualObjects(decoded, testString, @"Deprecated method should decode correctly");
    XCTAssertEqual(length, oscData.length, @"Deprecated method should set length correctly");
}

- (void)testThat_deprecatedMethodHandlesNullAndZeroLength
{
    // Test deprecated method with NULL buffer.
    NSUInteger length = 999;
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    #pragma clang diagnostic ignored "-Wnonnull"
    NSString *result1 = [NSString stringWithOSCStringBytes:NULL
                                                 maxLength:10 
                                                    length:&length];
    #pragma clang diagnostic pop

    XCTAssertNil(result1, @"Deprecated method should return nil for NULL buffer");
    XCTAssertEqual(length, 0, @"Deprecated method should set length to 0 for NULL buffer");

    // Test with zero maxLength.
    char validBuffer[4] = {'a', 'b', 'c', '\0'};
    length = 999;
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSString *result2 = [NSString stringWithOSCStringBytes:validBuffer 
                                                 maxLength:0 
                                                    length:&length];
    #pragma clang diagnostic pop

    XCTAssertNil(result2, @"Deprecated method should return nil for zero maxLength");
    XCTAssertEqual(length, 0, @"Deprecated method should set length to 0 for zero maxLength");
}

- (void)testThat_oscStringDataHandlesUnicodeCorrectly
{
    // Test various Unicode characters.
    NSArray *unicodeStrings = @[
        @"Enchanté",       // accented characters
        @"🎵🎶🎸",         // emoji
        @"こんにちは",       // Japanese
        @"Здравствуй",     // Cyrillic
        @"مرحبا",          // Arabic
        @"שלום"            // Hebrew
    ];

    for (NSString *unicodeString in unicodeStrings)
    {
        NSData *oscData = [unicodeString oscStringData];
        XCTAssertNotNil(oscData, @"Unicode string should produce valid OSC data: %@", unicodeString);
        XCTAssertEqual(oscData.length % 4, 0, @"Unicode OSC data length should be multiple of 4: %@", unicodeString);

        // Test round trip.
        NSUInteger bytesRead = 0;
        NSString *decoded = [NSString stringWithOSCStringBytes:oscData.bytes 
                                                     maxLength:oscData.length 
                                                     bytesRead:&bytesRead];
        XCTAssertNotNil(decoded, @"Should successfully decode Unicode string: %@", unicodeString);
        XCTAssertEqualObjects(decoded, unicodeString, @"Unicode round trip should preserve content: %@", unicodeString);
    }
}

- (void)testThat_oscStringDataHandlesEdgeCases
{
    // Test very long string.
    NSMutableString *longString = [NSMutableString string];
    for (int i = 0; i < 1000; i++)
    {
        [longString appendString:@"a"];
    }

    NSData *longData = [longString oscStringData];
    XCTAssertNotNil(longData, @"Very long string should produce valid OSC data");
    XCTAssertEqual(longData.length % 4, 0, @"Long string OSC data length should be multiple of 4");

    // Test round trip for long string.
    NSUInteger bytesRead = 0;
    NSString *decodedLong = [NSString stringWithOSCStringBytes:longData.bytes 
                                                     maxLength:longData.length 
                                                     bytesRead:&bytesRead];
    XCTAssertEqualObjects(decodedLong, longString, @"Long string round trip should work");

    // Test string that is exactly a multiple of 4 bytes.
    NSString *fourByteString = @"abcd"; // 4 bytes + 4 null = 8 bytes total
    NSData *fourByteData = [fourByteString oscStringData];
    XCTAssertEqual(fourByteData.length, 8, @"4-byte string should get 4 additional null bytes");
}

@end

NS_ASSUME_NONNULL_END
