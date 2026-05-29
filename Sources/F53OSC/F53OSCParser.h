//
//  F53OSCParser.h
//  F53OSC
//
//  Created by Christopher Ashworth on 1/30/13.
//  Copyright (c) 2013-2025 Figure 53 LLC, https://figure53.com
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

#import <Foundation/Foundation.h>

@class F53OSCBundle;
@class F53OSCMessage;
@class F53OSCPacket;
@class F53OSCSocket;
@protocol F53OSCPacketDestination;
@protocol F53OSCControlHandler;


NS_ASSUME_NONNULL_BEGIN

@interface F53OSCParser : NSObject

+ (nullable F53OSCMessage *) parseOscMessageData:(NSData *)data;

// Decode raw OSC bytes into a packet object without delivering to a destination.
// Returns an F53OSCMessage for messages, F53OSCBundle for bundles, nil if malformed.
// Inner bundle elements are recursively validated to match the work +processOscData:
// performs, but no delegate dispatch occurs. Use when measuring decode cost or when
// the caller wants the decoded structure directly.
+ (nullable F53OSCPacket *) packetFromData:(NSData *)data;

+ (void) processOscData:(NSData *)data forDestination:(id<F53OSCPacketDestination>)destination replyToSocket:(F53OSCSocket *)socket controlHandler:(nullable id<F53OSCControlHandler>)controlHandler wasEncrypted:(BOOL)wasEncrypted;

+ (void) translateSlipData:(NSData *)slipData toData:(NSMutableData *)data withState:(NSMutableDictionary<NSString *, id> *)state destination:(id<F53OSCPacketDestination>)destination
    controlHandler:(nullable id<F53OSCControlHandler>)controlHandler;

// Frame an arbitrary payload as a double-END SLIP packet. Pure transformation, no
// network. Exposed for benchmarks and integration tests. Production also uses this
// via F53OSCSocket -sendPacket:.
+ (NSData *) slipFrameData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
