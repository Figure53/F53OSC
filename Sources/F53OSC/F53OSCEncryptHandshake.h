//
//  F53OSCEncryptHandshake.h
//  F53OSC
//
//  Created by Chad Sellers on 1/14/22.
//  Copyright (c) 2022-2025 Figure 53, LLC. All rights reserved.
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

#if F53OSC_BUILT_AS_FRAMEWORK
#import <F53OSC/F53OSCMessage.h>
#else
#import "F53OSCMessage.h"
#endif

@class F53OSCEncrypt;


NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, F53OSCEncryptionHandshakeMessage)
{
    F53OSCEncryptionHandshakeMessageNone = 0,
    F53OSCEncryptionHandshakeMessageRequest,
    F53OSCEncryptionHandshakeMessageApprove,
    F53OSCEncryptionHandshakeMessageBegin,
};

@interface F53OSCEncryptHandshake : NSObject

@property (readonly) BOOL handshakeComplete;
@property (readonly) NSData *peerKey; // Peer's public key
@property (readonly) F53OSCEncryptionHandshakeMessage lastProcessedMessage; // Indicated which message was last processed

+ (instancetype) handshakeWithEncrypter:(F53OSCEncrypt *)encrypter;
+ (BOOL) isEncryptHandshakeMessage:(F53OSCMessage *)message;
- (nullable F53OSCMessage *) requestEncryptionMessage;
- (nullable F53OSCMessage *) approveEncryptionMessage;
- (F53OSCMessage *) beginEncryptionMessage;
- (BOOL) processHandshakeMessage:(F53OSCMessage *)message;

+ (int)protocolVersion;

@end


@interface F53OSCEncryptHandshake (DisallowedInits)
- (instancetype)init __attribute__((unavailable("Use +handshakeWithEncrypter: instead.")));
@end

NS_ASSUME_NONNULL_END
