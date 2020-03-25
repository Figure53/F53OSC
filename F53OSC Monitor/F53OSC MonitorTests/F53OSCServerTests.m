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
    // - match exact string '1'
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
}

- (void) testThat_stringMatchesPredicateWithOSCWildcardAsteriskPrefix
{
    // given
    // - match any sequence of zero or more characters followed by '3'
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
}

- (void) testThat_stringMatchesPredicateWithOSCWildcardAsteriskSuffix
{
    // given
    // - match '1' followed by any sequence of zero or more characters
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
}

- (void) testThat_stringMatchesPredicateWithOSCWildcardAsteriskMiddle
{
    // given
    // - match '1' followed by any sequence of zero or more characters followed by '3'
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
}

- (void) testThat_stringMatchesPredicateWithOSC2QuestionMarkWildcards
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
}

- (void) testThat_stringMatchesPredicateWithOSC3QuestionMarkWildcards
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
}

- (void) testThat_stringMatchesPredicateWithOSCWildcardQuestionMarkPrefix
{
    // given
    // - match any single character followed by a period
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
}

- (void) testThat_stringMatchesPredicateWithOSCWildcardQuestionMarkSuffix
{
    // given
    // - match '1' followed by any single character
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
}

- (void) testThat_stringMatchesPredicateWithOSCWildcardQuestionMarkMiddle
{
    // given
    // - match '1' followed by any single character followed by '3'
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
    
    oscPattern = @"[12]"; // match single characters '1' or '2'
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
    
    oscPattern = @"[1-3]"; // match any single character in range of '1' thru '3', inclusive
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
    
    oscPattern = @"[1][2]"; // match single character '1' followed by single character '2'
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
    
    oscPattern = @"{1,2,12}"; // match any exact string in list: '1', '2', or '12'
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
    
    oscPattern = @"{1,2,3}-{1,2,3}"; // match any exact string in list: '1', '2', or '3'; followed by minus sign, followed by any exact string in list: '1', '2', or '3'
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
}

- (void) testThat_stringMatchesPredicateWithOSCWildcardStringList
{
    NSString *oscPattern;
    NSPredicate *predicate;
    
    // given
    // when
    // then
    oscPattern = @"{12}"; // match exact string in list: '12'
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
    
    oscPattern = @"{12,13}"; // match any exact string in list: '12' or '13'
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
    
    oscPattern = @"{[1-3],[1][1-3]}"; // match any string in list: (any single character in range of '1' thru '3', inclusive), or (exact string '1' followed by any single character in range of '1' thru '3', inclusive)
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
    
    oscPattern = @"{[1-3],[1][2-3]}"; // match any string in list: (any single character in range of '1' thru '3', inclusive), or (exact string '1' followed by any single character in range of '2' thru '3', inclusive)
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
    
    oscPattern = @"{[!1-3],[1][1-3]}"; // match any string in list: (any single character NOT in range of '1' thru '3', inclusive), or (exact string '1' followed by any single character in range of '1' thru '3', inclusive)
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
    
    oscPattern = @"{[!12],[1][A-C]}"; // match any string in list: (any single character NOT '1' or '2'), or (exact string '1' followed by any single character in range of 'A' thru 'C', inclusive)
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
    
    oscPattern = @"{2,?3}"; // match any string in list: (exact string '2'), or (any single character followed by '3')
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
    
    oscPattern = @"{1*,1}"; // match any string in list: ('1' followed by any sequence of zero or more characters), or (exact string '1')
    predicate = [self stringTestPredicateWithOSCPattern:oscPattern];
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:@""] );
    XCTAssertFalse( [predicate evaluateWithObject:@"1*,1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"{1*,1}"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"0"] );
    XCTAssertTrue(  [predicate evaluateWithObject:@"1"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"2"] );
    XCTAssertFalse( [predicate evaluateWithObject:@"3"] );
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
