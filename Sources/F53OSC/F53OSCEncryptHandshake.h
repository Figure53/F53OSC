//
//  F53OSCEncryptHandshake.h
//  QLab
//
//  Created by Chad Sellers on 1/14/22.
//  Copyright © 2022 Figure 53, LLC. All rights reserved.
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
    F53OSCEncryptionHandshakeMessageRequest = 0,
    F53OSCEncryptionHandshakeMessageAppprove,
    F53OSCEncryptionHandshakeMessageBegin,
};

@interface F53OSCEncryptHandshake : NSObject

@property (assign) BOOL handshakeComplete;
@property (strong) NSData *peerKey; // Peer's public key
@property (assign) F53OSCEncryptionHandshakeMessage lastProcessedMessage; // Indicated which message was last processed

+ (instancetype) handshakeWithEncrypter:(F53OSCEncrypt *)encrypter;
+ (BOOL) isEncryptHandshakeMessage:(F53OSCMessage *)message;
- (nullable F53OSCMessage *) requestEncryptionMessage;
- (nullable F53OSCMessage *) approveEncryptionMessage;
- (F53OSCMessage *) beginEncryptionMessage;
- (BOOL) processHandshakeMessage:(F53OSCMessage *)message;

@end

NS_ASSUME_NONNULL_END
