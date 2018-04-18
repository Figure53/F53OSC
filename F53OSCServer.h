//
//  F53OSCServer.h
//
//  Created by Sean Dougall on 3/23/11.
//
//  Copyright (c) 2011-2018 Figure 53 LLC, http://figure53.com
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

#import "F53OSC.h"

#define F53_OSC_SERVER_DEBUG 0


NS_ASSUME_NONNULL_BEGIN

@interface F53OSCServer : NSObject <GCDAsyncSocketDelegate, GCDAsyncUdpSocketDelegate>

+ (NSString *) validCharsForOSCMethod;
+ (NSPredicate *) predicateForAttribute:(NSString *)attributeName 
                     matchingOSCPattern:(NSString *)pattern;

@property (nonatomic, weak, nullable)   id <F53OSCPacketDestination> delegate;
@property (nonatomic, assign)           UInt16 port;
@property (nonatomic, assign)           UInt16 udpReplyPort;

- (instancetype) initWithDelegateQueue:(nullable dispatch_queue_t)queue;

- (BOOL) startListening;
- (void) stopListening;

- (F53OSCSocket *)udpSocket;
- (F53OSCSocket *)tcpSocket;

@end

NS_ASSUME_NONNULL_END
