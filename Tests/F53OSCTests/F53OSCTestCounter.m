//
//  F53OSCTestCounter.m
//  F53OSC Tests
//
//  Created by Christopher Cahoon on 5/24/26.
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

#if !__has_feature(objc_arc)
#error This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#import "F53OSCTestCounter.h"

NS_ASSUME_NONNULL_BEGIN

@implementation F53OSCTestCounter
{
    // guards the "signal doneSemaphore once" logic
    NSLock *_lock;
    BOOL _signaled;
}

- (instancetype) init
{
    self = [super init];
    if ( self )
    {
        _lock = [[NSLock alloc] init];
        _doneSemaphore = dispatch_semaphore_create(0);
        _connectSemaphore = dispatch_semaphore_create(0);
        _receivedCount = 0;
        _targetCount = 0;
        _signaled = NO;
    }
    return self;
}

- (void) reset
{
    [_lock lock];
    _receivedCount = 0;
    _signaled = NO;
    _doneSemaphore = dispatch_semaphore_create(0);
    [_lock unlock];
}

- (void) waitForCount:(NSInteger)count timeout:(NSTimeInterval)timeout
{
    self.targetCount = count;
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    while ( [deadline timeIntervalSinceNow] > 0
            && dispatch_semaphore_wait(_doneSemaphore, DISPATCH_TIME_NOW) != 0 )
    {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
}


#pragma mark - F53OSCPacketDestination (server delegate)

- (void) takeMessage:(nullable F53OSCMessage *)message
{
    if ( message == nil )
        return;

    [_lock lock];
    _receivedCount++;
    NSInteger current = _receivedCount;
    NSInteger target = _targetCount;
    BOOL alreadySignaled = _signaled;
    if ( current >= target && !alreadySignaled && target > 0 )
    {
        _signaled = YES;
        dispatch_semaphore_signal(_doneSemaphore);
    }
    [_lock unlock];
}


#pragma mark - F53OSCClientDelegate

- (void) clientDidConnect:(F53OSCClient *)client
{
    dispatch_semaphore_signal(_connectSemaphore);
}

@end

NS_ASSUME_NONNULL_END
