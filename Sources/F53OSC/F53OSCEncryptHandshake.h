//
//  F53OSCEncryptHandshake.h
//  QLab
//
//  Created by Chad Sellers on 1/14/22.
//  Copyright © 2022 Figure 53, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "F53OSCMessage.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, EncryptionHandshakeMessage)
{
    EncryptionHandshakeMessageRequest = 0,
    EncryptionHandshakeMessageAppprove,
    EncryptionHandshakeMessageBegin,
};

@interface F53OSCEncryptHandshake : NSObject

@property (assign) BOOL handshakeComplete;
@property (strong) NSData *peerKey; // Peer's public key
@property (assign) EncryptionHandshakeMessage lastProcessedMessage; // Indicated which message was last processed

+ (instancetype) handshakeWithEncrypter:(F53OSCEncrypt *)encrypter;
- (F53OSCMessage *) requestEncryptionMessage;
- (F53OSCMessage *) approveEncryptionMessage;
- (F53OSCMessage *) beginEncryptionMessage;
- (BOOL) processHandshakeMessage:(F53OSCMessage *)message;

@end

NS_ASSUME_NONNULL_END
