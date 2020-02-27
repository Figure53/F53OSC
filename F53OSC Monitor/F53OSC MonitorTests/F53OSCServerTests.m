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

- (void) testThat_01_F53OSCCServerPredicateMatchesString
{
    // given
    NSString *oscPattern = @"1";
    
    NSString *str1 = @"1";
    NSString *str2 = @"21";
    NSString *str3 = @"1.";
    NSString *str4 = @"1.3";
    NSString *str5 = @"1?3"; // ? invalid in OSC address
    NSString *str6 = @"1 3"; // space invalid in OSC address
    
    // when
    NSPredicate *predicate = [F53OSCServer predicateForAttribute:@"SELF" matchingOSCPattern:oscPattern];
    predicate = [NSPredicate predicateWithFormat:[predicate.predicateFormat stringByReplacingOccurrencesOfString:@"#SELF" withString:@"SELF"]]; // hack around passing reserved word to `predicateWithFormat:`
    
    // then
    XCTAssertNotNil( predicate );
    XCTAssertTrue( [predicate evaluateWithObject:str1] );
    XCTAssertFalse( [predicate evaluateWithObject:str2] );
    XCTAssertFalse( [predicate evaluateWithObject:str3] );
    XCTAssertFalse( [predicate evaluateWithObject:str4] );
    XCTAssertFalse( [predicate evaluateWithObject:str5] );
    XCTAssertFalse( [predicate evaluateWithObject:str6] );
}

- (void) testThat_02_F53OSCCServerPredicateMatchesAsteriskWildcard
{
    // given
    NSString *oscPattern = @"*";
    
    NSString *str1 = @"1";
    NSString *str2 = @"21";
    NSString *str3 = @"1.";
    NSString *str4 = @"1.3";
    NSString *str5 = @"1?3"; // ? invalid in OSC address
    NSString *str6 = @"1 3"; // space invalid in OSC address
    
    // when
    NSPredicate *predicate = [F53OSCServer predicateForAttribute:@"SELF" matchingOSCPattern:oscPattern];
    predicate = [NSPredicate predicateWithFormat:[predicate.predicateFormat stringByReplacingOccurrencesOfString:@"#SELF" withString:@"SELF"]]; // hack around passing reserved word to `predicateWithFormat:`
    
    // then
    XCTAssertNotNil( predicate );
    XCTAssertTrue( [predicate evaluateWithObject:str1] );
    XCTAssertTrue( [predicate evaluateWithObject:str2] );
    XCTAssertTrue( [predicate evaluateWithObject:str3] );
    XCTAssertTrue( [predicate evaluateWithObject:str4] );
    XCTAssertFalse( [predicate evaluateWithObject:str5] );
    XCTAssertFalse( [predicate evaluateWithObject:str6] );
}

- (void) testThat_03_F53OSCCServerPredicateMatchesAsteriskWildcardPrefix
{
    NSString *oscPattern = @"*3";
    
    NSString *str1 = @"1";
    NSString *str2 = @"21";
    NSString *str3 = @"1.";
    NSString *str4 = @"1.3";
    NSString *str5 = @"1?3"; // ? invalid in OSC address
    NSString *str6 = @"1 3"; // space invalid in OSC address
    
    // when
    NSPredicate *predicate = [F53OSCServer predicateForAttribute:@"SELF" matchingOSCPattern:oscPattern];
    predicate = [NSPredicate predicateWithFormat:[predicate.predicateFormat stringByReplacingOccurrencesOfString:@"#SELF" withString:@"SELF"]]; // hack around passing reserved word to `predicateWithFormat:`
    
    // then
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:str1] );
    XCTAssertFalse( [predicate evaluateWithObject:str2] );
    XCTAssertFalse( [predicate evaluateWithObject:str3] );
    XCTAssertTrue( [predicate evaluateWithObject:str4] );
    XCTAssertFalse( [predicate evaluateWithObject:str5] );
    XCTAssertFalse( [predicate evaluateWithObject:str6] );
}

- (void) testThat_04_F53OSCCServerPredicateMatchesAsteriskWildcardSuffix
{
    NSString *oscPattern = @"1*";
    
    NSString *str1 = @"1";
    NSString *str2 = @"21";
    NSString *str3 = @"1.";
    NSString *str4 = @"1.3";
    NSString *str5 = @"1?3"; // ? invalid in OSC address
    NSString *str6 = @"1 3"; // space invalid in OSC address
    
    // when
    NSPredicate *predicate = [F53OSCServer predicateForAttribute:@"SELF" matchingOSCPattern:oscPattern];
    predicate = [NSPredicate predicateWithFormat:[predicate.predicateFormat stringByReplacingOccurrencesOfString:@"#SELF" withString:@"SELF"]]; // hack around passing reserved word to `predicateWithFormat:`
    
    // then
    XCTAssertNotNil( predicate );
    XCTAssertTrue( [predicate evaluateWithObject:str1] );
    XCTAssertFalse( [predicate evaluateWithObject:str2] );
    XCTAssertTrue( [predicate evaluateWithObject:str3] );
    XCTAssertTrue( [predicate evaluateWithObject:str4] );
    XCTAssertFalse( [predicate evaluateWithObject:str5] );
    XCTAssertFalse( [predicate evaluateWithObject:str6] );
}

- (void) testThat_05_F53OSCCServerPredicateMatchesAsteriskWildcardMiddle
{
    NSString *oscPattern = @"1*3";
    
    NSString *str1 = @"1";
    NSString *str2 = @"21";
    NSString *str3 = @"1.";
    NSString *str4 = @"1.3";
    NSString *str5 = @"1?3"; // ? invalid in OSC address
    NSString *str6 = @"1 3"; // space invalid in OSC address
    
    // when
    NSPredicate *predicate = [F53OSCServer predicateForAttribute:@"SELF" matchingOSCPattern:oscPattern];
    predicate = [NSPredicate predicateWithFormat:[predicate.predicateFormat stringByReplacingOccurrencesOfString:@"#SELF" withString:@"SELF"]]; // hack around passing reserved word to `predicateWithFormat:`
    
    // then
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:str1] );
    XCTAssertFalse( [predicate evaluateWithObject:str2] );
    XCTAssertFalse( [predicate evaluateWithObject:str3] );
    XCTAssertTrue( [predicate evaluateWithObject:str4] );
    XCTAssertFalse( [predicate evaluateWithObject:str5] );
    XCTAssertFalse( [predicate evaluateWithObject:str6] );
}

- (void) testThat_06_F53OSCCServerPredicateMatchesQuestionMarkWildcard
{
    NSString *oscPattern = @"?";
    
    NSString *str1 = @"1";
    NSString *str2 = @"21";
    NSString *str3 = @"1.";
    NSString *str4 = @"1.3";
    NSString *str5 = @"1?3"; // ? invalid in OSC address
    NSString *str6 = @"1 3"; // space invalid in OSC address
    
    // when
    NSPredicate *predicate = [F53OSCServer predicateForAttribute:@"SELF" matchingOSCPattern:oscPattern];
    predicate = [NSPredicate predicateWithFormat:[predicate.predicateFormat stringByReplacingOccurrencesOfString:@"#SELF" withString:@"SELF"]]; // hack around passing reserved word to `predicateWithFormat:`
    
    // then
    XCTAssertNotNil( predicate );
    XCTAssertTrue( [predicate evaluateWithObject:str1] );
    XCTAssertFalse( [predicate evaluateWithObject:str2] );
    XCTAssertFalse( [predicate evaluateWithObject:str3] );
    XCTAssertFalse( [predicate evaluateWithObject:str4] );
    XCTAssertFalse( [predicate evaluateWithObject:str5] );
    XCTAssertFalse( [predicate evaluateWithObject:str6] );
}

- (void) testThat_07_F53OSCCServerPredicateMatches2QuestionMarkWildcards
{
    NSString *oscPattern = @"??";
    
    NSString *str1 = @"1";
    NSString *str2 = @"21";
    NSString *str3 = @"1.";
    NSString *str4 = @"1.3";
    NSString *str5 = @"1?3"; // ? invalid in OSC address
    NSString *str6 = @"1 3"; // space invalid in OSC address
    
    // when
    NSPredicate *predicate = [F53OSCServer predicateForAttribute:@"SELF" matchingOSCPattern:oscPattern];
    predicate = [NSPredicate predicateWithFormat:[predicate.predicateFormat stringByReplacingOccurrencesOfString:@"#SELF" withString:@"SELF"]]; // hack around passing reserved word to `predicateWithFormat:`
    
    // then
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:str1] );
    XCTAssertTrue( [predicate evaluateWithObject:str2] );
    XCTAssertTrue( [predicate evaluateWithObject:str3] );
    XCTAssertFalse( [predicate evaluateWithObject:str4] );
    XCTAssertFalse( [predicate evaluateWithObject:str5] );
    XCTAssertFalse( [predicate evaluateWithObject:str6] );
}

- (void) testThat_08_F53OSCCServerPredicateMatches3QuestionMarkWildcards
{
    NSString *oscPattern = @"???";
    
    NSString *str1 = @"1";
    NSString *str2 = @"21";
    NSString *str3 = @"1.";
    NSString *str4 = @"1.3";
    NSString *str5 = @"1?3"; // ? invalid in OSC address
    NSString *str6 = @"1 3"; // space invalid in OSC address
    
    // when
    NSPredicate *predicate = [F53OSCServer predicateForAttribute:@"SELF" matchingOSCPattern:oscPattern];
    predicate = [NSPredicate predicateWithFormat:[predicate.predicateFormat stringByReplacingOccurrencesOfString:@"#SELF" withString:@"SELF"]]; // hack around passing reserved word to `predicateWithFormat:`
    
    // then
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:str1] );
    XCTAssertFalse( [predicate evaluateWithObject:str2] );
    XCTAssertFalse( [predicate evaluateWithObject:str3] );
    XCTAssertTrue( [predicate evaluateWithObject:str4] );
    XCTAssertFalse( [predicate evaluateWithObject:str5] );
    XCTAssertFalse( [predicate evaluateWithObject:str6] );
}

- (void) testThat_09_F53OSCCServerPredicateMatchesQuestionMarkWildcardPrefix
{
    NSString *oscPattern = @"?.";
    
    NSString *str1 = @"1";
    NSString *str2 = @"21";
    NSString *str3 = @"1.";
    NSString *str4 = @"1.3";
    NSString *str5 = @"1?3"; // ? invalid in OSC address
    NSString *str6 = @"1 3"; // space invalid in OSC address
    
    // when
    NSPredicate *predicate = [F53OSCServer predicateForAttribute:@"SELF" matchingOSCPattern:oscPattern];
    predicate = [NSPredicate predicateWithFormat:[predicate.predicateFormat stringByReplacingOccurrencesOfString:@"#SELF" withString:@"SELF"]]; // hack around passing reserved word to `predicateWithFormat:`
    
    // then
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:str1] );
    XCTAssertFalse( [predicate evaluateWithObject:str2] );
    XCTAssertTrue( [predicate evaluateWithObject:str3] );
    XCTAssertFalse( [predicate evaluateWithObject:str4] );
    XCTAssertFalse( [predicate evaluateWithObject:str5] );
    XCTAssertFalse( [predicate evaluateWithObject:str6] );
}

- (void) testThat_10_F53OSCCServerPredicateMatchesQuestionMarkWildcardSuffix
{
    NSString *oscPattern = @"1?";
    
    NSString *str1 = @"1";
    NSString *str2 = @"21";
    NSString *str3 = @"1.";
    NSString *str4 = @"1.3";
    NSString *str5 = @"1?3"; // ? invalid in OSC address
    NSString *str6 = @"1 3"; // space invalid in OSC address
    
    // when
    NSPredicate *predicate = [F53OSCServer predicateForAttribute:@"SELF" matchingOSCPattern:oscPattern];
    predicate = [NSPredicate predicateWithFormat:[predicate.predicateFormat stringByReplacingOccurrencesOfString:@"#SELF" withString:@"SELF"]]; // hack around passing reserved word to `predicateWithFormat:`
    
    // then
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:str1] );
    XCTAssertFalse( [predicate evaluateWithObject:str2] );
    XCTAssertTrue( [predicate evaluateWithObject:str3] );
    XCTAssertFalse( [predicate evaluateWithObject:str4] );
    XCTAssertFalse( [predicate evaluateWithObject:str5] );
    XCTAssertFalse( [predicate evaluateWithObject:str6] );
}

- (void) testThat_11_F53OSCCServerPredicateMatchesQuestionMarkWildcardMiddle
{
    NSString *oscPattern = @"1?3";
    
    NSString *str1 = @"1";
    NSString *str2 = @"21";
    NSString *str3 = @"1.";
    NSString *str4 = @"1.3";
    NSString *str5 = @"1?3"; // ? invalid in OSC address
    NSString *str6 = @"1 3"; // space invalid in OSC address
    
    // when
    NSPredicate *predicate = [F53OSCServer predicateForAttribute:@"SELF" matchingOSCPattern:oscPattern];
    predicate = [NSPredicate predicateWithFormat:[predicate.predicateFormat stringByReplacingOccurrencesOfString:@"#SELF" withString:@"SELF"]]; // hack around passing reserved word to `predicateWithFormat:`
    
    // then
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:str1] );
    XCTAssertFalse( [predicate evaluateWithObject:str2] );
    XCTAssertFalse( [predicate evaluateWithObject:str3] );
    XCTAssertTrue( [predicate evaluateWithObject:str4] );
    XCTAssertFalse( [predicate evaluateWithObject:str5] );
    XCTAssertFalse( [predicate evaluateWithObject:str6] );
}

- (void) testThat_12_F53OSCCServerPredicateMatchesStringRangeWildcard
{
    NSString *str1 = @"1";
    NSString *str2 = @"2";
    NSString *str3 = @"3";
    NSString *str4 = @"12";
    NSString *str5 = @"13";
    NSString *str6 = @"1 3";
    
    // when
    NSString *oscPattern;
    NSPredicate *predicate;
    
    // then
    oscPattern = @"12";
    predicate = [F53OSCServer predicateForAttribute:@"SELF" matchingOSCPattern:oscPattern];
    predicate = [NSPredicate predicateWithFormat:[predicate.predicateFormat stringByReplacingOccurrencesOfString:@"#SELF" withString:@"SELF"]]; // hack around passing reserved word to `predicateWithFormat:`
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:str1] );
    XCTAssertFalse( [predicate evaluateWithObject:str2] );
    XCTAssertFalse( [predicate evaluateWithObject:str3] );
    XCTAssertTrue( [predicate evaluateWithObject:str4] );
    XCTAssertFalse( [predicate evaluateWithObject:str5] );
    XCTAssertFalse( [predicate evaluateWithObject:str6] );
    
    oscPattern = @"[12]";
    predicate = [F53OSCServer predicateForAttribute:@"SELF" matchingOSCPattern:oscPattern];
    predicate = [NSPredicate predicateWithFormat:[predicate.predicateFormat stringByReplacingOccurrencesOfString:@"#SELF" withString:@"SELF"]]; // hack around passing reserved word to `predicateWithFormat:`
    XCTAssertNotNil( predicate );
    XCTAssertTrue( [predicate evaluateWithObject:str1] );
    XCTAssertTrue( [predicate evaluateWithObject:str2] );
    XCTAssertFalse( [predicate evaluateWithObject:str3] );
    XCTAssertFalse( [predicate evaluateWithObject:str4] );
    XCTAssertFalse( [predicate evaluateWithObject:str5] );
    XCTAssertFalse( [predicate evaluateWithObject:str6] );
    
    oscPattern = @"1-3";
    predicate = [F53OSCServer predicateForAttribute:@"SELF" matchingOSCPattern:oscPattern];
    predicate = [NSPredicate predicateWithFormat:[predicate.predicateFormat stringByReplacingOccurrencesOfString:@"#SELF" withString:@"SELF"]]; // hack around passing reserved word to `predicateWithFormat:`
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:str1] );
    XCTAssertFalse( [predicate evaluateWithObject:str2] );
    XCTAssertFalse( [predicate evaluateWithObject:str3] );
    XCTAssertFalse( [predicate evaluateWithObject:str4] );
    XCTAssertFalse( [predicate evaluateWithObject:str5] );
    XCTAssertFalse( [predicate evaluateWithObject:str6] );
    
    oscPattern = @"[1-3]";
    predicate = [F53OSCServer predicateForAttribute:@"SELF" matchingOSCPattern:oscPattern];
    predicate = [NSPredicate predicateWithFormat:[predicate.predicateFormat stringByReplacingOccurrencesOfString:@"#SELF" withString:@"SELF"]]; // hack around passing reserved word to `predicateWithFormat:`
    XCTAssertNotNil( predicate );
    XCTAssertTrue( [predicate evaluateWithObject:str1] );
    XCTAssertTrue( [predicate evaluateWithObject:str2] );
    XCTAssertTrue( [predicate evaluateWithObject:str3] );
    XCTAssertFalse( [predicate evaluateWithObject:str4] );
    XCTAssertFalse( [predicate evaluateWithObject:str5] );
    XCTAssertFalse( [predicate evaluateWithObject:str6] );
    
    oscPattern = @"[1][2]";
    predicate = [F53OSCServer predicateForAttribute:@"SELF" matchingOSCPattern:oscPattern];
    predicate = [NSPredicate predicateWithFormat:[predicate.predicateFormat stringByReplacingOccurrencesOfString:@"#SELF" withString:@"SELF"]]; // hack around passing reserved word to `predicateWithFormat:`
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:str1] );
    XCTAssertFalse( [predicate evaluateWithObject:str2] );
    XCTAssertFalse( [predicate evaluateWithObject:str3] );
    XCTAssertTrue( [predicate evaluateWithObject:str4] );
    XCTAssertFalse( [predicate evaluateWithObject:str5] );
    XCTAssertFalse( [predicate evaluateWithObject:str6] );
    
    oscPattern = @"1,2,12";
    predicate = [F53OSCServer predicateForAttribute:@"SELF" matchingOSCPattern:oscPattern];
    predicate = [NSPredicate predicateWithFormat:[predicate.predicateFormat stringByReplacingOccurrencesOfString:@"#SELF" withString:@"SELF"]]; // hack around passing reserved word to `predicateWithFormat:`
    XCTAssertNotNil( predicate );
    XCTAssertTrue( [predicate evaluateWithObject:str1] );
    XCTAssertTrue( [predicate evaluateWithObject:str2] );
    XCTAssertFalse( [predicate evaluateWithObject:str3] );
    XCTAssertTrue( [predicate evaluateWithObject:str4] );
    XCTAssertFalse( [predicate evaluateWithObject:str5] );
    XCTAssertFalse( [predicate evaluateWithObject:str6] );
    
    oscPattern = @"{1,2,12}";
    predicate = [F53OSCServer predicateForAttribute:@"SELF" matchingOSCPattern:oscPattern];
    predicate = [NSPredicate predicateWithFormat:[predicate.predicateFormat stringByReplacingOccurrencesOfString:@"#SELF" withString:@"SELF"]]; // hack around passing reserved word to `predicateWithFormat:`
    XCTAssertNotNil( predicate );
    XCTAssertTrue( [predicate evaluateWithObject:str1] );
    XCTAssertTrue( [predicate evaluateWithObject:str2] );
    XCTAssertFalse( [predicate evaluateWithObject:str3] );
    XCTAssertTrue( [predicate evaluateWithObject:str4] );
    XCTAssertFalse( [predicate evaluateWithObject:str5] );
    XCTAssertFalse( [predicate evaluateWithObject:str6] );
}

- (void) testThat_13_F53OSCCServerPredicateMatchesStringListWildcard
{
    NSString *str1 = @"1";
    NSString *str2 = @"2";
    NSString *str3 = @"3";
    NSString *str4 = @"11";
    NSString *str5 = @"12";
    NSString *str6 = @"13";
    
    // when
    NSString *oscPattern;
    NSPredicate *predicate;
    
    // then
    oscPattern = @"{12}";
    predicate = [F53OSCServer predicateForAttribute:@"SELF" matchingOSCPattern:oscPattern];
    predicate = [NSPredicate predicateWithFormat:[predicate.predicateFormat stringByReplacingOccurrencesOfString:@"#SELF" withString:@"SELF"]]; // hack around passing reserved word to `predicateWithFormat:`
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:str1] );
    XCTAssertFalse( [predicate evaluateWithObject:str2] );
    XCTAssertFalse( [predicate evaluateWithObject:str3] );
    XCTAssertFalse( [predicate evaluateWithObject:str4] );
    XCTAssertTrue( [predicate evaluateWithObject:str5] );
    XCTAssertFalse( [predicate evaluateWithObject:str6] );
    
    oscPattern = @"{12,13}";
    predicate = [F53OSCServer predicateForAttribute:@"SELF" matchingOSCPattern:oscPattern];
    predicate = [NSPredicate predicateWithFormat:[predicate.predicateFormat stringByReplacingOccurrencesOfString:@"#SELF" withString:@"SELF"]]; // hack around passing reserved word to `predicateWithFormat:`
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:str1] );
    XCTAssertFalse( [predicate evaluateWithObject:str2] );
    XCTAssertFalse( [predicate evaluateWithObject:str3] );
    XCTAssertFalse( [predicate evaluateWithObject:str4] );
    XCTAssertTrue( [predicate evaluateWithObject:str5] );
    XCTAssertTrue( [predicate evaluateWithObject:str6] );
    
    oscPattern = @"{[1-3],[1][1-3]}";
    predicate = [F53OSCServer predicateForAttribute:@"SELF" matchingOSCPattern:oscPattern];
    predicate = [NSPredicate predicateWithFormat:[predicate.predicateFormat stringByReplacingOccurrencesOfString:@"#SELF" withString:@"SELF"]]; // hack around passing reserved word to `predicateWithFormat:`
    XCTAssertNotNil( predicate );
    XCTAssertTrue( [predicate evaluateWithObject:str1] );
    XCTAssertTrue( [predicate evaluateWithObject:str2] );
    XCTAssertTrue( [predicate evaluateWithObject:str3] );
    XCTAssertTrue( [predicate evaluateWithObject:str4] );
    XCTAssertTrue( [predicate evaluateWithObject:str5] );
    XCTAssertTrue( [predicate evaluateWithObject:str6] );
    
    oscPattern = @"{[1-3],[1][2-3]}";
    predicate = [F53OSCServer predicateForAttribute:@"SELF" matchingOSCPattern:oscPattern];
    predicate = [NSPredicate predicateWithFormat:[predicate.predicateFormat stringByReplacingOccurrencesOfString:@"#SELF" withString:@"SELF"]]; // hack around passing reserved word to `predicateWithFormat:`
    XCTAssertNotNil( predicate );
    XCTAssertTrue( [predicate evaluateWithObject:str1] );
    XCTAssertTrue( [predicate evaluateWithObject:str2] );
    XCTAssertTrue( [predicate evaluateWithObject:str3] );
    XCTAssertFalse( [predicate evaluateWithObject:str4] );
    XCTAssertTrue( [predicate evaluateWithObject:str5] );
    XCTAssertTrue( [predicate evaluateWithObject:str6] );
    
    oscPattern = @"{[!1-3],[1][1-3]}"; // NOT characters 1, -, or 3; character sequences 11 thru 13
    predicate = [F53OSCServer predicateForAttribute:@"SELF" matchingOSCPattern:oscPattern];
    predicate = [NSPredicate predicateWithFormat:[predicate.predicateFormat stringByReplacingOccurrencesOfString:@"#SELF" withString:@"SELF"]]; // hack around passing reserved word to `predicateWithFormat:`
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:str1] );
    XCTAssertTrue( [predicate evaluateWithObject:str2] );
    XCTAssertFalse( [predicate evaluateWithObject:str3] );
    XCTAssertTrue( [predicate evaluateWithObject:str4] );
    XCTAssertTrue( [predicate evaluateWithObject:str5] );
    XCTAssertTrue( [predicate evaluateWithObject:str6] );
    
    oscPattern = @"{[!12],[1][2-3]}"; // NOT characters 1 or 2; character sequences 12 thru 13
    predicate = [F53OSCServer predicateForAttribute:@"SELF" matchingOSCPattern:oscPattern];
    predicate = [NSPredicate predicateWithFormat:[predicate.predicateFormat stringByReplacingOccurrencesOfString:@"#SELF" withString:@"SELF"]]; // hack around passing reserved word to `predicateWithFormat:`
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:str1] );
    XCTAssertFalse( [predicate evaluateWithObject:str2] );
    XCTAssertTrue( [predicate evaluateWithObject:str3] );
    XCTAssertFalse( [predicate evaluateWithObject:str4] );
    XCTAssertTrue( [predicate evaluateWithObject:str5] );
    XCTAssertTrue( [predicate evaluateWithObject:str6] );
    
    oscPattern = @"{2,?3}";
    predicate = [F53OSCServer predicateForAttribute:@"SELF" matchingOSCPattern:oscPattern];
    predicate = [NSPredicate predicateWithFormat:[predicate.predicateFormat stringByReplacingOccurrencesOfString:@"#SELF" withString:@"SELF"]]; // hack around passing reserved word to `predicateWithFormat:`
    XCTAssertNotNil( predicate );
    XCTAssertFalse( [predicate evaluateWithObject:str1] );
    XCTAssertTrue( [predicate evaluateWithObject:str2] );
    XCTAssertFalse( [predicate evaluateWithObject:str3] );
    XCTAssertFalse( [predicate evaluateWithObject:str4] );
    XCTAssertFalse( [predicate evaluateWithObject:str5] );
    XCTAssertTrue( [predicate evaluateWithObject:str6] );
    
    oscPattern = @"{1*,1}";
    predicate = [F53OSCServer predicateForAttribute:@"SELF" matchingOSCPattern:oscPattern];
    predicate = [NSPredicate predicateWithFormat:[predicate.predicateFormat stringByReplacingOccurrencesOfString:@"#SELF" withString:@"SELF"]]; // hack around passing reserved word to `predicateWithFormat:`
    XCTAssertNotNil( predicate );
    XCTAssertTrue( [predicate evaluateWithObject:str1] );
    XCTAssertFalse( [predicate evaluateWithObject:str2] );
    XCTAssertFalse( [predicate evaluateWithObject:str3] );
    XCTAssertTrue( [predicate evaluateWithObject:str4] );
    XCTAssertTrue( [predicate evaluateWithObject:str5] );
    XCTAssertTrue( [predicate evaluateWithObject:str6] );
}

@end

NS_ASSUME_NONNULL_END
