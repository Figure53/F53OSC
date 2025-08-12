//
//  F53OSCEncryptHandshake.m
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

#if !__has_feature(objc_arc)
#error This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#import "F53OSCEncryptHandshake.h"

#if __has_include(<F53OSC/F53OSC-Swift.h>) // F53OSC_BUILT_AS_FRAMEWORK
#import <F53OSC/F53OSC-Swift.h>
#endif

#define F53OSCHandshakeProtocolVersion 1

static NSString *const kRequestEncryptionAddress = @"!requestEncryption";
static NSString *const kApproveEncryptionAddress = @"!approveEncryption";
static NSString *const kBeginEncryptionAddress = @"!beginEncryption";


NS_ASSUME_NONNULL_BEGIN

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
        NSArray<id> *args = @[@(F53OSCHandshakeProtocolVersion),
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
        NSArray<id> *args = @[@(F53OSCHandshakeProtocolVersion),
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
    NSArray<id> *args = @[@(F53OSCHandshakeProtocolVersion)];

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

NS_ASSUME_NONNULL_END
