//
//  F53OSC_StatsTests.m
//  F53OSC Tests
//
//  Created by Christopher Cahoon on 5/23/26.
//  Adapted from OSCStatsTests.swift in F53OSC-Swift (rev a3006395c721).
//  Copyright (c) 2026 Figure 53 LLC, https://figure53.com
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

// Skipped Swift tests and reasons:
//   testStart             — no separate start method. Stats start automatically in init.
//   testStop              — no public -stop method. F53OSCSocket owns the stats and calls
//                           -stop internally. Not observable from outside.
//   testStartTwiceIsNoOp  — same reason as testStart. No separate run-state concept.
//   testRecordBytesWhenNotRunning — no separate "not running" state. Always accumulates.
//   testReset             — no public -reset method on F53OSCStats.
//   testSnapshot          — no snapshot type in the ObjC API.
//   testSnapshotWhenStopped — same reason as testSnapshot.

#if !__has_feature(objc_arc)
#error This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#import <XCTest/XCTest.h>

#if F53OSC_BUILT_AS_FRAMEWORK
#import <F53OSC/F53OSC.h>
#else
#import "F53OSC.h"
#endif

#import "F53OSCSocket+Internal.h"


NS_ASSUME_NONNULL_BEGIN

@interface F53OSC_StatsTests : XCTestCase
@end

@implementation F53OSC_StatsTests


#pragma mark - Initial state

- (void) testInitialState
{
    F53OSCStats *stats = [[F53OSCStats alloc] init];

    XCTAssertEqualWithAccuracy(stats.totalBytes, 0.0, 0.0001,
                               @"totalBytes should be 0 immediately after init");
    XCTAssertEqualWithAccuracy(stats.bytesPerSecond, 0.0, 0.0001,
                               @"bytesPerSecond should be 0 immediately after init");
}


#pragma mark - Recording bytes

- (void) testRecordBytes
{
    F53OSCStats *stats = [[F53OSCStats alloc] init];

    [stats addBytes:100.0];
    XCTAssertEqualWithAccuracy(stats.totalBytes, 100.0, 0.0001,
                               @"totalBytes should be 100 after addBytes:100");

    [stats addBytes:50.0];
    XCTAssertEqualWithAccuracy(stats.totalBytes, 150.0, 0.0001,
                               @"totalBytes should be 150 after addBytes:50");
}


#pragma mark - Bytes-per-second calculation

- (void) testBytesPerSecondCalculation
{
    F53OSCStats *stats = [[F53OSCStats alloc] init];

    [stats addBytes:200.0];
    [stats completeCurrentInterval];

    XCTAssertEqualWithAccuracy(stats.bytesPerSecond, 200.0, 0.0001,
                               @"bytesPerSecond should equal bytes added in the completed interval");
}

- (void) testBytesPerSecondResetsEachSecond
{
    F53OSCStats *stats = [[F53OSCStats alloc] init];

    [stats addBytes:500.0];
    [stats completeCurrentInterval];

    XCTAssertEqualWithAccuracy(stats.bytesPerSecond, 500.0, 0.0001,
                               @"bytesPerSecond should be 500 after first completed interval");

    // complete another interval with no new bytes — rate should drop to 0
    [stats completeCurrentInterval];

    XCTAssertEqualWithAccuracy(stats.bytesPerSecond, 0.0, 0.0001,
                               @"bytesPerSecond should be 0 when no bytes were added in the second interval");
}


#pragma mark - Concurrency

// This test has no Swift analog. It exercises the atomic counters introduced
// when F53OSCStats switched from non-atomic ivars to os_atomic / _Atomic.
- (void) testConcurrentAddBytes
{
    F53OSCStats *stats = [[F53OSCStats alloc] init];
    NSUInteger threadCount = 8;
    NSUInteger callsPerThread = 10000;
    dispatch_group_t group = dispatch_group_create();

    for ( NSUInteger t = 0; t < threadCount; t++ )
    {
        dispatch_group_async( group, dispatch_get_global_queue( QOS_CLASS_USER_INITIATED, 0 ), ^{
            for ( NSUInteger i = 0; i < callsPerThread; i++ )
                [stats addBytes:1.0];
        } );
    }

    dispatch_group_wait( group, DISPATCH_TIME_FOREVER );

    double expected = (double)(threadCount * callsPerThread);
    XCTAssertEqualWithAccuracy( stats.totalBytes, expected, 0.0001,
                                @"totalBytes should equal threadCount × callsPerThread with no lost updates" );
}


@end

NS_ASSUME_NONNULL_END
