//
//  F53OSCEncryptHandshake.m
//  QLab
//
//  Created by Chad Sellers on 1/14/22.
//  Copyright © 2022 Figure 53, LLC. All rights reserved.
//

#import "F53OSCEncryptHandshake.h"

#define F53OSCHandshakeProtocolVersion 1

static NSString *const kRequestEncryptionAddress = @"!requestEncryption";
static NSString *const kApproveEncryptionAddress = @"!approveEncryption";
static NSString *const kBeginEncryptionAddress = @"!beginEncryption";

@interface F53OSCEncryptHandshake ()

@property (weak) F53OSCEncrypt *encrypter;

@end

@implementation F53OSCEncryptHandshake

+ (BOOL) isEncryptHandshakeMessage:(F53OSCMessage *)message
{
    if ( [message.addressPattern isEqualToString:kRequestEncryptionAddress] ||
         [message.addressPattern isEqualToString:kApproveEncryptionAddress] ||
         [message.addressPattern isEqualToString:kBeginEncryptionAddress] )
        return YES;
    return NO;
}

+ (instancetype) handshakeWithEncrypter:(F53OSCEncrypt *)encrypter
{
    F53OSCEncryptHandshake *handshake = [[F53OSCEncryptHandshake alloc] init];
    handshake.encrypter = encrypter;
    return handshake;
}


/// Request arguments:
/// 1: Handshake protocol version
/// 2: Key pair data
- (nullable F53OSCMessage *) requestEncryptionMessage;
{
    NSData *pubKey = self.encrypter.publicKeyData;
    if ( pubKey )
    {
        NSArray *args = @[@(F53OSCHandshakeProtocolVersion),
                          pubKey
                         ];
        F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:kRequestEncryptionAddress arguments:args];
        return message;
    }
    else
    {
        NSLog(@"Error: F53OSC cannot create request encryption message if public key is missing");
        return nil;
    }
}

/// Approve arguments:
/// 1: Handshake protocol version
/// 2: Key pair data
/// 3: Salt data
- (nullable F53OSCMessage *) approveEncryptionMessage
{
    NSData *pubKey = self.encrypter.publicKeyData;
    NSData *salt = self.encrypter.salt;
    if ( pubKey && salt )
    {
        NSArray *args = @[@(F53OSCHandshakeProtocolVersion),
                          pubKey,
                          salt
                         ];
        F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:kApproveEncryptionAddress arguments:args];
        return message;
    }
    else
    {
        if ( !pubKey && !salt )
            NSLog(@"Error: F53OSC cannot create encryption approval message if public key and salt are missing");
        else if ( !pubKey && salt )
            NSLog(@"Error: F53OSC cannot create encryption approval message if public key is missing");
        else if ( pubKey && !salt )
            NSLog(@"Error: F53OSC cannot create encryption approval message if salt is missing");
        return nil;
    }
}

/// Begin arguments:
/// 1: Handshake protocol version
- (F53OSCMessage *) beginEncryptionMessage
{
    NSArray *args = @[@(F53OSCHandshakeProtocolVersion)];

    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:kBeginEncryptionAddress arguments:args];
    return message;
}

/// Returns NO on failure
- (BOOL) processHandshakeMessage:(F53OSCMessage *)message
{
    if ( message.arguments.count < 1 )
    {
        NSLog(@"Error: F53OSC handshake message lacks version information");
        return NO;
    }
    if ( ![message.arguments[0] isKindOfClass:[NSNumber class]] )
    {
        NSLog(@"Error: F53OSC handshake message version is not a number");
        return NO;
    }
    NSNumber *protocolVersion = message.arguments[0];
    if ( protocolVersion.intValue > F53OSCHandshakeProtocolVersion )
    {
        NSLog(@"Warning: F53OSC handshake message with protocol %d, but we only support %d. We assume the other end will handle the version compatibility", protocolVersion.intValue, F53OSCHandshakeProtocolVersion);
    }
    if ( [message.addressPattern isEqualToString:kRequestEncryptionAddress] )
    {
        if ( message.arguments.count < 2 )
        {
            NSLog(@"Error: F53OSC requestEncryption message has too few arguments: %lu", (unsigned long)message.arguments.count);
            return NO;
        }
        if ( ![message.arguments[1] isKindOfClass:[NSData class]] )
        {
            NSLog(@"Error: F53OSC requestEncryption peer key argument is not data");
            return NO;
        }

        self.peerKey = message.arguments[1];
        [self.encrypter generateSalt];
        if ( ![self.encrypter beginEncryptingWithPeerKey:self.peerKey] )
            return NO;
        self.lastProcessedMessage = F53OSCEncryptionHandshakeMessageRequest;
        return YES;
    }
    else if ( [message.addressPattern isEqualToString:kApproveEncryptionAddress] )
    {
        if ( message.arguments.count < 3 )
        {
            NSLog(@"Error: F53OSC approveEncryption message has too few arguments: %lu", (unsigned long)message.arguments.count);
            return NO;
        }
        if ( ![message.arguments[1] isKindOfClass:[NSData class]] )
        {
            NSLog(@"Error: F53OSC approveEncryption peer key argument is not data");
            return NO;
        }
        if ( ![message.arguments[2] isKindOfClass:[NSData class]] )
        {
            NSLog(@"Error: F53OSC approveEncryption salt argument is not data");
            return NO;
        }

        self.peerKey = message.arguments[1];
        NSData *salt = message.arguments[2];
        self.encrypter.salt = salt;
        if ( ![self.encrypter beginEncryptingWithPeerKey:self.peerKey] )
            return NO;
        self.lastProcessedMessage = F53OSCEncryptionHandshakeMessageAppprove;
        return YES;
    }
    else if ( [message.addressPattern isEqualToString:kBeginEncryptionAddress] )
    {
        self.handshakeComplete = YES;
        self.lastProcessedMessage = F53OSCEncryptionHandshakeMessageBegin;
        return YES;
    }
    NSLog(@"F53OSC received unknown encryption handshake message: %@", message.addressPattern);
    return NO;
}

@end
