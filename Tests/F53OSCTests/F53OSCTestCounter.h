//
//  F53OSCTestCounter.h
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
//  A combined server + client delegate that counts delivered messages and
//  signals a semaphore when the running total reaches `targetCount`. Used by
//  the throughput and performance test suites. Thread-safe: `receivedCount` is
//  updated under a lock so the doneSemaphore fires exactly once per reset
//  cycle. waitForCount:timeout: spins the run loop instead of blocking so
//  delegate callbacks dispatched to main aren't starved.
//

#import <Foundation/Foundation.h>

#if F53OSC_BUILT_AS_FRAMEWORK
#import <F53OSC/F53OSC.h>
#else
#import "F53OSC.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@interface F53OSCTestCounter : NSObject <F53OSCServerDelegate, F53OSCClientDelegate>

@property (atomic) NSInteger receivedCount;
@property (atomic) NSInteger targetCount;
@property (strong, nonatomic) dispatch_semaphore_t doneSemaphore;
@property (strong, nonatomic) dispatch_semaphore_t connectSemaphore;

- (void) reset;
- (void) waitForCount:(NSInteger)count timeout:(NSTimeInterval)timeout;

@end

NS_ASSUME_NONNULL_END
