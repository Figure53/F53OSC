//
//  F53OSCServerTests.m
//  F53OSC
//
//  Created by Brent Lord on 2/24/20.
//  Copyright (c) 2020 Figure 53, LLC. All rights reserved.
//

#if !__has_feature(objc_arc)
#error This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import "F53OSCServer.h"


NS_ASSUME_NONNULL_BEGIN

@interface F53OSCServerTests : XCTestCase
@end


@implementation F53OSCServerTests

#pragma mark - XCTest setup/teardown

//- (void) setUp
//{
//    [super setUp];
//
//    // set up
//}

#pragma mark - F53OSCServer Tests

- (void) testThat__setupWorks
{
    // given
    // - state created by `+setUp` and `-setUp`
    
    // when
    // - triggered by running this test
    
    // then
    XCTAssertTrue( YES );
}

- (void) testThat_stringMatchesPredicateWithString
{
    // given
    // - match character '1'
    NSString *oscPattern = @"1";
    
    // when
    NSPredicate *predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    
    // then
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:@""] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"21"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1."] );
    XCTAssertFalse( [predicate evaluateWithObject:@"13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1.3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1?3"] ); // ? invalid in OSC address
    XCTAssertFalse( [predicate evaluateWithObject:@"1 3"] ); // space invalid in OSC address
    XCTAssertFalse( [predicate evaluateWithObject:@"1.2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-12"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"2-13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"12-34"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1A"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"B2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"!3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"6/1"] ); // slash invalid in OSC address
}

- (void) testThat_stringMatchesPredicateWithOSCWildcardAsterisk
{
    // given
    // - match any sequence of zero or more characters
    NSString *oscPattern = @"*";
    
    // when
    NSPredicate *predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    
    // then
    XCTAssertNotNil( predicate );
    XCTAssertTrue(  [predicate evaluateWithObject:@""] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"3"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"21"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1."] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"13"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1.3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1?3"] ); // ? invalid in OSC address
    XCTAssertFalse( [predicate evaluateWithObject:@"1 3"] ); // space invalid in OSC address
    XCTAssertTrue(  [predicate evaluateWithObject:@"1.2"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1-2"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1-3"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1-12"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"2-13"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"10-1"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"10-2"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"10-3"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"12-34"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1A"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"B2"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"!3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"6/1"] ); // slash invalid in OSC address
}

- (void) testThat_stringMatchesPredicateWithOSCWildcardAsteriskPrefix
{
    // given
    // - match any sequence of zero or more characters, followed by character '3'
    NSString *oscPattern = @"*3";
    
    // when
    NSPredicate *predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    
    // then
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:@""] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"21"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1."] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"13"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1.3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1?3"] ); // ? invalid in OSC address
    XCTAssertFalse( [predicate evaluateWithObject:@"1 3"] ); // space invalid in OSC address
    XCTAssertFalse( [predicate evaluateWithObject:@"1.2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-2"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-12"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"2-13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-2"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"10-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"12-34"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1A"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"B2"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"!3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"6/1"] ); // slash invalid in OSC address
}

- (void) testThat_stringMatchesPredicateWithOSCWildcardAsteriskSuffix
{
    // given
    // - match character '1', followed by any sequence of zero or more characters
    NSString *oscPattern = @"1*";
    
    // when
    NSPredicate *predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    
    // then
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:@""] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"21"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1."] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"13"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1.3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1?3"] ); // ? invalid in OSC address
    XCTAssertFalse( [predicate evaluateWithObject:@"1 3"] ); // space invalid in OSC address
    XCTAssertTrue(  [predicate evaluateWithObject:@"1.2"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1-2"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1-3"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1-12"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"2-13"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"10-1"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"10-2"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"10-3"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"12-34"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1A"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"B2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"!3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"6/1"] ); // slash invalid in OSC address
}

- (void) testThat_stringMatchesPredicateWithOSCWildcardAsteriskMiddle
{
    // given
    // - match character '1', followed by any sequence of zero or more characters, followed by character '3'
    NSString *oscPattern = @"1*3";
    
    // when
    NSPredicate *predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    
    // then
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:@""] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"21"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1."] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"13"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1.3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1?3"] ); // ? invalid in OSC address
    XCTAssertFalse( [predicate evaluateWithObject:@"1 3"] ); // space invalid in OSC address
    XCTAssertFalse( [predicate evaluateWithObject:@"1.2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-2"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-12"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"2-13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-2"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"10-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"12-34"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1A"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"B2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"!3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"6/1"] ); // slash invalid in OSC address
}

- (void) testThat_stringMatchesPredicateWithOSCWildcardQuestionMark
{
    // given
    // - match any single character
    NSString *oscPattern = @"?";
    
    // when
    NSPredicate *predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    
    // then
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:@""] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"21"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1."] );
    XCTAssertFalse( [predicate evaluateWithObject:@"13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1.3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1?3"] ); // ? invalid in OSC address
    XCTAssertFalse( [predicate evaluateWithObject:@"1 3"] ); // space invalid in OSC address
    XCTAssertFalse( [predicate evaluateWithObject:@"1.2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-12"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"2-13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"12-34"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1A"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"B2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"!3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"6/1"] ); // slash invalid in OSC address
}

- (void) testThat_stringMatchesPredicateWithOSCWildcardTwoQuestionMarks
{
    // given
    // - match any two characters
    NSString *oscPattern = @"??";
    
    // when
    NSPredicate *predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    
    // then
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:@""] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"3"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"21"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1."] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1.3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1?3"] ); // ? invalid in OSC address
    XCTAssertFalse( [predicate evaluateWithObject:@"1 3"] ); // space invalid in OSC address
    XCTAssertFalse( [predicate evaluateWithObject:@"1.2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-12"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"2-13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"12-34"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1A"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"B2"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"!3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"6/1"] ); // slash invalid in OSC address
}

- (void) testThat_stringMatchesPredicateWithOSCWildcardThreeQuestionMarks
{
    // given
    // - match any three characters
    NSString *oscPattern = @"???";
    
    // when
    NSPredicate *predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    
    // then
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:@""] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"21"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1."] );
    XCTAssertFalse( [predicate evaluateWithObject:@"13"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1.3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1?3"] ); // ? invalid in OSC address
    XCTAssertFalse( [predicate evaluateWithObject:@"1 3"] ); // space invalid in OSC address
    XCTAssertTrue(  [predicate evaluateWithObject:@"1.2"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1-2"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-12"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"2-13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"12-34"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1A"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"B2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"!3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"6/1"] ); // slash invalid in OSC address
}

- (void) testThat_stringMatchesPredicateWithOSCWildcardQuestionMarkPrefix
{
    // given
    // - match any single character, followed by character '.'
    NSString *oscPattern = @"?.";
    
    // when
    NSPredicate *predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    
    // then
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:@""] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"21"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1."] );
    XCTAssertFalse( [predicate evaluateWithObject:@"13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1.3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1?3"] ); // ? invalid in OSC address
    XCTAssertFalse( [predicate evaluateWithObject:@"1 3"] ); // space invalid in OSC address
    XCTAssertFalse( [predicate evaluateWithObject:@"1.2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-12"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"2-13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"12-34"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1A"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"B2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"!3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"6/1"] ); // slash invalid in OSC address
}

- (void) testThat_stringMatchesPredicateWithOSCWildcardQuestionMarkSuffix
{
    // given
    // - match character '1', followed by any single character
    NSString *oscPattern = @"1?";
    
    // when
    NSPredicate *predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    
    // then
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:@""] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"21"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1."] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1.3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1?3"] ); // ? invalid in OSC address
    XCTAssertFalse( [predicate evaluateWithObject:@"1 3"] ); // space invalid in OSC address
    XCTAssertFalse( [predicate evaluateWithObject:@"1.2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-12"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"2-13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"12-34"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1A"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"B2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"!3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"6/1"] ); // slash invalid in OSC address
}

- (void) testThat_stringMatchesPredicateWithOSCWildcardQuestionMarkMiddle
{
    // given
    // - match character '1', followed by any single character, followed by character '3'
    NSString *oscPattern = @"1?3";
    
    // when
    NSPredicate *predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    
    // then
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:@""] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"21"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1."] );
    XCTAssertFalse( [predicate evaluateWithObject:@"13"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1.3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1?3"] ); // ? invalid in OSC address
    XCTAssertFalse( [predicate evaluateWithObject:@"1 3"] ); // space invalid in OSC address
    XCTAssertFalse( [predicate evaluateWithObject:@"1.2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-2"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-12"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"2-13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"12-34"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1A"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"B2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"!3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"6/1"] ); // slash invalid in OSC address
}

- (void) testThat_stringMatchesPredicateWithOSCWildcardStringRange
{
    NSString *oscPattern;
    NSPredicate *predicate;
    
    // given
    // when
    // then
    oscPattern = @"12"; // match exact string '12'
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:@""] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"3"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"12"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1 3"] ); // space invalid in OSC address
    XCTAssertFalse( [predicate evaluateWithObject:@"1.2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-12"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"2-13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"12-34"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1A"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"B2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"!3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"6/1"] ); // slash invalid in OSC address
    
    oscPattern = @"[12]"; // match either character '1' or character '2'
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:@""] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"12"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1 3"] ); // space invalid in OSC address
    XCTAssertFalse( [predicate evaluateWithObject:@"1.2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-12"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"2-13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"12-34"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1A"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"B2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"!3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"6/1"] ); // slash invalid in OSC address
    
    oscPattern = @"1-3"; // match exact string '1-3'
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:@""] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"12"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"13"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1 3"] ); // space invalid in OSC address
    XCTAssertFalse( [predicate evaluateWithObject:@"1.2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-12"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"2-13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"12-34"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1A"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"B2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"!3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"6/1"] ); // slash invalid in OSC address
    
    oscPattern = @"[1-3]"; // match any single character in range of '1' thru '3' inclusive
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:@""] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"2"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"12"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1 3"] ); // space invalid in OSC address
    XCTAssertFalse( [predicate evaluateWithObject:@"1.2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-12"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"2-13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"12-34"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1A"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"B2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"!3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"6/1"] ); // slash invalid in OSC address
    
    oscPattern = @"[1][2]"; // match character '1', followed by character '2'
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:@""] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"3"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"12"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1 3"] ); // space invalid in OSC address
    XCTAssertFalse( [predicate evaluateWithObject:@"1.2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-12"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"2-13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"12-34"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1A"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"B2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"!3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"6/1"] ); // slash invalid in OSC address
    
    oscPattern = @"[!1]"; // match any single character except for '1'
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:@""] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"2"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"12"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1 3"] ); // space invalid in OSC address
    XCTAssertFalse( [predicate evaluateWithObject:@"1.2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-12"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"2-13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"12-34"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1A"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"B2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"!3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"6/1"] ); // slash invalid in OSC address
    
    oscPattern = @"{1,2,12}"; // match exact string '1', '2', or '12'
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:@""] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1,2,12"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"3"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"12"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1 3"] ); // space invalid in OSC address
    XCTAssertFalse( [predicate evaluateWithObject:@"1.2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-12"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"2-13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"12-34"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1A"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"B2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"!3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"6/1"] ); // slash invalid in OSC address
    
    oscPattern = @"{1,2,3}-{1,2,3}"; // match characters '1', '2', or '3', followed by minus sign, followed by characters '1', '2', or '3'
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:@""] );
    XCTAssertFalse( [predicate evaluateWithObject:@"{1,2,3}-{1,2,3}"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"12"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"123"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1 3"] ); // space invalid in OSC address
    XCTAssertFalse( [predicate evaluateWithObject:@"1.2"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-12"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"2-13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"12-34"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1A"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"B2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"!3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"6/1"] ); // slash invalid in OSC address
}

- (void) testThat_stringMatchesPredicateWithOSCWildcardStringList
{
    NSString *oscPattern;
    NSPredicate *predicate;
    
    // given
    // when
    // then
    oscPattern = @"{12}"; // match exact string '12'
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:@""] );
    XCTAssertFalse( [predicate evaluateWithObject:@"{12}"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"11"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"12"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1.2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-12"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"2-13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"12-34"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1A"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"B2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"!3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"6/1"] ); // slash invalid in OSC address
    
    oscPattern = @"{12,13}"; // match exact string '12' or '13'
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:@""] );
    XCTAssertFalse( [predicate evaluateWithObject:@"12,13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"{12,13}"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"11"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"12"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1.2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-12"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"2-13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"12-34"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1A"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"B2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"!3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"6/1"] ); // slash invalid in OSC address
    
    oscPattern = @"{[1-3],[1][1-3]}"; // match (any single character in range of '1' thru '3' inclusive), or (character '1', followed by any single character in range of '1' thru '3' inclusive)
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:@""] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"[1]"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"[1-3]"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"[1][1-3]"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"{[1-3],[1][1-3]}"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"0"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"2"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"4"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"01"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"11"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"12"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"14"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"111"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1.2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-12"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"2-13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"12-34"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1A"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"B2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"!3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"6/1"] ); // slash invalid in OSC address
    
    oscPattern = @"{[1-3],[1][2-3]}"; // match (any single character in range of '1' thru '3' inclusive), or (character '1', followed by any single character in range of '2' thru '3' inclusive)
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:@""] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"2-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"[1]"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"[2-3]"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"[1][2-3]"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"{[1-3],[1][2-3]}"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"0"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"2"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"4"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"01"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"11"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"12"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"14"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"111"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1.2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-12"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"2-13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"12-34"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1A"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"B2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"!3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"6/1"] ); // slash invalid in OSC address
    
    oscPattern = @"{[!1-3],[1][1-3]}"; // match (any single character NOT in range of '1' thru '3' inclusive), or (character '1', followed by any single character in range of '1' thru '3' inclusive)
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:@""] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"!1-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"[1]"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"[1-3]"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"[1][1-3]"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"{[!1-3],[1][1-3]}"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"0"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"3"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"4"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"01"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"11"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"12"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"14"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"111"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1.2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-12"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"2-13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"12-34"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1A"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"B2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"!3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"6/1"] ); // slash invalid in OSC address
    
    oscPattern = @"{[!12],[1][A-C]}"; // match (any single character excluding '1' or '2'), or (character '1', followed by any single character in range of 'A' thru 'C' inclusive)
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:@""] );
    XCTAssertFalse( [predicate evaluateWithObject:@"!12"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"[!12]"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"[2-3]"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"[1][2-3]"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"{[!12],[1][2-3]}"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"0"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"2"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"3"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"4"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"11"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"12"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1A"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1B"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1C"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1a"] ); // matching is case-sensitive
    XCTAssertFalse( [predicate evaluateWithObject:@"1b"] ); // matching is case-sensitive
    XCTAssertFalse( [predicate evaluateWithObject:@"1c"] ); // matching is case-sensitive
    XCTAssertFalse( [predicate evaluateWithObject:@"111"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"313"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1.2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-12"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"2-13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"12-34"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"B2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"!3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"6/1"] ); // slash invalid in OSC address
    
    oscPattern = @"{2,?3}"; // match (character '2'), or (any single character, followed by '3')
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:@""] );
    XCTAssertFalse( [predicate evaluateWithObject:@"2,?3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"{2,?3}"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"0"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"4"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"11"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"12"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"14"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"x0"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"x1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"x2"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"x3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"x4"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"213"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1.2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1-12"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"2-13"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"10-3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"12-34"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1A"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"B2"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"!3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"6/1"] ); // slash invalid in OSC address
    
    oscPattern = @"{1*,3}"; // match (character '1', followed by any sequence of zero or more characters), or (character '3')
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:@""] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1*,3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"{1*,3}"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"0"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"2"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"4"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"10"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"11"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"12"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"13"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1A"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1B"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1C"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"111"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"222"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1.2"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1-2"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1-3"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1-12"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"2-13"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"10-1"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"10-2"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"10-3"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"12-34"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1A"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"B2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"!3"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"6/1"] ); // slash invalid in OSC address
    
    oscPattern = @"[Q-c]"; // match any single character in range of 'Q' thru 'c' inclusive
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:@""] );
    XCTAssertFalse( [predicate evaluateWithObject:@"Q-c"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"[Q-c]"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"0"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"12"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"123"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"A"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"B"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"C"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"O"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"P"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"Q"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"R"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"X"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"Y"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"Z"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"a"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"b"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"c"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"d"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"PP"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"PPP"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"QQ"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"QRS"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"XYZ"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"aa"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"abc"] );
}

#pragma mark - helpers

- (NSPredicate *) stringTestPredicateWithOSCPattern:(NSString *)oscPattern
{
    NSPredicate *predicate = [F53OSCServer predicateForAttribute:@"SELF" matchingOSCPattern:oscPattern];
    
    // hack around passing reserved word to `predicateWithFormat:`
    predicate = [NSPredicate predicateWithFormat:[predicate.predicateFormat stringByReplacingOccurrencesOfString:@"#SELF" withString:@"SELF"]];
    return predicate;
}

@end

NS_ASSUME_NONNULL_END
