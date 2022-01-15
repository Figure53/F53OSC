//
//  F53OSCEncryptHandshake.m
//  QLab
//
//  Created by Chad Sellers on 1/14/22.
//  Copyright © 2022 Figure 53, LLC. All rights reserved.
//

#import "F53OSCEncryptHandshake.h"

#define F53OSCHandshakeProtocolVersion 1

@interface F53OSCEncryptHandshake ()

@property (weak) F53OSCEncrypt *encrypter;

@end

@implementation F53OSCEncryptHandshake

+ (instancetype) handshakeWithEncrypter:(F53OSCEncrypt *)encrypter
{
    F53OSCEncryptHandshake *handshake = [[F53OSCEncryptHandshake alloc] init];
    handshake.encrypter = encrypter;
    return handshake;
}


/// Request arguments:
/// 1: Handshake protocol version
/// 2: Key pair data
- (F53OSCMessage *) requestEncryptionMessage;
{
    NSData *pubKey = self.encrypter.publicKeyData;
    NSArray *args = @[@(F53OSCHandshakeProtocolVersion),
                      pubKey
                     ];
    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:@"!requestEncryption" arguments:args];
    return message;
}

/// Approve arguments:
/// 1: Handshake protocol version
/// 2: Key pair data
/// 3: Salt data
- (F53OSCMessage *) approveEncryptionMessage
{
    NSData *pubKey = self.encrypter.publicKeyData;
    NSData *salt = self.encrypter.salt;
    NSArray *args = @[@(F53OSCHandshakeProtocolVersion),
                      pubKey,
                      salt
                     ];
    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:@"!approveEncryption" arguments:args];
    return message;
}

/// Begin arguments:
/// 1: Handshake protocol version
- (F53OSCMessage *) beginEncryptionMessage
{
    NSArray *args = @[@(F53OSCHandshakeProtocolVersion)];

    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:@"!beginEncryption" arguments:args];
    return message;
}

/// Returns NO on failure
- (BOOL) processHandshakeMessage:(F53OSCMessage *)message
{
    // TODO: Pay attention to protocol version
    // TODO: validity checking in address
    BOOL success = NO;
    if ( [message.addressPattern isEqualToString:@"!requestEncryption"] )
    {
        self.peerKey = message.arguments[1];
        [self.encrypter generateSalt];
        [self.encrypter beginEncryptingWithPeerKey:self.peerKey];
        self.lastProcessedMessage = EncryptionHandshakeMessageRequest;
        success = YES;
    }
    else if ( [message.addressPattern isEqualToString:@"!approveEncryption"] )
    {
        self.peerKey = message.arguments[1];
        NSData *salt = message.arguments[2];
        self.encrypter.salt = salt;
        [self.encrypter beginEncryptingWithPeerKey:self.peerKey];
        self.lastProcessedMessage = EncryptionHandshakeMessageAppprove;
        success = YES;
    }
    else if ( [message.addressPattern isEqualToString:@"!beginEncryption"] )
    {
        self.handshakeComplete = YES;
        self.lastProcessedMessage = EncryptionHandshakeMessageBegin;
        success = YES;
    }
    return success;
}

@end
