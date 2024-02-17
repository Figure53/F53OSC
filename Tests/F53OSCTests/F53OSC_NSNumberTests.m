//
//  F53OSC_NSNumberTests.m
//  F53OSC
//
//  Created by Brent Lord on 2/12/20.
//  Copyright (c) 2020-2024 Figure 53. All rights reserved.
//

#if !__has_feature(objc_arc)
#error This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import "F53OSCMessage.h"


NS_ASSUME_NONNULL_BEGIN

@interface F53OSC_NSNumberTests : XCTestCase
@end


@implementation F53OSC_NSNumberTests

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

- (void) testThat_NSNumberLiteralsAreEqual
{
    // ensure parentheses do not affect the value
    XCTAssertEqualObjects( @YES,        @(YES) );
    XCTAssertEqualObjects( @NO,         @(NO) );
    XCTAssertEqualObjects( @1,          @(1) );
    XCTAssertEqualObjects( @0,          @(0) );
    XCTAssertEqualObjects( @-1,         @(-1) );
    XCTAssertEqualObjects( @1.0f,       @(1.0f) );
    XCTAssertEqualObjects( @0.0f,       @(0.0f) );
    XCTAssertEqualObjects( @-1.0f,      @(-1.0f) );
    XCTAssertEqualObjects( @1.0,        @(1.0) );
    XCTAssertEqualObjects( @0.0,        @(0.0) );
    XCTAssertEqualObjects( @-1.0,       @(-1.0) );
    XCTAssertEqualObjects( @CHAR_MIN,   @(CHAR_MIN) );
    XCTAssertEqualObjects( @CHAR_MAX,   @(CHAR_MAX) );
    XCTAssertEqualObjects( @SCHAR_MIN,  @(SCHAR_MIN) );
    XCTAssertEqualObjects( @SCHAR_MAX,  @(SCHAR_MAX) );
    XCTAssertEqualObjects( @UCHAR_MAX,  @(UCHAR_MAX) );
    XCTAssertEqualObjects( @SHRT_MIN,   @(SHRT_MIN) );
    XCTAssertEqualObjects( @SHRT_MAX,   @(SHRT_MAX) );
    XCTAssertEqualObjects( @USHRT_MAX,  @(USHRT_MAX) );
    XCTAssertEqualObjects( @INT_MIN,    @(INT_MIN) );
    XCTAssertEqualObjects( @INT_MAX,    @(INT_MAX) );
    XCTAssertEqualObjects( @UINT_MAX,   @(UINT_MAX) );
    XCTAssertEqualObjects( @INT8_MIN,   @(INT8_MIN) );
    XCTAssertEqualObjects( @INT8_MAX,   @(INT8_MAX) );
    XCTAssertEqualObjects( @UINT8_MAX,  @(UINT8_MAX) );
    XCTAssertEqualObjects( @INT16_MIN,  @(INT16_MIN) );
    XCTAssertEqualObjects( @INT16_MAX,  @(INT16_MAX) );
    XCTAssertEqualObjects( @UINT16_MAX, @(UINT16_MAX) );
    XCTAssertEqualObjects( @INT32_MIN,  @(INT32_MIN) );
    XCTAssertEqualObjects( @INT32_MAX,  @(INT32_MAX) );
    XCTAssertEqualObjects( @UINT32_MAX, @(UINT32_MAX) );
    XCTAssertEqualObjects( @INT64_MIN,  @(INT64_MIN) );
    XCTAssertEqualObjects( @INT64_MAX,  @(INT64_MAX) );
    XCTAssertEqualObjects( @UINT64_MAX, @(UINT64_MAX) );
    XCTAssertEqualObjects( @LONG_MAX,   @(LONG_MAX) );
    XCTAssertEqualObjects( @ULONG_MAX,  @(ULONG_MAX) );
    XCTAssertEqualObjects( @FLT_MIN,    @(FLT_MIN) );
    XCTAssertEqualObjects( @FLT_MAX,    @(FLT_MAX) );
    XCTAssertEqualObjects( @DBL_MIN,    @(DBL_MIN) );
    XCTAssertEqualObjects( @DBL_MAX,    @(DBL_MAX) );

    // ensure parentheses do not affect the CFNumberRef type
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@YES ),           CFNumberGetType( (CFNumberRef)@(YES) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@NO ),            CFNumberGetType( (CFNumberRef)@(NO) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@1 ),             CFNumberGetType( (CFNumberRef)@(1) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@0 ),             CFNumberGetType( (CFNumberRef)@(0) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@-1 ),            CFNumberGetType( (CFNumberRef)@(-1) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@1.0f ),          CFNumberGetType( (CFNumberRef)@(1.0f) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@0.0f ),          CFNumberGetType( (CFNumberRef)@(0.0f) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@-1.0f ),         CFNumberGetType( (CFNumberRef)@(-1.0f) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@1.0 ),           CFNumberGetType( (CFNumberRef)@(1.0) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@0.0 ),           CFNumberGetType( (CFNumberRef)@(0.0) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@-1.0 ),          CFNumberGetType( (CFNumberRef)@(-1.0) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@CHAR_MIN ),      CFNumberGetType( (CFNumberRef)@(CHAR_MIN) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@CHAR_MAX ),      CFNumberGetType( (CFNumberRef)@(CHAR_MAX) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@SCHAR_MIN ),     CFNumberGetType( (CFNumberRef)@(SCHAR_MIN) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@SCHAR_MAX ),     CFNumberGetType( (CFNumberRef)@(SCHAR_MAX) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@UCHAR_MAX ),     CFNumberGetType( (CFNumberRef)@(UCHAR_MAX) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@SHRT_MIN ),      CFNumberGetType( (CFNumberRef)@(SHRT_MIN) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@SHRT_MAX ),      CFNumberGetType( (CFNumberRef)@(SHRT_MAX) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@USHRT_MAX ),     CFNumberGetType( (CFNumberRef)@(USHRT_MAX) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@INT_MIN ),       CFNumberGetType( (CFNumberRef)@(INT_MIN) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@INT_MAX ),       CFNumberGetType( (CFNumberRef)@(INT_MAX) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@UINT_MAX ),      CFNumberGetType( (CFNumberRef)@(UINT_MAX) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@INT8_MIN ),      CFNumberGetType( (CFNumberRef)@(INT8_MIN) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@INT8_MAX ),      CFNumberGetType( (CFNumberRef)@(INT8_MAX) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@UINT8_MAX ),     CFNumberGetType( (CFNumberRef)@(UINT8_MAX) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@INT16_MIN ),     CFNumberGetType( (CFNumberRef)@(INT16_MIN) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@INT16_MAX ),     CFNumberGetType( (CFNumberRef)@(INT16_MAX) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@UINT16_MAX ),    CFNumberGetType( (CFNumberRef)@(UINT16_MAX) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@INT32_MIN ),     CFNumberGetType( (CFNumberRef)@(INT32_MIN) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@INT32_MAX ),     CFNumberGetType( (CFNumberRef)@(INT32_MAX) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@UINT32_MAX ),    CFNumberGetType( (CFNumberRef)@(UINT32_MAX) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@INT64_MIN ),     CFNumberGetType( (CFNumberRef)@(INT64_MIN) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@INT64_MAX ),     CFNumberGetType( (CFNumberRef)@(INT64_MAX) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@UINT64_MAX ),    CFNumberGetType( (CFNumberRef)@(UINT64_MAX) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@LONG_MAX ),      CFNumberGetType( (CFNumberRef)@(LONG_MAX) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@ULONG_MAX ),     CFNumberGetType( (CFNumberRef)@(ULONG_MAX) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@FLT_MIN ),       CFNumberGetType( (CFNumberRef)@(FLT_MIN) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@FLT_MAX ),       CFNumberGetType( (CFNumberRef)@(FLT_MAX) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@DBL_MIN ),       CFNumberGetType( (CFNumberRef)@(DBL_MIN) ) );
    XCTAssertEqual( CFNumberGetType( (CFNumberRef)@DBL_MAX ),       CFNumberGetType( (CFNumberRef)@(DBL_MAX) ) );

    // ensure NSNumber literals are equal to initialized numbers
    XCTAssertEqualObjects( @(YES),          [NSNumber numberWithBool:YES] );
    XCTAssertEqualObjects( @(NO),           [NSNumber numberWithBool:NO] );
    XCTAssertEqualObjects( @(1),            [NSNumber numberWithShort:1] );
    XCTAssertEqualObjects( @(0),            [NSNumber numberWithShort:0] );
    XCTAssertEqualObjects( @(-1),           [NSNumber numberWithShort:-1] );
    XCTAssertEqualObjects( @(1),            [NSNumber numberWithUnsignedShort:1] );
    XCTAssertEqualObjects( @(1),            [NSNumber numberWithInt:1] );
    XCTAssertEqualObjects( @(0),            [NSNumber numberWithInt:0] );
    XCTAssertEqualObjects( @(-1),           [NSNumber numberWithInt:-1] );
    XCTAssertEqualObjects( @(1),            [NSNumber numberWithUnsignedInt:1] );
    XCTAssertEqualObjects( @(1),            [NSNumber numberWithLong:1] );
    XCTAssertEqualObjects( @(0),            [NSNumber numberWithLong:0] );
    XCTAssertEqualObjects( @(-1),           [NSNumber numberWithLong:-1] );
    XCTAssertEqualObjects( @(1),            [NSNumber numberWithUnsignedLong:1] );
    XCTAssertEqualObjects( @(1),            [NSNumber numberWithLongLong:1] );
    XCTAssertEqualObjects( @(0),            [NSNumber numberWithLongLong:0] );
    XCTAssertEqualObjects( @(-1),           [NSNumber numberWithLongLong:-1] );
    XCTAssertEqualObjects( @(1),            [NSNumber numberWithUnsignedLongLong:1] );
    XCTAssertEqualObjects( @(1),            [NSNumber numberWithInteger:1] );
    XCTAssertEqualObjects( @(0),            [NSNumber numberWithInteger:0] );
    XCTAssertEqualObjects( @(-1),           [NSNumber numberWithInteger:-1] );
    XCTAssertEqualObjects( @(1),            [NSNumber numberWithUnsignedInteger:1] );
    XCTAssertEqualObjects( @(1.0f),         [NSNumber numberWithFloat:1.0f] );
    XCTAssertEqualObjects( @(0.0f),         [NSNumber numberWithFloat:0.0f] );
    XCTAssertEqualObjects( @(-1.0f),        [NSNumber numberWithFloat:-1.0f] );
    XCTAssertEqualObjects( @(1.0),          [NSNumber numberWithDouble:1.0] );
    XCTAssertEqualObjects( @(0.0),          [NSNumber numberWithDouble:0.0] );
    XCTAssertEqualObjects( @(-1.0),         [NSNumber numberWithDouble:-1.0] );
    XCTAssertEqualObjects( @(CHAR_MIN),     [NSNumber numberWithChar:CHAR_MIN] );
    XCTAssertEqualObjects( @(CHAR_MAX),     [NSNumber numberWithChar:CHAR_MAX] );
    XCTAssertEqualObjects( @(SCHAR_MIN),    [NSNumber numberWithChar:SCHAR_MIN] );
    XCTAssertEqualObjects( @(SCHAR_MAX),    [NSNumber numberWithChar:SCHAR_MAX] );
    XCTAssertEqualObjects( @(UCHAR_MAX),    [NSNumber numberWithUnsignedChar:UCHAR_MAX] );
    XCTAssertEqualObjects( @(SHRT_MIN),     [NSNumber numberWithShort:SHRT_MIN] );
    XCTAssertEqualObjects( @(SHRT_MAX),     [NSNumber numberWithShort:SHRT_MAX] );
    XCTAssertEqualObjects( @(USHRT_MAX),    [NSNumber numberWithUnsignedShort:USHRT_MAX] );
    XCTAssertEqualObjects( @(INT_MIN),      [NSNumber numberWithInt:INT_MIN] );
    XCTAssertEqualObjects( @(INT_MAX),      [NSNumber numberWithInt:INT_MAX] );
    XCTAssertEqualObjects( @(UINT_MAX),     [NSNumber numberWithUnsignedInt:UINT_MAX] );
    XCTAssertEqualObjects( @(INT8_MIN),     [NSNumber numberWithShort:INT8_MIN] );
    XCTAssertEqualObjects( @(INT8_MAX),     [NSNumber numberWithShort:INT8_MAX] );
    XCTAssertEqualObjects( @(UINT8_MAX),    [NSNumber numberWithShort:UINT8_MAX] );
    XCTAssertEqualObjects( @(INT16_MIN),    [NSNumber numberWithShort:INT16_MIN] );
    XCTAssertEqualObjects( @(INT16_MAX),    [NSNumber numberWithShort:INT16_MAX] );
    XCTAssertEqualObjects( @(UINT16_MAX),   [NSNumber numberWithUnsignedShort:UINT16_MAX] );
    XCTAssertEqualObjects( @(INT32_MIN),    [NSNumber numberWithInt:INT32_MIN] );
    XCTAssertEqualObjects( @(INT32_MAX),    [NSNumber numberWithInt:INT32_MAX] );
    XCTAssertEqualObjects( @(UINT32_MAX),   [NSNumber numberWithUnsignedInt:UINT32_MAX] );
    XCTAssertEqualObjects( @(INT64_MIN),    [NSNumber numberWithLong:INT64_MIN] );
    XCTAssertEqualObjects( @(INT64_MAX),    [NSNumber numberWithLong:INT64_MAX] );
    XCTAssertEqualObjects( @(UINT64_MAX),   [NSNumber numberWithUnsignedLong:UINT64_MAX] );
    XCTAssertEqualObjects( @(LONG_MAX),     [NSNumber numberWithLong:LONG_MAX] );
    XCTAssertEqualObjects( @(ULONG_MAX),    [NSNumber numberWithUnsignedLong:ULONG_MAX] );
    XCTAssertEqualObjects( @(FLT_MIN),      [NSNumber numberWithFloat:FLT_MIN] );
    XCTAssertEqualObjects( @(FLT_MAX),      [NSNumber numberWithFloat:FLT_MAX] );
    XCTAssertEqualObjects( @(DBL_MIN),      [NSNumber numberWithDouble:DBL_MIN] );
    XCTAssertEqualObjects( @(DBL_MAX),      [NSNumber numberWithDouble:DBL_MAX] );
}

- (void) testThat_ArgumentTagFromNSNumberIsCorrect
{
    // given
    // - { tag : [numbers] }
    NSDictionary<NSString *, NSArray<NSNumber *> *> *tagsAndNumbers =
    @{
        @"i" : @[ // OSC integer
            // Char
            @(YES),
            @(NO),
            [NSNumber numberWithBool:YES],
            [NSNumber numberWithBool:NO],

            // SInt8
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

            // SInt16
            [NSNumber numberWithUnsignedChar:CHAR_MIN],
            [NSNumber numberWithUnsignedChar:CHAR_MAX],
            [NSNumber numberWithUnsignedChar:UCHAR_MAX],
            [NSNumber numberWithUnsignedChar:'1'],
            [NSNumber numberWithUnsignedChar:'0'],
            [NSNumber numberWithShort:SHRT_MIN],
            [NSNumber numberWithShort:SHRT_MAX],
            [NSNumber numberWithShort:INT8_MIN],
            [NSNumber numberWithShort:INT8_MAX],
            [NSNumber numberWithShort:INT16_MIN],
            [NSNumber numberWithShort:INT16_MAX],
            [NSNumber numberWithShort:1],
            [NSNumber numberWithShort:0],
            [NSNumber numberWithShort:-1],

            // SInt32
            @(CHAR_MIN),
            @(CHAR_MAX),
            @(SCHAR_MIN),
            @(SCHAR_MAX),
            @(SHRT_MIN),
            @(SHRT_MAX),
            @(UCHAR_MAX),
            @(INT8_MIN),
            @(INT8_MAX),
            @(USHRT_MAX),
            @(INT16_MIN),
            @(INT16_MAX),
            @(INT32_MIN),
            @(INT32_MAX),
            @(INT_MIN),
            @(INT_MAX),
            @1,
            @0,
            @-1,
            @(1),
            @(0),
            @(-1),
            [NSNumber numberWithUnsignedShort:USHRT_MAX],
            [NSNumber numberWithUnsignedShort:INT16_MIN],
            [NSNumber numberWithUnsignedShort:INT16_MAX],
            [NSNumber numberWithUnsignedShort:1],
            [NSNumber numberWithUnsignedShort:0],
            [NSNumber numberWithInt:INT32_MIN],
            [NSNumber numberWithInt:INT32_MAX],
            [NSNumber numberWithInt:INT_MIN],
            [NSNumber numberWithInt:INT_MAX],
            [NSNumber numberWithInt:1],
            [NSNumber numberWithInt:0],
            [NSNumber numberWithInt:-1],

            // SInt64
            @(UINT_MAX),
            @(LONG_MIN),
            @(LONG_MAX),
            @(ULONG_MAX),
            [NSNumber numberWithUnsignedInt:INT32_MIN],
            [NSNumber numberWithUnsignedInt:INT32_MAX],
            [NSNumber numberWithUnsignedInt:UINT_MAX],
            [NSNumber numberWithUnsignedInt:1],
            [NSNumber numberWithUnsignedInt:0],
            [NSNumber numberWithLong:LONG_MIN],
            [NSNumber numberWithLong:LONG_MAX],
            [NSNumber numberWithLong:1],
            [NSNumber numberWithLong:0],
            [NSNumber numberWithLong:-1],
            [NSNumber numberWithUnsignedLong:ULONG_MAX],
            [NSNumber numberWithUnsignedLong:1],
            [NSNumber numberWithUnsignedLong:0],
            [NSNumber numberWithLongLong:1],
            [NSNumber numberWithLongLong:0],
            [NSNumber numberWithLongLong:-1],
            [NSNumber numberWithUnsignedLongLong:1],
            [NSNumber numberWithUnsignedLongLong:0],
            [NSNumber numberWithInteger:1],
            [NSNumber numberWithInteger:0],
            [NSNumber numberWithInteger:-1],
            [NSNumber numberWithUnsignedInteger:1],
            [NSNumber numberWithUnsignedInteger:0],
        ],

        @"f" : @[ // OSC float
            // Float32
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

            // Float64
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
        ],
    };
    
    // when
    
    // then
    for ( NSString *expectedTag in tagsAndNumbers )
    {
        NSArray<NSNumber *> *numbers = tagsAndNumbers[expectedTag];
        for ( NSNumber *number in numbers )
        {
            NSString *actualTag = [F53OSCMessage tagForArgument:number];
            XCTAssertEqualObjects( actualTag, expectedTag );
        }
    }
}

@end

NS_ASSUME_NONNULL_END
