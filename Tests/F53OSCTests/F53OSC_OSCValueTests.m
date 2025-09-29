//
//  F53OSC_OSCValueTests.m
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

#import "F53OSCValue.h"


NS_ASSUME_NONNULL_BEGIN

#pragma mark - MockCoder

@interface MockCoder : NSCoder
@property (nonatomic) int mockIntValue;
@end


#pragma mark - F53OSC_OSCValueTests

@interface F53OSC_OSCValueTests : XCTestCase
@end

@implementation F53OSC_OSCValueTests

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


#pragma mark - F53OSCValue tests

- (void)testThat_F53OSCValueIsValidSubclassOfNSValue
{
    F53OSCValue *oscTrue = [F53OSCValue oscTrue];
    F53OSCValue *oscFalse = [F53OSCValue oscFalse];
    F53OSCValue *oscNull = [F53OSCValue oscNull];
    F53OSCValue *oscImpulse = [F53OSCValue oscImpulse];

    const char T = 'T';
    const char F = 'F';
    const char N = 'N';
    const char I = 'I';

    XCTAssertNotNil(oscTrue);
    XCTAssertNotNil(oscFalse);
    XCTAssertNotNil(oscNull);
    XCTAssertNotNil(oscImpulse);

    // equality
    XCTAssertTrue([oscTrue isMemberOfClass:[F53OSCValue class]]);
    XCTAssertTrue([oscFalse isMemberOfClass:[F53OSCValue class]]);
    XCTAssertTrue([oscNull isMemberOfClass:[F53OSCValue class]]);
    XCTAssertTrue([oscImpulse isMemberOfClass:[F53OSCValue class]]);

    XCTAssertTrue([oscTrue isKindOfClass:[NSValue class]]);
    XCTAssertTrue([oscFalse isKindOfClass:[NSValue class]]);
    XCTAssertTrue([oscNull isKindOfClass:[NSValue class]]);
    XCTAssertTrue([oscImpulse isKindOfClass:[NSValue class]]);

    XCTAssertTrue([[[F53OSCValue alloc] initWithBytes:&T objCType:@encode(char)] isKindOfClass:[NSValue class]]);
    XCTAssertTrue([[[F53OSCValue alloc] initWithBytes:&F objCType:@encode(char)] isKindOfClass:[NSValue class]]);
    XCTAssertTrue([[[F53OSCValue alloc] initWithBytes:&N objCType:@encode(char)] isKindOfClass:[NSValue class]]);
    XCTAssertTrue([[[F53OSCValue alloc] initWithBytes:&I objCType:@encode(char)] isKindOfClass:[NSValue class]]);

    XCTAssertTrue([[[F53OSCValue alloc] initWithBytes:&T objCType:@encode(char)] isMemberOfClass:[F53OSCValue class]]);
    XCTAssertTrue([[[F53OSCValue alloc] initWithBytes:&F objCType:@encode(char)] isMemberOfClass:[F53OSCValue class]]);
    XCTAssertTrue([[[F53OSCValue alloc] initWithBytes:&N objCType:@encode(char)] isMemberOfClass:[F53OSCValue class]]);
    XCTAssertTrue([[[F53OSCValue alloc] initWithBytes:&I objCType:@encode(char)] isMemberOfClass:[F53OSCValue class]]);

    XCTAssertTrue([[F53OSCValue valueWithBytes:&T objCType:@encode(char)] isKindOfClass:[NSValue class]]);
    XCTAssertTrue([[F53OSCValue valueWithBytes:&F objCType:@encode(char)] isKindOfClass:[NSValue class]]);
    XCTAssertTrue([[F53OSCValue valueWithBytes:&N objCType:@encode(char)] isKindOfClass:[NSValue class]]);
    XCTAssertTrue([[F53OSCValue valueWithBytes:&I objCType:@encode(char)] isKindOfClass:[NSValue class]]);

    XCTAssertTrue([[F53OSCValue valueWithBytes:&T objCType:@encode(char)] isMemberOfClass:[F53OSCValue class]]);
    XCTAssertTrue([[F53OSCValue valueWithBytes:&F objCType:@encode(char)] isMemberOfClass:[F53OSCValue class]]);
    XCTAssertTrue([[F53OSCValue valueWithBytes:&N objCType:@encode(char)] isMemberOfClass:[F53OSCValue class]]);
    XCTAssertTrue([[F53OSCValue valueWithBytes:&I objCType:@encode(char)] isMemberOfClass:[F53OSCValue class]]);

    XCTAssertEqual(oscTrue.boolValue, YES);
    XCTAssertEqualObjects(oscTrue, [F53OSCValue oscTrue]);
    XCTAssertTrue([oscTrue isEqual:[F53OSCValue oscTrue]]);
    XCTAssertTrue([oscTrue isEqualToValue:[F53OSCValue oscTrue]]);
    XCTAssertEqualObjects(oscTrue, [F53OSCValue valueWithBytes:&T objCType:@encode(char)]);
    XCTAssertTrue([oscTrue isEqual:[F53OSCValue valueWithBytes:&T objCType:@encode(char)]]);
    XCTAssertTrue([oscTrue isEqualToValue:[F53OSCValue valueWithBytes:&T objCType:@encode(char)]]);
    XCTAssertEqualObjects(oscTrue, [NSNumber numberWithChar:'T']);
    XCTAssertEqualObjects(oscTrue, [NSValue value:&T withObjCType:@encode(char)]);
    XCTAssertTrue([oscTrue isEqual:[NSValue value:&T withObjCType:@encode(char)]]);
    XCTAssertTrue([oscTrue isEqualToValue:[NSValue value:&T withObjCType:@encode(char)]]);
    XCTAssertTrue([[NSValue value:&T withObjCType:@encode(char)] isEqual:oscTrue]);
    XCTAssertTrue([[NSValue value:&T withObjCType:@encode(char)] isEqualToValue:oscTrue]);

    XCTAssertEqual(oscFalse.boolValue, NO);
    XCTAssertEqualObjects(oscFalse, [F53OSCValue oscFalse]);
    XCTAssertTrue([oscFalse isEqual:[F53OSCValue oscFalse]]);
    XCTAssertTrue([oscFalse isEqualToValue:[F53OSCValue oscFalse]]);
    XCTAssertEqualObjects(oscFalse, [F53OSCValue valueWithBytes:&F objCType:@encode(char)]);
    XCTAssertTrue([oscFalse isEqual:[F53OSCValue valueWithBytes:&F objCType:@encode(char)]]);
    XCTAssertTrue([oscFalse isEqualToValue:[F53OSCValue valueWithBytes:&F objCType:@encode(char)]]);
    XCTAssertEqualObjects(oscFalse, [NSNumber numberWithChar:'F']);
    XCTAssertEqualObjects(oscFalse, [NSValue value:&F withObjCType:@encode(char)]);
    XCTAssertTrue([oscFalse isEqual:[NSValue value:&F withObjCType:@encode(char)]]);
    XCTAssertTrue([oscFalse isEqualToValue:[NSValue value:&F withObjCType:@encode(char)]]);
    XCTAssertTrue([[NSValue value:&F withObjCType:@encode(char)] isEqual:oscFalse]);
    XCTAssertTrue([[NSValue value:&F withObjCType:@encode(char)] isEqualToValue:oscFalse]);

    XCTAssertEqual(oscNull.boolValue, NO);
    XCTAssertEqualObjects(oscNull, [F53OSCValue oscNull]);
    XCTAssertTrue([oscNull isEqual:[F53OSCValue oscNull]]);
    XCTAssertTrue([oscNull isEqualToValue:[F53OSCValue oscNull]]);
    XCTAssertEqualObjects(oscNull, [F53OSCValue valueWithBytes:&N objCType:@encode(char)]);
    XCTAssertTrue([oscNull isEqual:[F53OSCValue valueWithBytes:&N objCType:@encode(char)]]);
    XCTAssertTrue([oscNull isEqualToValue:[F53OSCValue valueWithBytes:&N objCType:@encode(char)]]);
    XCTAssertEqualObjects(oscNull, [NSNumber numberWithChar:'N']);
    XCTAssertEqualObjects(oscNull, [NSValue value:&N withObjCType:@encode(char)]);
    XCTAssertTrue([oscNull isEqual:[NSValue value:&N withObjCType:@encode(char)]]);
    XCTAssertTrue([oscNull isEqualToValue:[NSValue value:&N withObjCType:@encode(char)]]);
    XCTAssertTrue([[NSValue value:&N withObjCType:@encode(char)] isEqual:oscNull]);
    XCTAssertTrue([[NSValue value:&N withObjCType:@encode(char)] isEqualToValue:oscNull]);

    XCTAssertEqual(oscImpulse.boolValue, YES);
    XCTAssertEqualObjects(oscImpulse, [F53OSCValue oscImpulse]);
    XCTAssertTrue([oscImpulse isEqual:[F53OSCValue oscImpulse]]);
    XCTAssertTrue([oscImpulse isEqualToValue:[F53OSCValue oscImpulse]]);
    XCTAssertEqualObjects(oscImpulse, [F53OSCValue valueWithBytes:&I objCType:@encode(char)]);
    XCTAssertTrue([oscImpulse isEqual:[F53OSCValue valueWithBytes:&I objCType:@encode(char)]]);
    XCTAssertTrue([oscImpulse isEqualToValue:[F53OSCValue valueWithBytes:&I objCType:@encode(char)]]);
    XCTAssertEqualObjects(oscImpulse, [NSNumber numberWithChar:'I']);
    XCTAssertEqualObjects(oscImpulse, [NSValue value:&I withObjCType:@encode(char)]);
    XCTAssertTrue([oscImpulse isEqual:[NSValue value:&I withObjCType:@encode(char)]]);
    XCTAssertTrue([oscImpulse isEqualToValue:[NSValue value:&I withObjCType:@encode(char)]]);
    XCTAssertTrue([[NSValue value:&I withObjCType:@encode(char)] isEqual:oscImpulse]);
    XCTAssertTrue([[NSValue value:&I withObjCType:@encode(char)] isEqualToValue:oscImpulse]);

    // valid objCType and exception throwing
    XCTAssertNoThrow([[F53OSCValue alloc] initWithBytes:&T objCType:@encode(char)]);
    XCTAssertNoThrow([[F53OSCValue alloc] initWithBytes:&T objCType:@encode(signed char)]);
    XCTAssertNoThrow([F53OSCValue value:&T withObjCType:@encode(char)]);
    XCTAssertNoThrow([F53OSCValue value:&T withObjCType:@encode(signed char)]);

    // invalid objCType
    XCTAssertThrows([[F53OSCValue alloc] initWithBytes:&T objCType:@encode(unsigned char)]);
    XCTAssertThrows([[F53OSCValue alloc] initWithBytes:&T objCType:@encode(short)]);
    XCTAssertThrows([[F53OSCValue alloc] initWithBytes:&T objCType:@encode(unsigned short)]);
    XCTAssertThrows([[F53OSCValue alloc] initWithBytes:&T objCType:@encode(int)]);
    XCTAssertThrows([[F53OSCValue alloc] initWithBytes:&T objCType:@encode(unsigned int)]);
    XCTAssertThrows([[F53OSCValue alloc] initWithBytes:&T objCType:@encode(long)]);
    XCTAssertThrows([[F53OSCValue alloc] initWithBytes:&T objCType:@encode(unsigned long)]);
    XCTAssertThrows([[F53OSCValue alloc] initWithBytes:&T objCType:@encode(long long)]);
    XCTAssertThrows([[F53OSCValue alloc] initWithBytes:&T objCType:@encode(unsigned long long)]);
    XCTAssertThrows([[F53OSCValue alloc] initWithBytes:&T objCType:@encode(float)]);
    XCTAssertThrows([[F53OSCValue alloc] initWithBytes:&T objCType:@encode(double)]);
    XCTAssertThrows([[F53OSCValue alloc] initWithBytes:&T objCType:@encode(long double)]);
    XCTAssertThrows([F53OSCValue value:&T withObjCType:@encode(unsigned char)]);
    XCTAssertThrows([F53OSCValue value:&T withObjCType:@encode(short)]);
    XCTAssertThrows([F53OSCValue value:&T withObjCType:@encode(unsigned short)]);
    XCTAssertThrows([F53OSCValue value:&T withObjCType:@encode(int)]);
    XCTAssertThrows([F53OSCValue value:&T withObjCType:@encode(unsigned int)]);
    XCTAssertThrows([F53OSCValue value:&T withObjCType:@encode(long)]);
    XCTAssertThrows([F53OSCValue value:&T withObjCType:@encode(unsigned long)]);
    XCTAssertThrows([F53OSCValue value:&T withObjCType:@encode(long long)]);
    XCTAssertThrows([F53OSCValue value:&T withObjCType:@encode(unsigned long long)]);
    XCTAssertThrows([F53OSCValue value:&T withObjCType:@encode(float)]);
    XCTAssertThrows([F53OSCValue value:&T withObjCType:@encode(double)]);
    XCTAssertThrows([F53OSCValue value:&T withObjCType:@encode(long double)]);

    // guarantee inequality to avoid false positives
    XCTAssertFalse([oscTrue isMemberOfClass:[NSValue class]]);
    XCTAssertFalse([oscFalse isMemberOfClass:[NSValue class]]);
    XCTAssertFalse([oscNull isMemberOfClass:[NSValue class]]);
    XCTAssertFalse([oscImpulse isMemberOfClass:[NSValue class]]);

    // NOTE: class methods return singleton instances, so pointer equality should be true
    XCTAssertTrue(oscTrue == [F53OSCValue oscTrue]);
    XCTAssertTrue(oscFalse == [F53OSCValue oscFalse]);
    XCTAssertTrue(oscNull == [F53OSCValue oscNull]);
    XCTAssertTrue(oscImpulse == [F53OSCValue oscImpulse]);

    XCTAssertNotEqualObjects(oscTrue, oscFalse);
    XCTAssertNotEqualObjects(oscTrue, oscNull);
    XCTAssertNotEqualObjects(oscTrue, oscImpulse);
    XCTAssertNotEqualObjects(oscFalse, oscNull);
    XCTAssertNotEqualObjects(oscFalse, oscImpulse);
    XCTAssertNotEqualObjects(oscNull, oscImpulse);

    XCTAssertNotEqualObjects(oscTrue, [NSValue value:&F withObjCType:@encode(char)]);
    XCTAssertNotEqualObjects(oscTrue, [NSValue value:&N withObjCType:@encode(char)]);
    XCTAssertNotEqualObjects(oscTrue, [NSValue value:&I withObjCType:@encode(char)]);
    XCTAssertNotEqualObjects(oscFalse, [NSValue value:&N withObjCType:@encode(char)]);
    XCTAssertNotEqualObjects(oscFalse, [NSValue value:&I withObjCType:@encode(char)]);
    XCTAssertNotEqualObjects(oscNull, [NSValue value:&I withObjCType:@encode(char)]);

    XCTAssertFalse([oscTrue isEqual:oscFalse]);
    XCTAssertFalse([oscTrue isEqual:oscNull]);
    XCTAssertFalse([oscTrue isEqual:oscImpulse]);
    XCTAssertFalse([oscFalse isEqual:oscNull]);
    XCTAssertFalse([oscFalse isEqual:oscImpulse]);
    XCTAssertFalse([oscNull isEqual:oscImpulse]);

    XCTAssertFalse([oscTrue isEqual:[NSValue value:&F withObjCType:@encode(char)]]);
    XCTAssertFalse([oscTrue isEqual:[NSValue value:&N withObjCType:@encode(char)]]);
    XCTAssertFalse([oscTrue isEqual:[NSValue value:&I withObjCType:@encode(char)]]);
    XCTAssertFalse([oscFalse isEqual:[NSValue value:&N withObjCType:@encode(char)]]);
    XCTAssertFalse([oscFalse isEqual:[NSValue value:&I withObjCType:@encode(char)]]);
    XCTAssertFalse([oscNull isEqual:[NSValue value:&I withObjCType:@encode(char)]]);

    XCTAssertFalse([oscTrue isEqualToValue:oscFalse]);
    XCTAssertFalse([oscTrue isEqualToValue:oscNull]);
    XCTAssertFalse([oscTrue isEqualToValue:oscImpulse]);
    XCTAssertFalse([oscFalse isEqualToValue:oscNull]);
    XCTAssertFalse([oscFalse isEqualToValue:oscImpulse]);
    XCTAssertFalse([oscNull isEqualToValue:oscImpulse]);

    XCTAssertFalse([oscTrue isEqualToValue:[NSValue value:&F withObjCType:@encode(char)]]);
    XCTAssertFalse([oscTrue isEqualToValue:[NSValue value:&N withObjCType:@encode(char)]]);
    XCTAssertFalse([oscTrue isEqualToValue:[NSValue value:&I withObjCType:@encode(char)]]);
    XCTAssertFalse([oscFalse isEqualToValue:[NSValue value:&N withObjCType:@encode(char)]]);
    XCTAssertFalse([oscFalse isEqualToValue:[NSValue value:&I withObjCType:@encode(char)]]);
    XCTAssertFalse([oscNull isEqualToValue:[NSValue value:&I withObjCType:@encode(char)]]);

    XCTAssertNotEqualObjects(oscTrue, @YES);
    XCTAssertNotEqualObjects(oscTrue, @NO);
    XCTAssertNotEqualObjects(oscTrue, [NSNumber numberWithChar:'1']);
    XCTAssertNotEqualObjects(oscTrue, [NSNumber numberWithChar:'0']);
    XCTAssertNotEqualObjects(oscTrue, [NSNumber numberWithChar:1]);
    XCTAssertNotEqualObjects(oscTrue, [NSNumber numberWithChar:0]);
    XCTAssertNotEqualObjects(oscTrue, [NSNumber numberWithBool:YES]);
    XCTAssertNotEqualObjects(oscTrue, [NSNumber numberWithBool:NO]);
    XCTAssertNotEqualObjects(oscTrue, [NSNumber numberWithInteger:1]);
    XCTAssertNotEqualObjects(oscTrue, [NSNumber numberWithInteger:0]);
    XCTAssertNotEqualObjects(oscTrue, [NSNumber numberWithDouble:1.0]);
    XCTAssertNotEqualObjects(oscTrue, [NSNumber numberWithDouble:0.0]);

    XCTAssertNotEqualObjects(oscFalse, @YES);
    XCTAssertNotEqualObjects(oscFalse, @NO);
    XCTAssertNotEqualObjects(oscFalse, [NSNumber numberWithChar:'1']);
    XCTAssertNotEqualObjects(oscFalse, [NSNumber numberWithChar:'0']);
    XCTAssertNotEqualObjects(oscFalse, [NSNumber numberWithChar:1]);
    XCTAssertNotEqualObjects(oscFalse, [NSNumber numberWithChar:0]);
    XCTAssertNotEqualObjects(oscFalse, [NSNumber numberWithBool:YES]);
    XCTAssertNotEqualObjects(oscFalse, [NSNumber numberWithBool:NO]);
    XCTAssertNotEqualObjects(oscFalse, [NSNumber numberWithInteger:1]);
    XCTAssertNotEqualObjects(oscFalse, [NSNumber numberWithInteger:0]);
    XCTAssertNotEqualObjects(oscFalse, [NSNumber numberWithDouble:1.0]);
    XCTAssertNotEqualObjects(oscFalse, [NSNumber numberWithDouble:0.0]);

    XCTAssertNotEqualObjects(oscNull, @YES);
    XCTAssertNotEqualObjects(oscNull, @NO);
    XCTAssertNotEqualObjects(oscNull, [NSNumber numberWithChar:'1']);
    XCTAssertNotEqualObjects(oscNull, [NSNumber numberWithChar:'0']);
    XCTAssertNotEqualObjects(oscNull, [NSNumber numberWithChar:1]);
    XCTAssertNotEqualObjects(oscNull, [NSNumber numberWithChar:0]);
    XCTAssertNotEqualObjects(oscNull, [NSNumber numberWithBool:YES]);
    XCTAssertNotEqualObjects(oscNull, [NSNumber numberWithBool:NO]);
    XCTAssertNotEqualObjects(oscNull, [NSNumber numberWithInteger:1]);
    XCTAssertNotEqualObjects(oscNull, [NSNumber numberWithInteger:0]);
    XCTAssertNotEqualObjects(oscNull, [NSNumber numberWithDouble:1.0]);
    XCTAssertNotEqualObjects(oscNull, [NSNumber numberWithDouble:0.0]);

    XCTAssertNotEqualObjects(oscImpulse, @YES);
    XCTAssertNotEqualObjects(oscImpulse, @NO);
    XCTAssertNotEqualObjects(oscImpulse, [NSNumber numberWithChar:'1']);
    XCTAssertNotEqualObjects(oscImpulse, [NSNumber numberWithChar:'0']);
    XCTAssertNotEqualObjects(oscImpulse, [NSNumber numberWithChar:1]);
    XCTAssertNotEqualObjects(oscImpulse, [NSNumber numberWithChar:0]);
    XCTAssertNotEqualObjects(oscImpulse, [NSNumber numberWithBool:YES]);
    XCTAssertNotEqualObjects(oscImpulse, [NSNumber numberWithBool:NO]);
    XCTAssertNotEqualObjects(oscImpulse, [NSNumber numberWithInteger:1]);
    XCTAssertNotEqualObjects(oscImpulse, [NSNumber numberWithInteger:0]);
    XCTAssertNotEqualObjects(oscImpulse, [NSNumber numberWithDouble:1.0]);
    XCTAssertNotEqualObjects(oscImpulse, [NSNumber numberWithDouble:0.0]);

    // Test with zero character (which should return NO).
    const char zeroChar = 0;
    F53OSCValue *zeroValue = [[F53OSCValue alloc] initWithBytes:&zeroChar objCType:@encode(char)];
    XCTAssertEqual([zeroValue boolValue], NO, @"Zero character should return NO");

    // Test with '0' character (which should return NO according to the code).
    const char zeroCharacter = '0';
    F53OSCValue *zeroCharValue = [[F53OSCValue alloc] initWithBytes:&zeroCharacter objCType:@encode(char)];
    XCTAssertEqual([zeroCharValue boolValue], NO, @"'0' character should return NO");

    // Test with any other character (should return YES).
    const char arbitraryChar = 'X';
    F53OSCValue *arbitraryValue = [[F53OSCValue alloc] initWithBytes:&arbitraryChar objCType:@encode(char)];
    XCTAssertEqual([arbitraryValue boolValue], YES, @"Any other character should return YES");

    // Test with numeric value 1 (should return YES).
    const char oneChar = 1;
    F53OSCValue *oneValue = [[F53OSCValue alloc] initWithBytes:&oneChar objCType:@encode(char)];
    XCTAssertEqual([oneValue boolValue], YES, @"Character value 1 should return YES");

    // Test custom value.
    const char value = 'X';
    F53OSCValue *oscValue = [[F53OSCValue alloc] initWithBytes:&value objCType:@encode(char)];
    XCTAssertTrue([oscValue isMemberOfClass:[F53OSCValue class]], @"Init with unspported custom character value should be correct class");
    XCTAssertNotEqualObjects(oscValue, [F53OSCValue oscTrue], @"Init with unspported custom character value should not match object");
    XCTAssertNotEqualObjects(oscValue, [F53OSCValue oscFalse], @"Init with unspported custom character value should not match object");
    XCTAssertNotEqualObjects(oscValue, [F53OSCValue oscNull], @"Init with unspported custom character value should not match object");
    XCTAssertNotEqualObjects(oscValue, [F53OSCValue oscImpulse], @"Init with unspported custom character value should not match object");

    oscValue = (F53OSCValue *)[F53OSCValue valueWithBytes:&value objCType:@encode(char)];
    XCTAssertTrue([oscValue isMemberOfClass:[F53OSCValue class]], @"Init with unspported custom character value should be correct class");
    XCTAssertEqual([oscValue hash], (NSUInteger)'X', @"Hash should return character value for custom value");
    XCTAssertNotEqualObjects(oscValue, [F53OSCValue oscTrue], @"Init with unspported custom character value should not match object");
    XCTAssertNotEqualObjects(oscValue, [F53OSCValue oscFalse], @"Init with unspported custom character value should not match object");
    XCTAssertNotEqualObjects(oscValue, [F53OSCValue oscNull], @"Init with unspported custom character value should not match object");
    XCTAssertNotEqualObjects(oscValue, [F53OSCValue oscImpulse], @"Init with unspported custom character value should not match object");
}

- (void)testThat_F53OSCValueCanBeCopied
{
    F53OSCValue *oscTrue = [F53OSCValue oscTrue];
    F53OSCValue *oscFalse = [F53OSCValue oscFalse];
    F53OSCValue *oscNull = [F53OSCValue oscNull];
    F53OSCValue *oscImpulse = [F53OSCValue oscImpulse];

    F53OSCValue *oscTrueCopy = [oscTrue copy];
    F53OSCValue *oscFalseCopy = [oscFalse copy];
    F53OSCValue *oscNullCopy = [oscNull copy];
    F53OSCValue *oscImpulseCopy = [oscImpulse copy];

    XCTAssertTrue([F53OSCValue conformsToProtocol:@protocol(NSCopying)]);

    XCTAssertNotNil(oscTrueCopy);
    XCTAssertNotNil(oscFalseCopy);
    XCTAssertNotNil(oscNullCopy);
    XCTAssertNotNil(oscImpulseCopy);

    XCTAssertTrue([oscTrueCopy isMemberOfClass:[F53OSCValue class]]);
    XCTAssertTrue([oscFalseCopy isMemberOfClass:[F53OSCValue class]]);
    XCTAssertTrue([oscNullCopy isMemberOfClass:[F53OSCValue class]]);
    XCTAssertTrue([oscImpulseCopy isMemberOfClass:[F53OSCValue class]]);

    XCTAssertEqualObjects(oscTrue, oscTrueCopy);
    XCTAssertEqualObjects(oscFalse, oscFalseCopy);
    XCTAssertEqualObjects(oscNull, oscNullCopy);
    XCTAssertEqualObjects(oscImpulse, oscImpulseCopy);

    XCTAssertEqualObjects(oscTrueCopy, [F53OSCValue oscTrue]);
    XCTAssertEqualObjects(oscFalseCopy, [F53OSCValue oscFalse]);
    XCTAssertEqualObjects(oscNullCopy, [F53OSCValue oscNull]);
    XCTAssertEqualObjects(oscImpulseCopy, [F53OSCValue oscImpulse]);
}

- (void)testThat_F53OSCValueSupportsNSSecureCoding
{
    F53OSCValue *oscTrue = [F53OSCValue oscTrue];
    F53OSCValue *oscFalse = [F53OSCValue oscFalse];
    F53OSCValue *oscNull = [F53OSCValue oscNull];
    F53OSCValue *oscImpulse = [F53OSCValue oscImpulse];

    NSDictionary<NSString *, F53OSCValue *> *dict = @{
        @"oscTrue"      : oscTrue,
        @"oscFalse"     : oscFalse,
        @"oscNull"      : oscNull,
        @"oscImpulse"   : oscImpulse,
    };

    id rootObject;

    NSError *encodeError = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:dict requiringSecureCoding:YES error:&encodeError];

    NSError *decodeError = nil;
    rootObject = [NSKeyedUnarchiver unarchivedObjectOfClasses:[NSSet setWithObjects:[NSDictionary class], [NSString class], [F53OSCValue class], nil]
                                                     fromData:data
                                                        error:&decodeError];

    id t = [rootObject objectForKey:@"oscTrue"];
    id f = [rootObject objectForKey:@"oscFalse"];
    id n = [rootObject objectForKey:@"oscNull"];
    id i = [rootObject objectForKey:@"oscImpulse"];

    XCTAssertTrue([F53OSCValue conformsToProtocol:@protocol(NSCoding)]);
    XCTAssertTrue([F53OSCValue conformsToProtocol:@protocol(NSSecureCoding)]);

    XCTAssertNil(encodeError);
    XCTAssertNil(decodeError);
    XCTAssertNotNil(rootObject);
    XCTAssertTrue([rootObject isKindOfClass:[NSDictionary class]]);

    XCTAssertNotNil(t);
    XCTAssertNotNil(f);
    XCTAssertNotNil(n);
    XCTAssertNotNil(i);

    XCTAssertTrue([t isMemberOfClass:[F53OSCValue class]]);
    XCTAssertTrue([f isMemberOfClass:[F53OSCValue class]]);
    XCTAssertTrue([i isMemberOfClass:[F53OSCValue class]]);
    XCTAssertTrue([n isMemberOfClass:[F53OSCValue class]]);

    XCTAssertEqualObjects(t, [F53OSCValue oscTrue]);
    XCTAssertEqualObjects(f, [F53OSCValue oscFalse]);
    XCTAssertEqualObjects(n, [F53OSCValue oscNull]);
    XCTAssertEqualObjects(i, [F53OSCValue oscImpulse]);
}

- (void)testThat_NSValueGetValueSizeHandlesDifferentBufferSizes
{
    // Test the getValue:size: method with misc buffer size.

    char value;

    F53OSCValue *oscTrue = [F53OSCValue oscTrue];
    value = 'X'; // Initialize to something other than 'T'

    // Call with insufficient buffer size - should return early without setting value.
    [oscTrue getValue:&value size:0];
    XCTAssertEqual(value, 'X', @"Value should remain unchanged when buffer size is insufficient");

    // Test with NULL pointer - should not crash.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertNoThrow([oscTrue getValue:NULL size:sizeof(char)]);
    XCTAssertNoThrow([oscTrue getValue:NULL size:0]);
#pragma clang diagnostic pop

    // Call with sufficient buffer size - should work correctly.
    [oscTrue getValue:&value size:sizeof(char)];
    XCTAssertEqual(value, 'T', @"Value should be set correctly when buffer size is sufficient");

    F53OSCValue *oscFalse = [F53OSCValue oscFalse];
    value = 'X'; // Initialize to something other than 'F'

    // Call with insufficient buffer size - should return early without setting value.
    [oscFalse getValue:&value size:0];
    XCTAssertEqual(value, 'X', @"Value should remain unchanged when buffer size is insufficient");

    // Test with NULL pointer - should not crash.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertNoThrow([oscFalse getValue:NULL size:sizeof(char)]);
    XCTAssertNoThrow([oscFalse getValue:NULL size:0]);
#pragma clang diagnostic pop

    // Call with sufficient buffer size - should work correctly.
    [oscFalse getValue:&value size:sizeof(char)];
    XCTAssertEqual(value, 'F', @"Value should be set correctly when buffer size is sufficient");

    F53OSCValue *oscNull = [F53OSCValue oscNull];
    value = 'X'; // Initialize to something other than 'N'

    // Call with insufficient buffer size - should return early without setting value.
    [oscNull getValue:&value size:0];
    XCTAssertEqual(value, 'X', @"Value should remain unchanged when buffer size is insufficient");

    // Test with NULL pointer - should not crash.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertNoThrow([oscNull getValue:NULL size:sizeof(char)]);
    XCTAssertNoThrow([oscNull getValue:NULL size:0]);
#pragma clang diagnostic pop

    // Call with sufficient buffer size - should work correctly.
    [oscNull getValue:&value size:sizeof(char)];
    XCTAssertEqual(value, 'N', @"Value should be set correctly when buffer size is sufficient");

    F53OSCValue *oscImpulse = [F53OSCValue oscImpulse];
    value = 'X'; // Initialize to something other than 'I'

    // Call with insufficient buffer size - should return early without setting value.
    [oscImpulse getValue:&value size:0];
    XCTAssertEqual(value, 'X', @"Value should remain unchanged when buffer size is insufficient");

    // Test with NULL pointer - should not crash.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertNoThrow([oscImpulse getValue:NULL size:sizeof(char)]);
    XCTAssertNoThrow([oscImpulse getValue:NULL size:0]);
#pragma clang diagnostic pop

    // Call with sufficient buffer size - should work correctly.
    [oscImpulse getValue:&value size:sizeof(char)];
    XCTAssertEqual(value, 'I', @"Value should be set correctly when buffer size is sufficient");
}

- (void)testThat_F53OSCValueHashWorks
{
    // Test the hash method returns the character value as NSUInteger.
    F53OSCValue *oscTrue = [F53OSCValue oscTrue];
    F53OSCValue *oscFalse = [F53OSCValue oscFalse];
    F53OSCValue *oscNull = [F53OSCValue oscNull];
    F53OSCValue *oscImpulse = [F53OSCValue oscImpulse];

    XCTAssertEqual([oscTrue hash], (NSUInteger)'T', @"Hash should return character value for oscTrue");
    XCTAssertEqual([oscFalse hash], (NSUInteger)'F', @"Hash should return character value for oscFalse");
    XCTAssertEqual([oscNull hash], (NSUInteger)'N', @"Hash should return character value for oscNull");
    XCTAssertEqual([oscImpulse hash], (NSUInteger)'I', @"Hash should return character value for oscImpulse");

    // Test custom value.
    const char value = 'X';
    F53OSCValue *oscValue = [[F53OSCValue alloc] initWithBytes:&value objCType:@encode(char)];
    XCTAssertEqual([oscValue hash], (NSUInteger)'X', @"Hash should return character value for custom value");

    oscValue = (F53OSCValue *)[F53OSCValue valueWithBytes:&value objCType:@encode(char)];
    XCTAssertEqual([oscValue hash], (NSUInteger)'X', @"Hash should return character value for custom value");
}

- (void)testThat_F53OSCValueClassForCoderWorks
{
    F53OSCValue *oscTrue = [F53OSCValue oscTrue];
    F53OSCValue *oscFalse = [F53OSCValue oscFalse];
    F53OSCValue *oscNull = [F53OSCValue oscNull];
    F53OSCValue *oscImpulse = [F53OSCValue oscImpulse];

    XCTAssertEqual([oscTrue classForCoder], [F53OSCValue class], @"classForCoder should return F53OSCValue class");
    XCTAssertEqual([oscFalse classForCoder], [F53OSCValue class], @"classForCoder should return F53OSCValue class");
    XCTAssertEqual([oscNull classForCoder], [F53OSCValue class], @"classForCoder should return F53OSCValue class");
    XCTAssertEqual([oscImpulse classForCoder], [F53OSCValue class], @"classForCoder should return F53OSCValue class");
}

- (void)testThat_F53OSCValueInitWithCoderWorks
{
    NSArray<F53OSCValue *> *values = @[
        [F53OSCValue oscTrue],
        [F53OSCValue oscFalse],
        [F53OSCValue oscNull],
        [F53OSCValue oscImpulse],
    ];
    for (F53OSCValue *value in values)
    {
        // Test the normal case to ensure our setup works.
        NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
        [value encodeWithCoder:archiver];

        NSData *data = [archiver encodedData];

        NSError *error = nil;
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:&error];
        XCTAssertNotNil(unarchiver, @"Unarchiver should not be nil");
        XCTAssertNil(error, @"Error should be nil");

        F53OSCValue *decoded = [[F53OSCValue alloc] initWithCoder:unarchiver];
        XCTAssertNotNil(decoded, @"Normal decoding should work");
        XCTAssertNotEqual(decoded, value, @"Decoded value should be a different object");
        XCTAssertEqualObjects(decoded, value, @"Decoded value should match original");
    }

    // Now test with invalid data using our mock coder.
    MockCoder *mockCoder = [[MockCoder alloc] init];

    // Test with valid values to ensure they don't throw.
    mockCoder.mockIntValue = CHAR_MAX;
    XCTAssertNoThrow([[F53OSCValue alloc] initWithCoder:mockCoder],
                     @"initWithCoder should not throw exception for CHAR_MAX");

    mockCoder.mockIntValue = 'T';
    XCTAssertNoThrow([[F53OSCValue alloc] initWithCoder:mockCoder],
                     @"initWithCoder should not throw exception for normal char values");

    // Value too large for char
    mockCoder.mockIntValue = CHAR_MAX + 1;
    XCTAssertThrows([[F53OSCValue alloc] initWithCoder:mockCoder],
                   @"initWithCoder should throw exception for value > CHAR_MAX");

    // Value much larger than char
    mockCoder.mockIntValue = INT_MAX;
    XCTAssertThrows([[F53OSCValue alloc] initWithCoder:mockCoder], 
                   @"initWithCoder should throw exception for very large values");
}

@end


#pragma mark - MockCoder

@implementation MockCoder

- (int)decodeIntForKey:(NSString *)key
{
    return self.mockIntValue;
}

- (BOOL)allowsKeyedCoding
{
    return YES;
}

@end

NS_ASSUME_NONNULL_END
