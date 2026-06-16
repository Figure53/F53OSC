//
//  F53OSCSocket+Internal.h
//  F53OSC Tests
//
//  Created by Christopher Cahoon on 5/23/26.
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

#import <Network/Network.h>

#if F53OSC_BUILT_AS_FRAMEWORK
#import <F53OSC/F53OSCSocket.h>
#else
#import "F53OSCSocket.h"
#endif

NS_ASSUME_NONNULL_BEGIN

//
//  Internal factory used by the listener's new_connection_handler to wrap an
//  accepted nw_connection_t as a child F53OSCSocket. Not part of the public API.
//  F53OSCServer.m should import this header to call the factory.
//

@interface F53OSCSocket (Internal)

+ (instancetype) socketWrappingAcceptedConnection:(nw_connection_t)connection
                                            isTcp:(BOOL)isTcp
                                             host:(NSString *)host
                                             port:(UInt16)port
                                    callbackQueue:(dispatch_queue_t)queue;

// Push bytes through the underlying nw_connection_t without encryption or SLIP
// framing. Intended for tests that need to inject pre-shaped wire bytes (e.g.
// payloads encrypted with a mismatched key, to verify the receive side drops
// them). Production code MUST NOT call this; use -sendPacket: instead.
- (void) sendRawBytes:(NSData *)bytes;

@end


// Test-only hook on F53OSCStats. Forces the current 1-second window to
// complete and rotate counters synchronously, without waiting for the timer.
@interface F53OSCStats (Internal)
- (void) completeCurrentInterval;
@end

NS_ASSUME_NONNULL_END
