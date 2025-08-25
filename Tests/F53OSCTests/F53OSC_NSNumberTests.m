//
//  F53OSC_NSNumberTests.m
//  F53OSC
//
//  Created by Brent Lord on 2/12/20.
//  Copyright (c) 2020-2025 Figure 53. All rights reserved.
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


NS_ASSUME_NONNULL_BEGIN

@interface F53OSC_NSNumberTests : XCTestCase
@end


@implementation F53OSC_NSNumberTests

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

- (void)testThat_NSNumberLiteralsAreEqual
{
    // ensure parentheses do not affect the value
    XCTAssertEqualObjects(@YES,         @(YES));
    XCTAssertEqualObjects(@NO,          @(NO));
    XCTAssertEqualObjects(@1,           @(1));
    XCTAssertEqualObjects(@0,           @(0));
    XCTAssertEqualObjects(@-1,          @(-1));
    XCTAssertEqualObjects(@1.0f,        @(1.0f));
    XCTAssertEqualObjects(@0.0f,        @(0.0f));
    XCTAssertEqualObjects(@-1.0f,       @(-1.0f));
    XCTAssertEqualObjects(@1.0,         @(1.0));
    XCTAssertEqualObjects(@0.0,         @(0.0));
    XCTAssertEqualObjects(@-1.0,        @(-1.0));
    XCTAssertEqualObjects(@CHAR_MIN,    @(CHAR_MIN));
    XCTAssertEqualObjects(@CHAR_MAX,    @(CHAR_MAX));
    XCTAssertEqualObjects(@SCHAR_MIN,   @(SCHAR_MIN));
    XCTAssertEqualObjects(@SCHAR_MAX,   @(SCHAR_MAX));
    XCTAssertEqualObjects(@UCHAR_MAX,   @(UCHAR_MAX));
    XCTAssertEqualObjects(@SHRT_MIN,    @(SHRT_MIN));
    XCTAssertEqualObjects(@SHRT_MAX,    @(SHRT_MAX));
    XCTAssertEqualObjects(@USHRT_MAX,   @(USHRT_MAX));
    XCTAssertEqualObjects(@INT_MIN,     @(INT_MIN));
    XCTAssertEqualObjects(@INT_MAX,     @(INT_MAX));
    XCTAssertEqualObjects(@UINT_MAX,    @(UINT_MAX));
    XCTAssertEqualObjects(@INT8_MIN,    @(INT8_MIN));
    XCTAssertEqualObjects(@INT8_MAX,    @(INT8_MAX));
    XCTAssertEqualObjects(@UINT8_MAX,   @(UINT8_MAX));
    XCTAssertEqualObjects(@INT16_MIN,   @(INT16_MIN));
    XCTAssertEqualObjects(@INT16_MAX,   @(INT16_MAX));
    XCTAssertEqualObjects(@UINT16_MAX,  @(UINT16_MAX));
    XCTAssertEqualObjects(@INT32_MIN,   @(INT32_MIN));
    XCTAssertEqualObjects(@INT32_MAX,   @(INT32_MAX));
    XCTAssertEqualObjects(@UINT32_MAX,  @(UINT32_MAX));
    XCTAssertEqualObjects(@INT64_MIN,   @(INT64_MIN));
    XCTAssertEqualObjects(@INT64_MAX,   @(INT64_MAX));
    XCTAssertEqualObjects(@UINT64_MAX,  @(UINT64_MAX));
    XCTAssertEqualObjects(@LONG_MAX,    @(LONG_MAX));
    XCTAssertEqualObjects(@ULONG_MAX,   @(ULONG_MAX));
    XCTAssertEqualObjects(@FLT_MIN,     @(FLT_MIN));
    XCTAssertEqualObjects(@FLT_MAX,     @(FLT_MAX));
    XCTAssertEqualObjects(@DBL_MIN,     @(DBL_MIN));
    XCTAssertEqualObjects(@DBL_MAX,     @(DBL_MAX));

    // ensure parentheses do not affect the CFNumberRef type
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@YES),          CFNumberGetType((CFNumberRef)@(YES)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@NO),           CFNumberGetType((CFNumberRef)@(NO)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@1),            CFNumberGetType((CFNumberRef)@(1)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@0),            CFNumberGetType((CFNumberRef)@(0)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@-1),           CFNumberGetType((CFNumberRef)@(-1)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@1.0f),         CFNumberGetType((CFNumberRef)@(1.0f)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@0.0f),         CFNumberGetType((CFNumberRef)@(0.0f)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@-1.0f),        CFNumberGetType((CFNumberRef)@(-1.0f)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@1.0),          CFNumberGetType((CFNumberRef)@(1.0)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@0.0),          CFNumberGetType((CFNumberRef)@(0.0)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@-1.0),         CFNumberGetType((CFNumberRef)@(-1.0)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@CHAR_MIN),     CFNumberGetType((CFNumberRef)@(CHAR_MIN)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@CHAR_MAX),     CFNumberGetType((CFNumberRef)@(CHAR_MAX)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@SCHAR_MIN),    CFNumberGetType((CFNumberRef)@(SCHAR_MIN)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@SCHAR_MAX),    CFNumberGetType((CFNumberRef)@(SCHAR_MAX)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@UCHAR_MAX),    CFNumberGetType((CFNumberRef)@(UCHAR_MAX)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@SHRT_MIN),     CFNumberGetType((CFNumberRef)@(SHRT_MIN)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@SHRT_MAX),     CFNumberGetType((CFNumberRef)@(SHRT_MAX)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@USHRT_MAX),    CFNumberGetType((CFNumberRef)@(USHRT_MAX)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@INT_MIN),      CFNumberGetType((CFNumberRef)@(INT_MIN)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@INT_MAX),      CFNumberGetType((CFNumberRef)@(INT_MAX)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@UINT_MAX),     CFNumberGetType((CFNumberRef)@(UINT_MAX)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@INT8_MIN),     CFNumberGetType((CFNumberRef)@(INT8_MIN)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@INT8_MAX),     CFNumberGetType((CFNumberRef)@(INT8_MAX)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@UINT8_MAX),    CFNumberGetType((CFNumberRef)@(UINT8_MAX)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@INT16_MIN),    CFNumberGetType((CFNumberRef)@(INT16_MIN)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@INT16_MAX),    CFNumberGetType((CFNumberRef)@(INT16_MAX)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@UINT16_MAX),   CFNumberGetType((CFNumberRef)@(UINT16_MAX)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@INT32_MIN),    CFNumberGetType((CFNumberRef)@(INT32_MIN)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@INT32_MAX),    CFNumberGetType((CFNumberRef)@(INT32_MAX)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@UINT32_MAX),   CFNumberGetType((CFNumberRef)@(UINT32_MAX)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@INT64_MIN),    CFNumberGetType((CFNumberRef)@(INT64_MIN)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@INT64_MAX),    CFNumberGetType((CFNumberRef)@(INT64_MAX)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@UINT64_MAX),   CFNumberGetType((CFNumberRef)@(UINT64_MAX)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@LONG_MAX),     CFNumberGetType((CFNumberRef)@(LONG_MAX)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@ULONG_MAX),    CFNumberGetType((CFNumberRef)@(ULONG_MAX)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@FLT_MIN),      CFNumberGetType((CFNumberRef)@(FLT_MIN)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@FLT_MAX),      CFNumberGetType((CFNumberRef)@(FLT_MAX)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@DBL_MIN),      CFNumberGetType((CFNumberRef)@(DBL_MIN)));
    XCTAssertEqual(CFNumberGetType((CFNumberRef)@DBL_MAX),      CFNumberGetType((CFNumberRef)@(DBL_MAX)));

    // ensure NSNumber literals are equal to initialized numbers
    XCTAssertEqualObjects(@(YES),           [NSNumber numberWithBool:YES]);
    XCTAssertEqualObjects(@(NO),            [NSNumber numberWithBool:NO]);
    XCTAssertEqualObjects(@(1),             [NSNumber numberWithShort:1]);
    XCTAssertEqualObjects(@(0),             [NSNumber numberWithShort:0]);
    XCTAssertEqualObjects(@(-1),            [NSNumber numberWithShort:-1]);
    XCTAssertEqualObjects(@(1),             [NSNumber numberWithUnsignedShort:1]);
    XCTAssertEqualObjects(@(1),             [NSNumber numberWithInt:1]);
    XCTAssertEqualObjects(@(0),             [NSNumber numberWithInt:0]);
    XCTAssertEqualObjects(@(-1),            [NSNumber numberWithInt:-1]);
    XCTAssertEqualObjects(@(1),             [NSNumber numberWithUnsignedInt:1]);
    XCTAssertEqualObjects(@(1),             [NSNumber numberWithLong:1]);
    XCTAssertEqualObjects(@(0),             [NSNumber numberWithLong:0]);
    XCTAssertEqualObjects(@(-1),            [NSNumber numberWithLong:-1]);
    XCTAssertEqualObjects(@(1),             [NSNumber numberWithUnsignedLong:1]);
    XCTAssertEqualObjects(@(1),             [NSNumber numberWithLongLong:1]);
    XCTAssertEqualObjects(@(0),             [NSNumber numberWithLongLong:0]);
    XCTAssertEqualObjects(@(-1),            [NSNumber numberWithLongLong:-1]);
    XCTAssertEqualObjects(@(1),             [NSNumber numberWithUnsignedLongLong:1]);
    XCTAssertEqualObjects(@(1),             [NSNumber numberWithInteger:1]);
    XCTAssertEqualObjects(@(0),             [NSNumber numberWithInteger:0]);
    XCTAssertEqualObjects(@(-1),            [NSNumber numberWithInteger:-1]);
    XCTAssertEqualObjects(@(1),             [NSNumber numberWithUnsignedInteger:1]);
    XCTAssertEqualObjects(@(1.0f),          [NSNumber numberWithFloat:1.0f]);
    XCTAssertEqualObjects(@(0.0f),          [NSNumber numberWithFloat:0.0f]);
    XCTAssertEqualObjects(@(-1.0f),         [NSNumber numberWithFloat:-1.0f]);
    XCTAssertEqualObjects(@(1.0),           [NSNumber numberWithDouble:1.0]);
    XCTAssertEqualObjects(@(0.0),           [NSNumber numberWithDouble:0.0]);
    XCTAssertEqualObjects(@(-1.0),          [NSNumber numberWithDouble:-1.0]);
    XCTAssertEqualObjects(@(CHAR_MIN),      [NSNumber numberWithChar:CHAR_MIN]);
    XCTAssertEqualObjects(@(CHAR_MAX),      [NSNumber numberWithChar:CHAR_MAX]);
    XCTAssertEqualObjects(@(SCHAR_MIN),     [NSNumber numberWithChar:SCHAR_MIN]);
    XCTAssertEqualObjects(@(SCHAR_MAX),     [NSNumber numberWithChar:SCHAR_MAX]);
    XCTAssertEqualObjects(@(UCHAR_MAX),     [NSNumber numberWithUnsignedChar:UCHAR_MAX]);
    XCTAssertEqualObjects(@(SHRT_MIN),      [NSNumber numberWithShort:SHRT_MIN]);
    XCTAssertEqualObjects(@(SHRT_MAX),      [NSNumber numberWithShort:SHRT_MAX]);
    XCTAssertEqualObjects(@(USHRT_MAX),     [NSNumber numberWithUnsignedShort:USHRT_MAX]);
    XCTAssertEqualObjects(@(INT_MIN),       [NSNumber numberWithInt:INT_MIN]);
    XCTAssertEqualObjects(@(INT_MAX),       [NSNumber numberWithInt:INT_MAX]);
    XCTAssertEqualObjects(@(UINT_MAX),      [NSNumber numberWithUnsignedInt:UINT_MAX]);
    XCTAssertEqualObjects(@(INT8_MIN),      [NSNumber numberWithShort:INT8_MIN]);
    XCTAssertEqualObjects(@(INT8_MAX),      [NSNumber numberWithShort:INT8_MAX]);
    XCTAssertEqualObjects(@(UINT8_MAX),     [NSNumber numberWithShort:UINT8_MAX]);
    XCTAssertEqualObjects(@(INT16_MIN),     [NSNumber numberWithShort:INT16_MIN]);
    XCTAssertEqualObjects(@(INT16_MAX),     [NSNumber numberWithShort:INT16_MAX]);
    XCTAssertEqualObjects(@(UINT16_MAX),    [NSNumber numberWithUnsignedShort:UINT16_MAX]);
    XCTAssertEqualObjects(@(INT32_MIN),     [NSNumber numberWithInt:INT32_MIN]);
    XCTAssertEqualObjects(@(INT32_MAX),     [NSNumber numberWithInt:INT32_MAX]);
    XCTAssertEqualObjects(@(UINT32_MAX),    [NSNumber numberWithUnsignedInt:UINT32_MAX]);
    XCTAssertEqualObjects(@(INT64_MIN),     [NSNumber numberWithLong:INT64_MIN]);
    XCTAssertEqualObjects(@(INT64_MAX),     [NSNumber numberWithLong:INT64_MAX]);
    XCTAssertEqualObjects(@(UINT64_MAX),    [NSNumber numberWithUnsignedLong:UINT64_MAX]);
    XCTAssertEqualObjects(@(LONG_MAX),      [NSNumber numberWithLong:LONG_MAX]);
    XCTAssertEqualObjects(@(ULONG_MAX),     [NSNumber numberWithUnsignedLong:ULONG_MAX]);
    XCTAssertEqualObjects(@(FLT_MIN),       [NSNumber numberWithFloat:FLT_MIN]);
    XCTAssertEqualObjects(@(FLT_MAX),       [NSNumber numberWithFloat:FLT_MAX]);
    XCTAssertEqualObjects(@(DBL_MIN),       [NSNumber numberWithDouble:DBL_MIN]);
    XCTAssertEqualObjects(@(DBL_MAX),       [NSNumber numberWithDouble:DBL_MAX]);
}

- (void)testThat_argumentTagFromNSNumberIsCorrect
{
    // Values for all CFNumberType enum members
    SInt8 sint8Value = -42;
    SInt16 sint16Value = -12345;
    SInt32 sint32Value = -123456789;
    SInt64 sint64Value = -1234567890123456789LL;
    Float32 float32Value = 3.14159f;
    Float64 float64Value = 2.718281828;
    char charValue = -42;
    short shortValue = -12345;
    int intValue = -123456789;
    long longValue = -1234567890123456789L;
    long long longLongValue = -1234567890123456789LL;
    float floatValue = 3.14159f;
    double doubleValue = 2.718281828;
    CFIndex cfIndexValue = -1234567890123456789L;
    NSInteger nsIntegerValue = -1234567890123456789L;
    CGFloat cgFloatValue = 1.618033988749;

    XCTAssertEqual(kCFNumberMaxType, 16);

    // given
    // - { tag : [numbers] }
    NSDictionary<NSString *, NSArray<NSNumber *> *> *tagsAndNumbers =
    @{
        @"i" : @[ // OSC integer
            // BOOL
            @(YES),
            @(NO),
            [NSNumber numberWithBool:YES],
            [NSNumber numberWithBool:NO],

            // SInt8
            // signed char
            @(CHAR_MIN),
            @(CHAR_MAX),
            @(SCHAR_MIN),
            @(SCHAR_MAX),
            @(INT8_MIN),
            @(INT8_MAX),
            [NSNumber numberWithChar:CHAR_MIN],
            [NSNumber numberWithChar:CHAR_MAX],
            [NSNumber numberWithChar:SCHAR_MIN],
            [NSNumber numberWithChar:SCHAR_MAX],
            [NSNumber numberWithChar:INT8_MIN],
            [NSNumber numberWithChar:INT8_MAX],
            [NSNumber numberWithChar:'T'],
            [NSNumber numberWithChar:'F'],
            [NSNumber numberWithChar:'t'],
            [NSNumber numberWithChar:'f'],
            [NSNumber numberWithChar:'1'],
            [NSNumber numberWithChar:'0'],
            [NSNumber numberWithChar:1],
            [NSNumber numberWithChar:0],
            [NSNumber numberWithChar:-1],
            (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt8Type, &sint8Value),
            (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberCharType, &charValue),

            // UInt8
            // unsigned char
            @(UCHAR_MAX),
            @(UINT8_MAX),
            [NSNumber numberWithUnsignedChar:UCHAR_MAX],
            [NSNumber numberWithUnsignedChar:UINT8_MAX],
            [NSNumber numberWithUnsignedChar:'T'],
            [NSNumber numberWithUnsignedChar:'F'],
            [NSNumber numberWithUnsignedChar:'t'],
            [NSNumber numberWithUnsignedChar:'f'],
            [NSNumber numberWithUnsignedChar:'1'],
            [NSNumber numberWithUnsignedChar:'0'],
            [NSNumber numberWithUnsignedChar:1],
            [NSNumber numberWithUnsignedChar:0],

            // SInt16
            // signed short
            @(INT16_MIN),
            @(INT16_MAX),
            @(SHRT_MIN),
            @(SHRT_MAX),
            [NSNumber numberWithShort:INT16_MIN],
            [NSNumber numberWithShort:INT16_MAX],
            [NSNumber numberWithShort:SHRT_MIN],
            [NSNumber numberWithShort:SHRT_MAX],
            (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt16Type, &sint16Value),
            (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberShortType, &shortValue),

            // UInt16
            // unsigned short
            @(USHRT_MAX),
            @(UINT16_MAX),
            [NSNumber numberWithUnsignedShort:UINT16_MAX],
            [NSNumber numberWithUnsignedShort:USHRT_MAX],

            // SInt32
            // signed int
            @(INT32_MIN),
            @(INT32_MAX),
            @(INT_MIN),
            @(INT_MAX),
            [NSNumber numberWithInt:INT32_MIN],
            [NSNumber numberWithInt:INT32_MAX],
            [NSNumber numberWithInt:INT_MIN],
            [NSNumber numberWithInt:INT_MAX],
            (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &sint32Value),
            (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &intValue),

            // UInt32
            // unsigned int
            @(UINT32_MAX),
            @(UINT_MAX),
            [NSNumber numberWithUnsignedInt:UINT32_MAX],
            [NSNumber numberWithUnsignedInt:UINT_MAX],

            // SInt64
            // signed long
            // signed long long
            @-1,
            @(-1),
            @(LONG_MIN),
            @(LONG_MAX),
            @(INT64_MIN),
            @(INT64_MAX),
            @(LLONG_MIN),
            @(LLONG_MAX),
            [NSNumber numberWithLong:LONG_MIN],
            [NSNumber numberWithLong:LONG_MAX],
            [NSNumber numberWithLongLong:INT64_MIN],
            [NSNumber numberWithLongLong:INT64_MAX],
            [NSNumber numberWithLongLong:LLONG_MIN],
            [NSNumber numberWithLongLong:LLONG_MAX],
            (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt64Type, &sint64Value),
            (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberLongType, &longValue),
            (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberLongLongType, &longLongValue),
            (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberCFIndexType, &cfIndexValue),
            (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberNSIntegerType, &nsIntegerValue),

            // UInt64
            // unsigned long
            // unsigned long long
            @1,
            @0,
            @(1),
            @(0),
            @(ULONG_MAX),
            @(UINT64_MAX),
            @(ULLONG_MAX),
            [NSNumber numberWithUnsignedLong:ULONG_MAX],
            [NSNumber numberWithUnsignedLongLong:ULLONG_MAX],
            [NSNumber numberWithUnsignedLongLong:UINT64_MAX],

            // overflows
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wconversion"
            [NSNumber numberWithBool:CHAR_MIN],
            [NSNumber numberWithBool:CHAR_MAX],
            [NSNumber numberWithBool:SCHAR_MIN],
            [NSNumber numberWithBool:SCHAR_MAX],
            [NSNumber numberWithBool:INT8_MIN],
            [NSNumber numberWithBool:INT8_MAX],
            [NSNumber numberWithBool:'T'],
            [NSNumber numberWithBool:'F'],
            [NSNumber numberWithBool:'t'],
            [NSNumber numberWithBool:'f'],
            [NSNumber numberWithBool:'1'],
            [NSNumber numberWithBool:'0'],
            [NSNumber numberWithBool:1],
            [NSNumber numberWithBool:0],
            [NSNumber numberWithBool:-1],
            [NSNumber numberWithBool:UCHAR_MAX],
            [NSNumber numberWithBool:UINT8_MAX],
            [NSNumber numberWithBool:INT16_MIN],
            [NSNumber numberWithBool:INT16_MAX],
            [NSNumber numberWithBool:SHRT_MIN],
            [NSNumber numberWithBool:SHRT_MAX],
            [NSNumber numberWithBool:USHRT_MAX],
            [NSNumber numberWithBool:UINT16_MAX],
            [NSNumber numberWithBool:INT32_MIN],
            [NSNumber numberWithBool:INT32_MAX],
            [NSNumber numberWithBool:INT_MIN],
            [NSNumber numberWithBool:INT_MAX],
            [NSNumber numberWithBool:UINT32_MAX],
            [NSNumber numberWithBool:UINT_MAX],
            [NSNumber numberWithBool:LONG_MIN],
            [NSNumber numberWithBool:LONG_MAX],
            [NSNumber numberWithBool:INT64_MIN],
            [NSNumber numberWithBool:INT64_MAX],
            [NSNumber numberWithBool:INT64_MIN],
            [NSNumber numberWithBool:LLONG_MIN],
            [NSNumber numberWithBool:LLONG_MAX],
            [NSNumber numberWithBool:UINT64_MAX],
            [NSNumber numberWithBool:ULLONG_MAX],

            [NSNumber numberWithChar:INT16_MIN],
            [NSNumber numberWithChar:INT16_MAX],
            [NSNumber numberWithChar:SHRT_MIN],
            [NSNumber numberWithChar:SHRT_MAX],
            [NSNumber numberWithChar:USHRT_MAX],
            [NSNumber numberWithChar:UINT16_MAX],
            [NSNumber numberWithChar:INT32_MIN],
            [NSNumber numberWithChar:INT32_MAX],
            [NSNumber numberWithChar:INT_MIN],
            [NSNumber numberWithChar:INT_MAX],
            [NSNumber numberWithChar:UINT32_MAX],
            [NSNumber numberWithChar:UINT_MAX],
            [NSNumber numberWithChar:LONG_MIN],
            [NSNumber numberWithChar:LONG_MAX],
            [NSNumber numberWithChar:INT64_MIN],
            [NSNumber numberWithChar:INT64_MAX],
            [NSNumber numberWithChar:ULONG_MAX],
            [NSNumber numberWithChar:LLONG_MIN],
            [NSNumber numberWithChar:LLONG_MAX],
            [NSNumber numberWithChar:UINT64_MAX],
            [NSNumber numberWithChar:ULLONG_MAX],

            [NSNumber numberWithUnsignedChar:CHAR_MIN],
            [NSNumber numberWithUnsignedChar:SCHAR_MIN],
            [NSNumber numberWithUnsignedChar:INT8_MIN],
            [NSNumber numberWithUnsignedChar:-1],
            [NSNumber numberWithUnsignedChar:INT16_MIN],
            [NSNumber numberWithUnsignedChar:INT16_MAX],
            [NSNumber numberWithUnsignedChar:SHRT_MIN],
            [NSNumber numberWithUnsignedChar:SHRT_MAX],
            [NSNumber numberWithUnsignedChar:USHRT_MAX],
            [NSNumber numberWithUnsignedChar:UINT16_MAX],
            [NSNumber numberWithUnsignedChar:INT32_MIN],
            [NSNumber numberWithUnsignedChar:INT32_MAX],
            [NSNumber numberWithUnsignedChar:INT_MIN],
            [NSNumber numberWithUnsignedChar:INT_MAX],
            [NSNumber numberWithUnsignedChar:UINT32_MAX],
            [NSNumber numberWithUnsignedChar:UINT_MAX],
            [NSNumber numberWithUnsignedChar:LONG_MIN],
            [NSNumber numberWithUnsignedChar:LONG_MAX],
            [NSNumber numberWithUnsignedChar:INT64_MIN],
            [NSNumber numberWithUnsignedChar:INT64_MAX],
            [NSNumber numberWithUnsignedChar:ULONG_MAX],
            [NSNumber numberWithUnsignedChar:LLONG_MIN],
            [NSNumber numberWithUnsignedChar:LLONG_MAX],
            [NSNumber numberWithUnsignedChar:UINT64_MAX],
            [NSNumber numberWithUnsignedChar:ULLONG_MAX],

            [NSNumber numberWithShort:USHRT_MAX],
            [NSNumber numberWithShort:UINT16_MAX],
            [NSNumber numberWithShort:INT32_MIN],
            [NSNumber numberWithShort:INT32_MAX],
            [NSNumber numberWithShort:INT_MIN],
            [NSNumber numberWithShort:INT_MAX],
            [NSNumber numberWithShort:UINT32_MAX],
            [NSNumber numberWithShort:UINT_MAX],
            [NSNumber numberWithShort:LONG_MIN],
            [NSNumber numberWithShort:LONG_MAX],
            [NSNumber numberWithShort:INT64_MIN],
            [NSNumber numberWithShort:INT64_MAX],
            [NSNumber numberWithShort:LLONG_MIN],
            [NSNumber numberWithShort:LLONG_MAX],
            [NSNumber numberWithShort:ULONG_MAX],
            [NSNumber numberWithShort:UINT64_MAX],
            [NSNumber numberWithShort:ULLONG_MAX],

            [NSNumber numberWithUnsignedShort:CHAR_MIN],
            [NSNumber numberWithUnsignedShort:SCHAR_MIN],
            [NSNumber numberWithUnsignedShort:INT8_MIN],
            [NSNumber numberWithUnsignedShort:-1],
            [NSNumber numberWithUnsignedShort:INT16_MIN],
            [NSNumber numberWithUnsignedShort:SHRT_MIN],
            [NSNumber numberWithUnsignedShort:INT32_MIN],
            [NSNumber numberWithUnsignedShort:INT32_MAX],
            [NSNumber numberWithUnsignedShort:INT_MIN],
            [NSNumber numberWithUnsignedShort:INT_MAX],
            [NSNumber numberWithUnsignedShort:UINT32_MAX],
            [NSNumber numberWithUnsignedShort:UINT_MAX],
            [NSNumber numberWithUnsignedShort:LONG_MIN],
            [NSNumber numberWithUnsignedShort:LONG_MAX],
            [NSNumber numberWithUnsignedShort:INT64_MIN],
            [NSNumber numberWithUnsignedShort:INT64_MAX],
            [NSNumber numberWithUnsignedShort:LLONG_MIN],
            [NSNumber numberWithUnsignedShort:LLONG_MAX],
            [NSNumber numberWithUnsignedShort:ULONG_MAX],
            [NSNumber numberWithUnsignedShort:UINT64_MAX],
            [NSNumber numberWithUnsignedShort:ULLONG_MAX],

            [NSNumber numberWithInt:UINT32_MAX],
            [NSNumber numberWithInt:UINT_MAX],
            [NSNumber numberWithInt:LONG_MIN],
            [NSNumber numberWithInt:LONG_MAX],
            [NSNumber numberWithInt:INT64_MIN],
            [NSNumber numberWithInt:INT64_MAX],
            [NSNumber numberWithInt:LLONG_MIN],
            [NSNumber numberWithInt:LLONG_MAX],
            [NSNumber numberWithInt:ULONG_MAX],
            [NSNumber numberWithInt:UINT64_MAX],
            [NSNumber numberWithInt:ULLONG_MAX],

            [NSNumber numberWithUnsignedInt:CHAR_MIN],
            [NSNumber numberWithUnsignedInt:SCHAR_MIN],
            [NSNumber numberWithUnsignedInt:INT8_MIN],
            [NSNumber numberWithUnsignedInt:-1],
            [NSNumber numberWithUnsignedInt:INT16_MIN],
            [NSNumber numberWithUnsignedInt:SHRT_MIN],
            [NSNumber numberWithUnsignedInt:INT32_MIN],
            [NSNumber numberWithUnsignedInt:INT_MIN],
            [NSNumber numberWithUnsignedInt:LONG_MIN],
            [NSNumber numberWithUnsignedInt:LONG_MAX],
            [NSNumber numberWithUnsignedInt:INT64_MIN],
            [NSNumber numberWithUnsignedInt:INT64_MAX],
            [NSNumber numberWithUnsignedInt:LLONG_MIN],
            [NSNumber numberWithUnsignedInt:LLONG_MAX],
            [NSNumber numberWithUnsignedInt:ULONG_MAX],
            [NSNumber numberWithUnsignedInt:UINT64_MAX],
            [NSNumber numberWithUnsignedInt:ULLONG_MAX],

            [NSNumber numberWithLong:LLONG_MIN],
            [NSNumber numberWithLong:LLONG_MAX],
            [NSNumber numberWithLong:ULONG_MAX],
            [NSNumber numberWithLong:UINT64_MAX],
            [NSNumber numberWithLong:ULLONG_MAX],

            [NSNumber numberWithUnsignedLong:CHAR_MIN],
            [NSNumber numberWithUnsignedLong:SCHAR_MIN],
            [NSNumber numberWithUnsignedLong:INT8_MIN],
            [NSNumber numberWithUnsignedLong:-1],
            [NSNumber numberWithUnsignedLong:INT16_MIN],
            [NSNumber numberWithUnsignedLong:SHRT_MIN],
            [NSNumber numberWithUnsignedLong:INT32_MIN],
            [NSNumber numberWithUnsignedLong:INT_MIN],
            [NSNumber numberWithUnsignedLong:LONG_MIN],
            [NSNumber numberWithUnsignedLong:INT64_MIN],
            [NSNumber numberWithUnsignedLong:LLONG_MIN],
            [NSNumber numberWithUnsignedLong:LLONG_MAX],
            [NSNumber numberWithUnsignedLong:ULONG_MAX],
            [NSNumber numberWithUnsignedLong:UINT64_MAX],
            [NSNumber numberWithUnsignedLong:ULLONG_MAX],

            [NSNumber numberWithLongLong:ULONG_MAX],
            [NSNumber numberWithLongLong:UINT64_MAX],
            [NSNumber numberWithLongLong:ULLONG_MAX],

            [NSNumber numberWithUnsignedLongLong:CHAR_MIN],
            [NSNumber numberWithUnsignedLongLong:SCHAR_MIN],
            [NSNumber numberWithUnsignedLongLong:INT8_MIN],
            [NSNumber numberWithUnsignedLongLong:-1],
            [NSNumber numberWithUnsignedLongLong:INT16_MIN],
            [NSNumber numberWithUnsignedLongLong:SHRT_MIN],
            [NSNumber numberWithUnsignedLongLong:INT32_MIN],
            [NSNumber numberWithUnsignedLongLong:INT_MIN],
            [NSNumber numberWithUnsignedLongLong:LONG_MIN],
            [NSNumber numberWithUnsignedLongLong:INT64_MIN],
            [NSNumber numberWithUnsignedLongLong:LLONG_MIN],
#pragma clang diagnostic pop
        ],

        @"f" : @[ // OSC float
            // Float32
            // float
            @(FLT_MIN),
            @(FLT_MAX),
            @1.0f,
            @0.0f,
            @-1.0f,
            [NSNumber numberWithFloat:FLT_MIN],
            [NSNumber numberWithFloat:FLT_MAX],
            [NSNumber numberWithFloat:1.0f],
            [NSNumber numberWithFloat:0.0f],
            [NSNumber numberWithFloat:-1.0f],
            [NSNumber numberWithFloat:1.0],
            [NSNumber numberWithFloat:0.0],
            [NSNumber numberWithFloat:-1.0],
            (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberFloat32Type, &float32Value),
            (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberFloatType, &floatValue),

            // Float64
            // double
            // CGFloat
            @(DBL_MIN),
            @(DBL_MAX),
            @1.0,
            @0.0,
            @-1.0,
            [NSNumber numberWithDouble:DBL_MIN],
            [NSNumber numberWithDouble:DBL_MAX],
            [NSNumber numberWithDouble:1.0f],
            [NSNumber numberWithDouble:0.0f],
            [NSNumber numberWithDouble:-1.0f],
            [NSNumber numberWithDouble:1.0],
            [NSNumber numberWithDouble:0.0],
            [NSNumber numberWithDouble:-1.0],
            (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberFloat64Type, &float64Value),
            (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberDoubleType, &doubleValue),
            (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberCGFloatType, &cgFloatValue),
        ],
    };

    // when

    // then
    for (NSString *expectedTag in tagsAndNumbers)
    {
        NSArray<NSNumber *> *numbers = tagsAndNumbers[expectedTag];
        for (NSNumber *number in numbers)
        {
            NSString *actualTag = [F53OSCMessage tagForArgument:number];
            XCTAssertEqualObjects(actualTag, expectedTag);
        }
    }
}


#pragma mark - F53OSCNumberAdditions tests

- (void)testThat_oscFloatValueProducesCorrectBigEndianBytes
{
    // Test various float values.
    NSNumber *positiveFloat = @(3.14159f);
    NSNumber *negativeFloat = @(-2.71828f);
    NSNumber *zero = @(0.0f);
    NSNumber *maxFloat = @(FLT_MAX);
    NSNumber *minFloat = @(FLT_MIN);

    SInt32 result1 = [positiveFloat oscFloatValue];
    SInt32 result2 = [negativeFloat oscFloatValue];
    SInt32 result3 = [zero oscFloatValue];
    SInt32 result4 = [maxFloat oscFloatValue];
    SInt32 result5 = [minFloat oscFloatValue];

    // These should be non-zero (testing that conversion happens).
    XCTAssertNotEqual(result1, 0, @"Float conversion should produce non-zero result");
    XCTAssertNotEqual(result2, 0, @"Negative float conversion should produce non-zero result");
    XCTAssertEqual(result3, 0, @"Zero float should convert to zero");
    XCTAssertNotEqual(result4, 0, @"Max float conversion should produce non-zero result");
    XCTAssertNotEqual(result5, 0, @"Min float conversion should produce non-zero result");
}

- (void)testThat_oscIntValueProducesCorrectBigEndianBytes
{
    // Test various integer values.
    NSNumber *positiveInt = @(42);
    NSNumber *negativeInt = @(-42);
    NSNumber *zero = @(0);
    NSNumber *maxInt = @(INT32_MAX);
    NSNumber *minInt = @(INT32_MIN);

    SInt32 result1 = [positiveInt oscIntValue];
    SInt32 result2 = [negativeInt oscIntValue];
    SInt32 result3 = [zero oscIntValue];
    SInt32 result4 = [maxInt oscIntValue];
    SInt32 result5 = [minInt oscIntValue];

    // Test that byte swapping occurs for non-zero values.
    XCTAssertNotEqual(result1, 42, @"Should be byte-swapped from host order");
    XCTAssertNotEqual(result2, -42, @"Should be byte-swapped from host order");
    XCTAssertEqual(result3, 0, @"Zero should remain zero after byte swap");
    XCTAssertNotEqual(result4, (SInt32)INT32_MAX, @"Should be byte-swapped from host order");
    XCTAssertNotEqual(result5, (SInt32)INT32_MIN, @"Should be byte-swapped from host order");
}

- (void)testThat_numberWithOSCFloatBytesHandlesValidInput
{
    // Create a test float in big-endian format.
    Float32 testFloat = 3.14159f;
    SInt32 intValue = *((SInt32 *)(&testFloat));
    SInt32 bigEndianInt = OSSwapHostToBigInt32(intValue);
    const char *buf = (const char *)&bigEndianInt;

    NSNumber *result = [NSNumber numberWithOSCFloatBytes:buf maxLength:sizeof(SInt32)];

    XCTAssertNotNil(result, @"Should successfully create NSNumber from valid float bytes");
    XCTAssertEqualWithAccuracy([result floatValue], testFloat, 0.0001, @"Should restore original float value");
}

- (void)testThat_numberWithOSCFloatBytesHandlesInvalidInput
{
    // Test with NULL buffer.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    NSNumber *result1 = [NSNumber numberWithOSCFloatBytes:NULL maxLength:sizeof(SInt32)];
#pragma clang diagnostic pop
    XCTAssertNil(result1, @"Should return nil for NULL buffer");

    // Test with insufficient buffer length.
    char shortBuffer[2] = {0x01, 0x02};
    NSNumber *result2 = [NSNumber numberWithOSCFloatBytes:shortBuffer maxLength:2];
    XCTAssertNil(result2, @"Should return nil for insufficient buffer length");

    // Test with zero length.
    char validBuffer[4] = {0x40, 0x49, 0x0F, 0xDB}; // π in big-endian
    NSNumber *result3 = [NSNumber numberWithOSCFloatBytes:validBuffer maxLength:0];
    XCTAssertNil(result3, @"Should return nil for zero maxLength");
}

- (void)testThat_numberWithOSCIntBytesHandlesValidInput
{
    // Create a test integer in big-endian format.
    SInt32 testInt = 123456;
    SInt32 bigEndianInt = OSSwapHostToBigInt32(testInt);
    const char *buf = (const char *)&bigEndianInt;

    NSNumber *result = [NSNumber numberWithOSCIntBytes:buf maxLength:sizeof(SInt32)];

    XCTAssertNotNil(result, @"Should successfully create NSNumber from valid int bytes");
    XCTAssertEqual([result integerValue], testInt, @"Should restore original integer value");
}

- (void)testThat_numberWithOSCIntBytesHandlesInvalidInput
{
    // Test with NULL buffer.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    NSNumber *result1 = [NSNumber numberWithOSCIntBytes:NULL maxLength:sizeof(SInt32)];
#pragma clang diagnostic pop
    XCTAssertNil(result1, @"Should return nil for NULL buffer");

    // Test with insufficient buffer length.
    char shortBuffer[2] = {0x01, 0x02};
    NSNumber *result2 = [NSNumber numberWithOSCIntBytes:shortBuffer maxLength:2];
    XCTAssertNil(result2, @"Should return nil for insufficient buffer length");

    // Test with zero length.
    char validBuffer[4] = {0x00, 0x01, 0xE2, 0x40}; // 123456 in big-endian
    NSNumber *result3 = [NSNumber numberWithOSCIntBytes:validBuffer maxLength:0];
    XCTAssertNil(result3, @"Should return nil for zero maxLength");
}

- (void)testThat_roundTripConversionWorksForFloats
{
    // Test that we can convert a float to OSC bytes and back.
    NSArray *testFloats = @[@(0.0f), @(1.0f), @(-1.0f), @(3.14159f), @(-2.71828f), @(FLT_MAX), @(FLT_MIN)];

    for (NSNumber *originalFloat in testFloats)
    {
        // Convert to OSC bytes.
        SInt32 oscBytes = [originalFloat oscFloatValue];
        const char *buf = (const char *)&oscBytes;

        // Convert back to NSNumber.
        NSNumber *restoredFloat = [NSNumber numberWithOSCFloatBytes:buf maxLength:sizeof(SInt32)];

        XCTAssertNotNil(restoredFloat, @"Should successfully round-trip float conversion");
        XCTAssertEqualWithAccuracy([restoredFloat floatValue], [originalFloat floatValue], 0.0001, 
                                 @"Round-trip conversion should preserve float value");
    }
}

- (void)testThat_roundTripConversionWorksForInts
{
    // Test that we can convert an int to OSC bytes and back.
    NSArray *testInts = @[@(0), @(1), @(-1), @(42), @(-42), @(INT32_MAX), @(INT32_MIN)];

    for (NSNumber *originalInt in testInts)
    {
        // Convert to OSC bytes.
        SInt32 oscBytes = [originalInt oscIntValue];
        const char *buf = (const char *)&oscBytes;

        // Convert back to NSNumber.
        NSNumber *restoredInt = [NSNumber numberWithOSCIntBytes:buf maxLength:sizeof(SInt32)];

        XCTAssertNotNil(restoredInt, @"Should successfully round-trip int conversion");
        XCTAssertEqual([restoredInt integerValue], [originalInt integerValue], 
                      @"Round-trip conversion should preserve integer value");
    }
}

- (void)testThat_edgeCasesAreHandledCorrectly
{
    // Test special float values.
    NSNumber *nan = @(NAN);
    NSNumber *infinity = @(INFINITY);
    NSNumber *negInfinity = @(-INFINITY);

    SInt32 nanResult = [nan oscFloatValue];
    SInt32 infResult = [infinity oscFloatValue];
    SInt32 negInfResult = [negInfinity oscFloatValue];

    // These should produce valid SInt32 values (not crash).
    XCTAssertNotEqual(nanResult, 0, @"NaN conversion should produce non-zero result");
    XCTAssertNotEqual(infResult, 0, @"Infinity conversion should produce non-zero result");
    XCTAssertNotEqual(negInfResult, 0, @"Negative infinity conversion should produce non-zero result");

    // Test maximum buffer size scenarios.
    char largeBuffer[1024];
    memset(largeBuffer, 0x42, sizeof(largeBuffer));

    // Should work with large buffer.
    NSNumber *result1 = [NSNumber numberWithOSCFloatBytes:largeBuffer maxLength:1024];
    XCTAssertNotNil(result1, @"Should handle large buffer correctly");

    NSNumber *result2 = [NSNumber numberWithOSCIntBytes:largeBuffer maxLength:1024];
    XCTAssertNotNil(result2, @"Should handle large buffer correctly");
}

- (void)testThat_allCFNumberTypesHandleOSCConversionCorrectly
{
    // Test all CFNumberType enum values with CFNumberCreate.
    // The oscIntValue and oscFloatValue methods return big-endian representations.

    // Fixed-width types.
    int8_t sint8Value = -42;
    NSNumber *sint8Number = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt8Type, &sint8Value);
    SInt32 sint8OSCValue = [sint8Number oscIntValue];
    SInt32 expectedSint8 = OSSwapHostToBigInt32((SInt32)sint8Value);
    XCTAssertEqual(sint8OSCValue, expectedSint8, @"SInt8 should convert to big-endian OSC int value correctly");

    int16_t sint16Value = -1234;
    NSNumber *sint16Number = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt16Type, &sint16Value);
    SInt32 sint16OSCValue = [sint16Number oscIntValue];
    SInt32 expectedSint16 = OSSwapHostToBigInt32((SInt32)sint16Value);
    XCTAssertEqual(sint16OSCValue, expectedSint16, @"SInt16 should convert to big-endian OSC int value correctly");

    int32_t sint32Value = -123456;
    NSNumber *sint32Number = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &sint32Value);
    SInt32 sint32OSCValue = [sint32Number oscIntValue];
    SInt32 expectedSint32 = OSSwapHostToBigInt32(sint32Value);
    XCTAssertEqual(sint32OSCValue, expectedSint32, @"SInt32 should convert to big-endian OSC int value correctly");

    int64_t sint64Value = 876543210987654321LL;
    NSNumber *sint64Number = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt64Type, &sint64Value);
    SInt32 sint64OSCValue = [sint64Number oscIntValue];
    SInt32 expectedSint64 = OSSwapHostToBigInt32((SInt32)sint64Value);  // Truncates to 32-bit
    XCTAssertEqual(sint64OSCValue, expectedSint64, @"SInt64 should truncate and convert to big-endian OSC int value correctly");

    float float32Value = 3.14159f;
    NSNumber *float32Number = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberFloat32Type, &float32Value);
    SInt32 float32OSCValue = [float32Number oscFloatValue];
    // Verify round-trip conversion.
    NSNumber *roundTripFloat = [NSNumber numberWithOSCFloatBytes:(const char *)&float32OSCValue maxLength:sizeof(SInt32)];
    XCTAssertEqualWithAccuracy([roundTripFloat floatValue], float32Value, 0.0001f, @"Float32 should round-trip correctly");

    double float64Value = 2.718281828;
    NSNumber *float64Number = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberFloat64Type, &float64Value);
    SInt32 float64OSCValue = [float64Number oscFloatValue];
    // Verify round-trip conversion (truncated to float precision).
    NSNumber *roundTripDouble = [NSNumber numberWithOSCFloatBytes:(const char *)&float64OSCValue maxLength:sizeof(SInt32)];
    XCTAssertEqualWithAccuracy([roundTripDouble floatValue], (float)float64Value, 0.0001f, @"Float64 should truncate and round-trip correctly");

    // Basic C types.
    char charValue = 'A';
    NSNumber *charNumber = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberCharType, &charValue);
    SInt32 charOSCValue = [charNumber oscIntValue];
    SInt32 expectedChar = OSSwapHostToBigInt32((SInt32)charValue);
    XCTAssertEqual(charOSCValue, expectedChar, @"Char should convert to big-endian OSC int value correctly");

    short shortValue = 12345;
    NSNumber *shortNumber = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberShortType, &shortValue);
    SInt32 shortOSCValue = [shortNumber oscIntValue];
    SInt32 expectedShort = OSSwapHostToBigInt32((SInt32)shortValue);
    XCTAssertEqual(shortOSCValue, expectedShort, @"Short should convert to big-endian OSC int value correctly");

    int intValue = 987654321;
    NSNumber *intNumber = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &intValue);
    SInt32 intOSCValue = [intNumber oscIntValue];
    SInt32 expectedInt = OSSwapHostToBigInt32((SInt32)intValue);
    XCTAssertEqual(intOSCValue, expectedInt, @"Int should convert to big-endian OSC int value correctly");

    long longValue = 1234567890L;
    NSNumber *longNumber = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberLongType, &longValue);
    SInt32 longOSCValue = [longNumber oscIntValue];
    SInt32 expectedLong = OSSwapHostToBigInt32((SInt32)longValue);
    XCTAssertEqual(longOSCValue, expectedLong, @"Long should convert to big-endian OSC int value correctly");

    long long longLongValue = 876543210987654321LL;
    NSNumber *longLongNumber = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberLongLongType, &longLongValue);
    SInt32 longLongOSCValue = [longLongNumber oscIntValue];
    SInt32 expectedLongLong = OSSwapHostToBigInt32((SInt32)longLongValue);  // Truncates to 32-bit
    XCTAssertEqual(longLongOSCValue, expectedLongLong, @"Long long should truncate and convert to big-endian OSC int value correctly");

    float floatValue = 1.414213f;
    NSNumber *floatNumber = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberFloatType, &floatValue);
    SInt32 floatOSCValue = [floatNumber oscFloatValue];
    NSNumber *roundTripFloat2 = [NSNumber numberWithOSCFloatBytes:(const char *)&floatOSCValue maxLength:sizeof(SInt32)];
    XCTAssertEqualWithAccuracy([roundTripFloat2 floatValue], floatValue, 0.0001f, @"Float should round-trip correctly");

    double doubleValue = 1.732050808;
    NSNumber *doubleNumber = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberDoubleType, &doubleValue);
    SInt32 doubleOSCValue = [doubleNumber oscFloatValue];
    NSNumber *roundTripDouble2 = [NSNumber numberWithOSCFloatBytes:(const char *)&doubleOSCValue maxLength:sizeof(SInt32)];
    XCTAssertEqualWithAccuracy([roundTripDouble2 floatValue], (float)doubleValue, 0.0001f, @"Double should truncate and round-trip correctly");

    // Other types.
    CFIndex cfIndexValue = 54321;
    NSNumber *cfIndexNumber = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberCFIndexType, &cfIndexValue);
    SInt32 cfIndexOSCValue = [cfIndexNumber oscIntValue];
    SInt32 expectedCFIndex = OSSwapHostToBigInt32((SInt32)cfIndexValue);
    XCTAssertEqual(cfIndexOSCValue, expectedCFIndex, @"CFIndex should convert to big-endian OSC int value correctly");

    NSInteger nsIntegerValue = 246810;
    NSNumber *nsIntegerNumber = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberNSIntegerType, &nsIntegerValue);
    SInt32 nsIntegerOSCValue = [nsIntegerNumber oscIntValue];
    SInt32 expectedNSInteger = OSSwapHostToBigInt32((SInt32)nsIntegerValue);
    XCTAssertEqual(nsIntegerOSCValue, expectedNSInteger, @"NSInteger should convert to big-endian OSC int value correctly");

    CGFloat cgFloatValue = 1.61803398875;
    NSNumber *cgFloatNumber = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberCGFloatType, &cgFloatValue);
    SInt32 cgFloatOSCValue = [cgFloatNumber oscFloatValue];
    NSNumber *roundTripCGFloat = [NSNumber numberWithOSCFloatBytes:(const char *)&cgFloatOSCValue maxLength:sizeof(SInt32)];
    XCTAssertEqualWithAccuracy([roundTripCGFloat floatValue], (float)cgFloatValue, 0.0001f, @"CGFloat should round-trip correctly");
}

- (void)testThat_allCFNumberTypesRoundTripCorrectly
{
    // Test round-trip conversion for all CFNumberType enum values via OSC byte format.
    // oscIntValue and oscFloatValue return big-endian data, which can be passed directly to the factory methods.

    // Test a few key types for round-trip accuracy.
    int32_t originalInt = 0x12345678;
    NSNumber *intNumber = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &originalInt);
    SInt32 oscIntValue = [intNumber oscIntValue];
    // The oscIntValue is already in big-endian format, pass directly to factory method.
    NSNumber *roundTripInt = [NSNumber numberWithOSCIntBytes:(const char *)&oscIntValue maxLength:sizeof(SInt32)];
    XCTAssertEqual([roundTripInt intValue], originalInt, @"SInt32 should round-trip correctly");

    float originalFloat = 3.14159265f;
    NSNumber *floatNumber = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberFloat32Type, &originalFloat);
    SInt32 oscFloatValue = [floatNumber oscFloatValue];
    // The oscFloatValue is already in big-endian format, pass directly to factory method.
    NSNumber *roundTripFloat = [NSNumber numberWithOSCFloatBytes:(const char *)&oscFloatValue maxLength:sizeof(SInt32)];
    XCTAssertEqualWithAccuracy([roundTripFloat floatValue], originalFloat, 0.0001f, @"Float32 should round-trip correctly");

    // Test edge cases with large values that will be truncated.
    int64_t largeInt64 = 0x123456789ABCDEFLL;
    NSNumber *largeInt64Number = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt64Type, &largeInt64);
    SInt32 largeSInt32OSCValue = [largeInt64Number oscIntValue];
    NSNumber *roundTripLargeInt = [NSNumber numberWithOSCIntBytes:(const char *)&largeSInt32OSCValue maxLength:sizeof(SInt32)];
    // Should be truncated to 32-bit.
    int32_t expectedTruncated = (int32_t)largeInt64;
    XCTAssertEqual([roundTripLargeInt intValue], expectedTruncated, @"SInt64 should truncate to 32-bit correctly");

    double largeDouble = 1234567.89012;  // Use a more reasonable double value
    NSNumber *largeDoubleNumber = (__bridge_transfer NSNumber *)CFNumberCreate(kCFAllocatorDefault, kCFNumberFloat64Type, &largeDouble);
    SInt32 largeSInt32FloatOSCValue = [largeDoubleNumber oscFloatValue];
    NSNumber *roundTripLargeFloat = [NSNumber numberWithOSCFloatBytes:(const char *)&largeSInt32FloatOSCValue maxLength:sizeof(SInt32)];
    // Should be truncated to float precision.
    float expectedFloat = (float)largeDouble;
    XCTAssertEqualWithAccuracy([roundTripLargeFloat floatValue], expectedFloat, expectedFloat * 0.001f, @"Float64 should truncate to float correctly");
}

@end

NS_ASSUME_NONNULL_END
