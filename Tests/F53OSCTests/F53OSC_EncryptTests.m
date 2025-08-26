//
//  F53OSC_EncryptionTests.m
//  F53OSC
//
//  Created by Brent Lord on 8/5/25.
//  Copyright (c) 2025 Figure 53. All rights reserved.
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

#import <XCTest/XCTest.h>
#import <F53OSC/F53OSC-Swift.h>

#import "F53OSC.h"


NS_ASSUME_NONNULL_BEGIN

@interface F53OSC_EncryptionTests : XCTestCase
@end

@implementation F53OSC_EncryptionTests

//- (void)setUp
//{
//    [super setUp];
//}

//- (void)tearDown
//{
//    [super tearDown];
//}

- (void)setupEncryptionBetweenPeer:(F53OSCEncrypt *)encrypterA andPeer:(F53OSCEncrypt *)encrypterB
{
    // Generate key pairs.
    XCTAssertNotNil([encrypterA generateKeyPair]);
    XCTAssertNotNil([encrypterB generateKeyPair]);

    // Generate and share salt.
    [encrypterA generateSalt];
    encrypterB.salt = encrypterA.salt;

    // Exchange public keys and begin encryption.
    NSData *publicKeyA = [encrypterA publicKeyData];
    NSData *publicKeyB = [encrypterB publicKeyData];

    XCTAssertNotNil(publicKeyA, @"Encrypter A should have public key");
    XCTAssertNotNil(publicKeyB, @"Encrypter B should have public key");
    XCTAssertNotEqualObjects(publicKeyA, publicKeyB, @"Public keys should be different");

    // Begin encryption.
    BOOL didBeginA = [encrypterA beginEncryptingWithPeerKey:publicKeyB];
    BOOL didBeginB = [encrypterB beginEncryptingWithPeerKey:publicKeyA];

    XCTAssertTrue(didBeginA, @"Encrypter A should begin encryption");
    XCTAssertTrue(didBeginB, @"Encrypter B should begin encryption");

    XCTAssertEqualObjects(encrypterA.peerKey, publicKeyB, @"Encrypter A should store peer's public key");
    XCTAssertEqualObjects(encrypterB.peerKey, publicKeyA, @"Encrypter B should store peer's public key");
}


#pragma mark - Basic configuration tests

- (void)testThat__setupWorks
{
    // given
    // - state created by `+setUp` and `-setUp`

    // when
    // - triggered by running this test

    // then
    XCTAssertTrue(YES);
}

- (void)testThat_encryptHasCorrectDefaults
{
    F53OSCEncrypt *encrypter = [[F53OSCEncrypt alloc] init];

    XCTAssertNotNil(encrypter, @"Encrypter should not be nil");
    XCTAssertNil(encrypter.peerKey, @"Default peerKey should be nil");
    XCTAssertNil(encrypter.salt, @"Default salt should be nil");
    XCTAssertNil([encrypter keyPairData], @"Default keyPairData should be nil");
    XCTAssertNil([encrypter publicKeyData], @"Default publicKeyData should be nil");
}

- (void)testThat_encryptCanConfigureProperties
{
    F53OSCEncrypt *encrypter = [[F53OSCEncrypt alloc] init];

    NSData *testPeerKey = [@"test_peer_key_data" dataUsingEncoding:NSUTF8StringEncoding];
    encrypter.peerKey = testPeerKey;
    XCTAssertEqualObjects(encrypter.peerKey, testPeerKey, @"Encrypter peerKey should be %@", testPeerKey);

    NSData *testSalt = [@"test_salt_data" dataUsingEncoding:NSUTF8StringEncoding];
    encrypter.salt = testSalt;
    XCTAssertEqualObjects(encrypter.salt, testSalt, @"Encrypter salt should be %@", testSalt);
}

- (void)testThat_encryptCannotBeCopied
{
    F53OSCEncrypt *encrypter = [[F53OSCEncrypt alloc] init];

    XCTAssertThrows(encrypter.copy, @"Encrypter does not conform to NSCopying");
}

- (void)testThat_encryptCanGenerateKeyPair
{
    F53OSCEncrypt *encrypter = [[F53OSCEncrypt alloc] init];

    NSData *keyPairData = [encrypter generateKeyPair];
    XCTAssertNotNil(keyPairData, @"Key pair generation should return data");
    XCTAssertGreaterThan(keyPairData.length, 0, @"Key pair data should not be empty");

    // Should be able to get the same data again.
    NSData *retrievedKeyPairData = [encrypter keyPairData];
    XCTAssertEqualObjects(keyPairData, retrievedKeyPairData, @"Retrieved key pair data should match generated data");

    // Public key should also be available.
    NSData *publicKeyData = [encrypter publicKeyData];
    XCTAssertNotNil(publicKeyData, @"Public key data should be available after key pair generation");
    XCTAssertGreaterThan(publicKeyData.length, 0, @"Public key data should not be empty");

    // Public key should be different from private key pair data.
    XCTAssertNotEqualObjects(publicKeyData, keyPairData, @"Public key should be different from key pair data");
}

- (void)testThat_encryptCanBeInitializedWithExistingKeyPair
{
    F53OSCEncrypt *encrypter = [[F53OSCEncrypt alloc] init];

    // Generate a key pair.
    NSData *originalKeyPairData = [encrypter generateKeyPair];
    NSData *originalPublicKey = [encrypter publicKeyData];

    // Create new encrypter with the key pair data.
    F53OSCEncrypt *newEncrypter = [[F53OSCEncrypt alloc] initWithKeyPairData:originalKeyPairData];
    XCTAssertNotNil(newEncrypter, @"Should be able to initialize with existing key pair");

    NSData *restoredKeyPairData = [newEncrypter keyPairData];
    NSData *restoredPublicKey = [newEncrypter publicKeyData];
    XCTAssertEqualObjects(restoredKeyPairData, originalKeyPairData, @"Restored key pair should match original");
    XCTAssertEqualObjects(restoredPublicKey, originalPublicKey, @"Restored public key should match original");
}

- (void)testThat_encryptCanGenerateSalt
{
    F53OSCEncrypt *encrypter = [[F53OSCEncrypt alloc] init];
    [encrypter generateSalt];

    XCTAssertNotNil(encrypter.salt, @"Salt should be generated");
    XCTAssertGreaterThan(encrypter.salt.length, 0, @"Salt should not be empty");

    // Generate a second salt and verify they are different.
    NSData *firstSalt = [encrypter.salt copy];
    [encrypter generateSalt];

    NSData *secondSalt = encrypter.salt;
    XCTAssertNotEqualObjects(firstSalt, secondSalt, @"Generated salts should be different");
}

- (void)testThat_encryptRejectsInvalidKeyPairData
{
    // Try to initialize with invalid key pair data.
    NSData *invalidData = [@"This is not a valid key pair" dataUsingEncoding:NSUTF8StringEncoding];
    F53OSCEncrypt *encrypter = [[F53OSCEncrypt alloc] initWithKeyPairData:invalidData];

    // Should initialize but key pair data should be nil (error logged).
    XCTAssertNotNil(encrypter, @"Encrypter should initialize even with invalid data");
    XCTAssertNil([encrypter keyPairData], @"Key pair data should be nil with invalid input");
    XCTAssertNil([encrypter publicKeyData], @"Public key data should be nil with invalid input");
}


#pragma mark - Key agreement and setup tests

- (void)testThat_twoEncryptersCanEstablishSharedEncryption
{
    F53OSCEncrypt *encrypterA = [[F53OSCEncrypt alloc] init];
    F53OSCEncrypt *encrypterB = [[F53OSCEncrypt alloc] init];
    [self setupEncryptionBetweenPeer:encrypterA andPeer:encrypterB];
}

- (void)testThat_encryptionFailsWithoutSalt
{
    F53OSCEncrypt *encrypterA = [[F53OSCEncrypt alloc] init];
    F53OSCEncrypt *encrypterB = [[F53OSCEncrypt alloc] init];

    // Generate key pairs but no salt.
    XCTAssertNotNil([encrypterA generateKeyPair]);
    XCTAssertNotNil([encrypterB generateKeyPair]);

    NSData *publicKeyB = [encrypterB publicKeyData];

    // Try to begin encryption without salt.
    BOOL didBegin = [encrypterA beginEncryptingWithPeerKey:publicKeyB];

    XCTAssertFalse(didBegin, @"Encryption setup should fail without salt");
}

- (void)testThat_encryptionFailsWithInvalidPeerKey
{
    F53OSCEncrypt *encrypter = [[F53OSCEncrypt alloc] init];

    // Generate key pair and salt.
    XCTAssertNotNil([encrypter generateKeyPair]);
    [encrypter generateSalt];

    // Try to begin encryption with invalid peer key.
    NSData *invalidPeerKey = [@"invalid_peer_key_data" dataUsingEncoding:NSUTF8StringEncoding];
    BOOL didBegin = [encrypter beginEncryptingWithPeerKey:invalidPeerKey];
    XCTAssertFalse(didBegin, @"Encryption setup should fail with invalid peer key");
}


#pragma mark - Data encryption/decryption tests

- (void)testThat_encryptedDataCanBeDecrypted
{
    // Setup encryption between two encrypters.
    F53OSCEncrypt *encrypterA = [[F53OSCEncrypt alloc] init];
    F53OSCEncrypt *encrypterB = [[F53OSCEncrypt alloc] init];
    [self setupEncryptionBetweenPeer:encrypterA andPeer:encrypterB];

    NSString *originalString = @"Hello, encrypted OSC world!";
    NSData *originalData = [originalString dataUsingEncoding:NSUTF8StringEncoding];

    // Encrypt with A.
    NSData *encryptedData = [encrypterA encryptDataWithClearData:originalData];
    XCTAssertNotNil(encryptedData, @"Encryption should succeed");
    XCTAssertGreaterThan(encryptedData.length, 0, @"Encrypted data should not be empty");
    XCTAssertNotEqualObjects(encryptedData, originalData, @"Encrypted data should be different from original");

    // Decrypt with B.
    NSData *decryptedData = [encrypterB decryptDataWithEncryptedData:encryptedData];
    XCTAssertNotNil(decryptedData, @"Decryption should succeed");
    XCTAssertEqualObjects(decryptedData, originalData, @"Decrypted data should match original");

    // Verify string content.
    NSString *decryptedString = [[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(decryptedString, originalString, @"Decrypted string should match original");
}

- (void)testThat_bidirectionalEncryptionWorks
{
    // Setup encryption between two encrypters
    F53OSCEncrypt *encrypterA = [[F53OSCEncrypt alloc] init];
    F53OSCEncrypt *encrypterB = [[F53OSCEncrypt alloc] init];
    [self setupEncryptionBetweenPeer:encrypterA andPeer:encrypterB];

    // Test data from A to B.
    NSString *messageAtoB = @"Message from A to B";
    NSData *dataAtoB = [messageAtoB dataUsingEncoding:NSUTF8StringEncoding];

    NSData *encryptedAtoB = [encrypterA encryptDataWithClearData:dataAtoB];
    NSData *decryptedAtoB = [encrypterB decryptDataWithEncryptedData:encryptedAtoB];

    XCTAssertEqualObjects(decryptedAtoB, dataAtoB, @"A→B encryption should work");

    // Test data from B to A.
    NSString *messageBtoA = @"Message from B to A";
    NSData *dataBtoA = [messageBtoA dataUsingEncoding:NSUTF8StringEncoding];

    NSData *encryptedBtoA = [encrypterB encryptDataWithClearData:dataBtoA];
    NSData *decryptedBtoA = [encrypterA decryptDataWithEncryptedData:encryptedBtoA];

    XCTAssertEqualObjects(decryptedBtoA, dataBtoA, @"B→A encryption should work");
}

- (void)testThat_encryptionFailsWithoutProperSetup
{
    F53OSCEncrypt *encrypter = [[F53OSCEncrypt alloc] init];

    // Try to encrypt without calling beginEncrypting.
    NSData *testData = [@"test data" dataUsingEncoding:NSUTF8StringEncoding];

    NSData *encryptedData = [encrypter encryptDataWithClearData:testData];
    XCTAssertNil(encryptedData, @"Encryption should fail without proper setup");

    NSData *decryptedData = [encrypter decryptDataWithEncryptedData:testData];
    XCTAssertNil(decryptedData, @"Decryption should fail without proper setup");
}

- (void)testThat_decryptionFailsWithInvalidData
{
    F53OSCEncrypt *encrypterA = [[F53OSCEncrypt alloc] init];
    F53OSCEncrypt *encrypterB = [[F53OSCEncrypt alloc] init];
    [self setupEncryptionBetweenPeer:encrypterA andPeer:encrypterB];

    // Try to decrypt invalid/corrupted data.
    NSData *invalidData = [@"This is not valid encrypted data" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *decryptedData = [encrypterA decryptDataWithEncryptedData:invalidData];

    XCTAssertNil(decryptedData, @"Decryption should fail with invalid data");
}

- (void)testThat_encryptionHandlesNilKeyPairScenario
{
    F53OSCEncrypt *encrypter = [[F53OSCEncrypt alloc] init];

    // Generate salt but no key pair.
    [encrypter generateSalt];

    // Create a valid public key from another encrypter.
    F53OSCEncrypt *tempEncrypter = [[F53OSCEncrypt alloc] init];
    XCTAssertNotNil([tempEncrypter generateKeyPair]);

    NSData *validPublicKey = [tempEncrypter publicKeyData];

    // Try to begin encryption without having a key pair. This succeeds but creates invalid state.
    BOOL didBegin = [encrypter beginEncryptingWithPeerKey:validPublicKey];
    XCTAssertTrue(didBegin, @"Should succeed but with invalid state");

    // Now try to encrypt data - this should fail because symmetricKey will be nil.
    NSData *testData = [@"test data" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *encryptedData = [encrypter encryptDataWithClearData:testData];
    XCTAssertNil(encryptedData, @"Encryption should fail with no valid key pair");
}

- (void)testThat_encryptionWithExtremelyLargeData
{
    F53OSCEncrypt *encrypterA = [[F53OSCEncrypt alloc] init];
    F53OSCEncrypt *encrypterB = [[F53OSCEncrypt alloc] init];
    [self setupEncryptionBetweenPeer:encrypterA andPeer:encrypterB];

    // Create very large test data that might stress the encryption.
    NSMutableData *veryLargeData = [NSMutableData dataWithCapacity:1024 * 1024];
    for (int i = 0; i < 1024 * 1024; i++)
    {
        uint8_t byte = (uint8_t)(i % 256);
        [veryLargeData appendBytes:&byte length:1];
    }

    NSData *encryptedData = [encrypterA encryptDataWithClearData:veryLargeData];
    XCTAssertNotNil(encryptedData, @"Should be able to encrypt very large data");

    if (encryptedData)
    {
        NSData *decryptedData = [encrypterB decryptDataWithEncryptedData:encryptedData];
        XCTAssertNotNil(decryptedData, @"Should be able to decrypt very large data");
        XCTAssertEqualObjects(decryptedData, veryLargeData, @"Decrypted data should match original");
    }
}

- (void)testThat_decryptionFailsWithWrongKey
{
    // Setup encryption between A and B.
    F53OSCEncrypt *encrypterA = [[F53OSCEncrypt alloc] init];
    F53OSCEncrypt *encrypterB = [[F53OSCEncrypt alloc] init];
    [self setupEncryptionBetweenPeer:encrypterA andPeer:encrypterB];

    // Setup a third encrypter with different key.
    F53OSCEncrypt *encrypterC = [[F53OSCEncrypt alloc] init];
    XCTAssertNotNil([encrypterC generateKeyPair]);

    encrypterC.salt = encrypterA.salt;
    BOOL didBegin = [encrypterC beginEncryptingWithPeerKey:[encrypterA publicKeyData]];

    XCTAssertTrue(didBegin, @"Encrypter should set up successfully");

    // Encrypt with A.
    NSData *testData = [@"secret message" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *encryptedData = [encrypterA encryptDataWithClearData:testData];

    // Try to decrypt with wrong key (C instead of B).
    NSData *wrongDecryption = [encrypterC decryptDataWithEncryptedData:encryptedData];
    XCTAssertNil(wrongDecryption, @"Decryption should fail with wrong key");

    // Verify B can still decrypt correctly.
    NSData *correctDecryption = [encrypterB decryptDataWithEncryptedData:encryptedData];
    XCTAssertEqualObjects(correctDecryption, testData, @"Correct key should still work");
}


#pragma mark - Binary data encryption tests

- (void)testThat_binaryDataCanBeEncrypted
{
    F53OSCEncrypt *encrypterA = [[F53OSCEncrypt alloc] init];
    F53OSCEncrypt *encrypterB = [[F53OSCEncrypt alloc] init];
    [self setupEncryptionBetweenPeer:encrypterA andPeer:encrypterB];

    // Create binary test data.
    NSMutableData *binaryData = [NSMutableData dataWithCapacity:256];
    for (int i = 0; i < 256; i++)
    {
        uint8_t byte = (uint8_t)i;
        [binaryData appendBytes:&byte length:1];
    }

    // Encrypt and decrypt.
    NSData *encryptedData = [encrypterA encryptDataWithClearData:binaryData];
    NSData *decryptedData = [encrypterB decryptDataWithEncryptedData:encryptedData];

    XCTAssertNotNil(encryptedData, @"Binary data should encrypt successfully");
    XCTAssertNotNil(decryptedData, @"Binary data should decrypt successfully");
    XCTAssertEqualObjects(decryptedData, binaryData, @"Decrypted binary data should match original");
}

- (void)testThat_emptyDataCanBeEncrypted
{
    F53OSCEncrypt *encrypterA = [[F53OSCEncrypt alloc] init];
    F53OSCEncrypt *encrypterB = [[F53OSCEncrypt alloc] init];
    [self setupEncryptionBetweenPeer:encrypterA andPeer:encrypterB];

    NSData *emptyData = [NSData data];

    NSData *encryptedData = [encrypterA encryptDataWithClearData:emptyData];
    NSData *decryptedData = [encrypterB decryptDataWithEncryptedData:encryptedData];

    XCTAssertNotNil(encryptedData, @"Empty data should encrypt successfully");
    XCTAssertNotNil(decryptedData, @"Empty data should decrypt successfully");
    XCTAssertEqualObjects(decryptedData, emptyData, @"Decrypted empty data should match original");
    XCTAssertEqual(decryptedData.length, 0, @"Decrypted data should still be empty");
}

- (void)testThat_largeDataCanBeEncrypted
{
    F53OSCEncrypt *encrypterA = [[F53OSCEncrypt alloc] init];
    F53OSCEncrypt *encrypterB = [[F53OSCEncrypt alloc] init];
    [self setupEncryptionBetweenPeer:encrypterA andPeer:encrypterB];

    // Create large test data (64KB).
    NSMutableData *largeData = [NSMutableData dataWithCapacity:65536];
    for (int i = 0; i < 65536; i++)
    {
        uint8_t byte = (uint8_t)(i % 256);
        [largeData appendBytes:&byte length:1];
    }

    NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];

    NSData *encryptedData = [encrypterA encryptDataWithClearData:largeData];
    NSData *decryptedData = [encrypterB decryptDataWithEncryptedData:encryptedData];

    NSTimeInterval elapsed = [NSDate timeIntervalSinceReferenceDate] - startTime;

    XCTAssertNotNil(encryptedData, @"Large data should encrypt successfully");
    XCTAssertNotNil(decryptedData, @"Large data should decrypt successfully");
    XCTAssertEqualObjects(decryptedData, largeData, @"Decrypted large data should match original");
    XCTAssertLessThan(elapsed, 1.0, @"Large data encryption should complete in reasonable time");

    NSLog(@"Encrypted/decrypted %lu bytes in %.3f seconds", (unsigned long)largeData.length, elapsed);
}


#pragma mark - Handshake tests

- (void)testThat_handshakeHasCorrectDefaults
{
    F53OSCEncrypt *encrypter = [[F53OSCEncrypt alloc] init];

    XCTAssertNotNil([encrypter generateKeyPair]);

    F53OSCEncryptHandshake *handshake = [F53OSCEncryptHandshake handshakeWithEncrypter:encrypter];

    XCTAssertNotNil(handshake, @"Handshake should not be nil");
    XCTAssertFalse(handshake.handshakeComplete, @"Default handshakeComplete should be NO");
    XCTAssertNil(handshake.peerKey, @"Default peerKey should be nil");
    XCTAssertEqual(handshake.lastProcessedMessage, F53OSCEncryptionHandshakeMessageNone, @"Default lastProcessedMessage should be .None");
}

- (void)testThat_handshakeCanGenerateAndHandleMessages
{
    F53OSCEncrypt *encrypter = [[F53OSCEncrypt alloc] init];

    XCTAssertNotNil([encrypter generateKeyPair]);
    [encrypter generateSalt];

    NSData *initialSalt = encrypter.salt;

    F53OSCEncryptHandshake *handshake = [F53OSCEncryptHandshake handshakeWithEncrypter:encrypter];

    // Test request message.
    F53OSCMessage *requestMessage = [handshake requestEncryptionMessage];
    XCTAssertNotNil(requestMessage, @"Should generate request message");
    XCTAssertTrue([F53OSCEncryptHandshake isEncryptHandshakeMessage:requestMessage], @"Should be identified as handshake message");
    XCTAssertEqual(requestMessage.arguments.count, 2, @"Handshake request message should have 2 arguments");
    XCTAssertTrue([requestMessage.arguments[0] isKindOfClass:[NSNumber class]], @"Handshake request message has invalid argument");
    XCTAssertEqual([requestMessage.arguments[0] intValue], [F53OSCEncryptHandshake protocolVersion], @"Handshake request message has invalid protocol version");
    XCTAssertTrue([requestMessage.arguments[1] isKindOfClass:[NSData class]], @"Handshake request message has invalid argument");
    XCTAssertTrue([handshake processHandshakeMessage:requestMessage], @"Should process request message");
    XCTAssertFalse(handshake.handshakeComplete, @"Handshake should not be complete");
    XCTAssertEqual(handshake.lastProcessedMessage, F53OSCEncryptionHandshakeMessageRequest, @"Handshake lastProcessedMessage should be .Request");

    // Test approve message.
    F53OSCMessage *approveMessage = [handshake approveEncryptionMessage];
    XCTAssertNotNil(approveMessage, @"Should generate approve message");
    XCTAssertTrue([F53OSCEncryptHandshake isEncryptHandshakeMessage:approveMessage], @"Should be identified as handshake message");
    XCTAssertEqual(approveMessage.arguments.count, 3, @"Handshake approve message should have 3 arguments");
    XCTAssertTrue([approveMessage.arguments[0] isKindOfClass:[NSNumber class]], @"Handshake approve message has invalid argument");
    XCTAssertEqual([approveMessage.arguments[0] intValue], [F53OSCEncryptHandshake protocolVersion], @"Handshake approve message has invalid protocol version");
    XCTAssertTrue([approveMessage.arguments[1] isKindOfClass:[NSData class]], @"Handshake approve message has invalid argument");
    XCTAssertTrue([approveMessage.arguments[2] isKindOfClass:[NSData class]], @"Handshake approve message has invalid argument");
    XCTAssertTrue([handshake processHandshakeMessage:approveMessage], @"Should process approve message");
    XCTAssertNotEqualObjects(encrypter.salt, initialSalt, @"Encrypter salt should change after processing approve message");
    XCTAssertFalse(handshake.handshakeComplete, @"Handshake should not be complete");
    XCTAssertEqual(handshake.lastProcessedMessage, F53OSCEncryptionHandshakeMessageApprove, @"Handshake lastProcessedMessage should be .Approve");

    // Test begin message.
    F53OSCMessage *beginMessage = [handshake beginEncryptionMessage];
    XCTAssertNotNil(beginMessage, @"Should generate begin message");
    XCTAssertTrue([F53OSCEncryptHandshake isEncryptHandshakeMessage:beginMessage], @"Should be identified as handshake message");
    XCTAssertEqual(beginMessage.arguments.count, 1, @"Handshake begin message should have 1 argument");
    XCTAssertTrue([beginMessage.arguments[0] isKindOfClass:[NSNumber class]], @"Handshake begin message has invalid argument");
    XCTAssertEqual([beginMessage.arguments[0] intValue], [F53OSCEncryptHandshake protocolVersion], @"Handshake begin message has invalid protocol version");
    XCTAssertTrue([handshake processHandshakeMessage:beginMessage], @"Should process begin message");
    XCTAssertTrue(handshake.handshakeComplete, @"Handshake should be complete");
    XCTAssertEqual(handshake.lastProcessedMessage, F53OSCEncryptionHandshakeMessageBegin, @"Handshake lastProcessedMessage should be .Begin");
}

- (void)testThat_processHandshakeMessageHandlesVariousHandshakeStates
{
    F53OSCEncrypt *encrypterA = [[F53OSCEncrypt alloc] init];
    F53OSCEncrypt *encrypterB = [[F53OSCEncrypt alloc] init];
    [self setupEncryptionBetweenPeer:encrypterA andPeer:encrypterB];

    F53OSCEncryptHandshake *handshakeA = [F53OSCEncryptHandshake handshakeWithEncrypter:encrypterA];
    F53OSCEncryptHandshake *handshakeB = [F53OSCEncryptHandshake handshakeWithEncrypter:encrypterB];

    // Simulate a full handshake sequence to test different states

    // handshakeA creates request
    F53OSCMessage *requestMessage = [handshakeA requestEncryptionMessage];
    XCTAssertNotNil(requestMessage, @"Handshake A should create request message");
    XCTAssertFalse(handshakeA.handshakeComplete, @"Handshake A should not be complete");
    XCTAssertFalse(handshakeB.handshakeComplete, @"Handshake B should not be complete");
    XCTAssertEqual(handshakeA.lastProcessedMessage, F53OSCEncryptionHandshakeMessageNone, @"Handshake A lastProcessedMessage should be .None");
    XCTAssertEqual(handshakeB.lastProcessedMessage, F53OSCEncryptionHandshakeMessageNone, @"Handshake B lastProcessedMessage should be .None");

    // handshakeB processes request and creates approve
    XCTAssertTrue([handshakeB processHandshakeMessage:requestMessage], @"Handshake B should process request message");
    F53OSCMessage *approveMessage = [handshakeB approveEncryptionMessage];
    XCTAssertNotNil(approveMessage, @"Handshake B should create approve message");
    XCTAssertFalse(handshakeA.handshakeComplete, @"Handshake A should not be complete");
    XCTAssertFalse(handshakeB.handshakeComplete, @"Handshake B should not be complete");
    XCTAssertEqual(handshakeA.lastProcessedMessage, F53OSCEncryptionHandshakeMessageNone, @"Handshake A lastProcessedMessage should still be .None");
    XCTAssertEqual(handshakeB.lastProcessedMessage, F53OSCEncryptionHandshakeMessageRequest, @"Handshake B lastProcessedMessage should be .Request");

    // handshakeA processes approve and creates begin
    XCTAssertTrue([handshakeA processHandshakeMessage:approveMessage], @"Handshake A should process approve message");
    F53OSCMessage *beginMessage = [handshakeA beginEncryptionMessage];
    XCTAssertNotNil(beginMessage, @"Handshake A should create begin message");
    XCTAssertFalse(handshakeA.handshakeComplete, @"Handshake A should not be complete");
    XCTAssertFalse(handshakeB.handshakeComplete, @"Handshake B should not be complete");
    XCTAssertEqual(handshakeA.lastProcessedMessage, F53OSCEncryptionHandshakeMessageApprove, @"Handshake A lastProcessedMessage should be .Approve");
    XCTAssertEqual(handshakeB.lastProcessedMessage, F53OSCEncryptionHandshakeMessageRequest, @"Handshake B lastProcessedMessage should still be .Request");

    // handshakeB processes begin
    XCTAssertTrue([handshakeB processHandshakeMessage:beginMessage], @"Should process begin message");
    XCTAssertFalse(handshakeA.handshakeComplete, @"Handshake A should not be complete");
    XCTAssertTrue(handshakeB.handshakeComplete, @"Handshake B should be complete");
    XCTAssertEqual(handshakeA.lastProcessedMessage, F53OSCEncryptionHandshakeMessageApprove, @"Handshake A lastProcessedMessage should be .Approve");
    XCTAssertEqual(handshakeB.lastProcessedMessage, F53OSCEncryptionHandshakeMessageBegin, @"Handshake B lastProcessedMessage should still be .Begin");
}

- (void)testThat_handshakeCannotGenerateRequestMessagesWithoutPublicKeyData
{
    F53OSCEncrypt *encrypter = [[F53OSCEncrypt alloc] init];

    // Generate salt but no key pair.
    [encrypter generateSalt];

    F53OSCEncryptHandshake *handshake = [F53OSCEncryptHandshake handshakeWithEncrypter:encrypter];

    XCTAssertNil(encrypter.publicKeyData, @"Encrypter publicKeyData should be nil");
    XCTAssertNotNil(encrypter.salt, @"Encrypter salt should not be nil");

    F53OSCMessage *requestMessage = [handshake requestEncryptionMessage];
    XCTAssertNil(requestMessage, @"Should not generate request message without publicKeyData");
    XCTAssertFalse([F53OSCEncryptHandshake isEncryptHandshakeMessage:requestMessage], @"Nil should not be identified as handshake message");
    XCTAssertFalse(handshake.handshakeComplete, @"Handshake should not be complete");
    XCTAssertEqual(handshake.lastProcessedMessage, F53OSCEncryptionHandshakeMessageNone, @"Handshake lastProcessedMessage should be .None");
}

- (void)testThat_handshakeCanGenerateRequestMessagesWithoutSalt
{
    F53OSCEncrypt *encrypter = [[F53OSCEncrypt alloc] init];

    // Generate key pair but no salt.
    XCTAssertNotNil([encrypter generateKeyPair]);

    F53OSCEncryptHandshake *handshake = [F53OSCEncryptHandshake handshakeWithEncrypter:encrypter];

    XCTAssertNotNil(encrypter.publicKeyData, @"Encrypter publicKeyData should not be nil");
    XCTAssertNil(encrypter.salt, @"Encrypter salt should be nil");

    F53OSCMessage *requestMessage = [handshake requestEncryptionMessage];
    XCTAssertNotNil(requestMessage, @"Should generate request message");
    XCTAssertTrue([F53OSCEncryptHandshake isEncryptHandshakeMessage:requestMessage], @"Nil should not be identified as handshake message");
    XCTAssertFalse(handshake.handshakeComplete, @"Handshake should not be complete");
    XCTAssertEqual(handshake.lastProcessedMessage, F53OSCEncryptionHandshakeMessageNone, @"Handshake lastProcessedMessage should be .None");
}

- (void)testThat_handshakeDoesNotProcessInvalidRequestMessages
{
    F53OSCEncrypt *encrypter = [[F53OSCEncrypt alloc] init];

    XCTAssertNotNil([encrypter generateKeyPair]);
    [encrypter generateSalt];

    F53OSCEncryptHandshake *handshake = [F53OSCEncryptHandshake handshakeWithEncrypter:encrypter];

    XCTAssertNotNil(encrypter.publicKeyData, @"Encrypter publicKeyData should not be nil");
    XCTAssertNotNil(encrypter.salt, @"Encrypter salt should not be nil");

    F53OSCMessage *requestMessage = [handshake requestEncryptionMessage];
    XCTAssertNotNil(requestMessage, @"Should generate request message");
    XCTAssertTrue([F53OSCEncryptHandshake isEncryptHandshakeMessage:requestMessage], @"Nil should not be identified as handshake message");
    XCTAssertFalse(handshake.handshakeComplete, @"Handshake should not be complete");
    XCTAssertEqual(handshake.lastProcessedMessage, F53OSCEncryptionHandshakeMessageNone, @"Handshake lastProcessedMessage should be .None");

    NSArray<id> *validArguments = requestMessage.arguments;

    requestMessage.arguments = @[validArguments[0]];
    XCTAssertFalse([handshake processHandshakeMessage:requestMessage], @"Should not process request message without 2 arguments");
    XCTAssertFalse(handshake.handshakeComplete, @"Handshake should not be complete");
    XCTAssertEqual(handshake.lastProcessedMessage, F53OSCEncryptionHandshakeMessageNone, @"Handshake lastProcessedMessage should be .None");

    requestMessage.arguments = @[validArguments[0], @"invalid_peer_key_data_string"];
    XCTAssertFalse([handshake processHandshakeMessage:requestMessage], @"Should not process request message with invalid publicKeyData argument");
    XCTAssertFalse(handshake.handshakeComplete, @"Handshake should not be complete");
    XCTAssertEqual(handshake.lastProcessedMessage, F53OSCEncryptionHandshakeMessageNone, @"Handshake lastProcessedMessage should be .None");

    NSData *invalidPeerKey = [@"invalid_peer_key_data" dataUsingEncoding:NSUTF8StringEncoding];
    requestMessage.arguments = @[validArguments[0], invalidPeerKey];
    XCTAssertFalse([handshake processHandshakeMessage:requestMessage], @"Should not process request message with invalid publicKeyData argument");
    XCTAssertFalse(handshake.handshakeComplete, @"Handshake should not be complete");
    XCTAssertEqual(handshake.lastProcessedMessage, F53OSCEncryptionHandshakeMessageNone, @"Handshake lastProcessedMessage should be .None");

    requestMessage.arguments = @[@([F53OSCEncryptHandshake protocolVersion] + 1), validArguments[1]];
    XCTAssertTrue([handshake processHandshakeMessage:requestMessage], @"Should still process request message even with invalid protocol version");
    XCTAssertFalse(handshake.handshakeComplete, @"Handshake should not be complete");
    XCTAssertEqual(handshake.lastProcessedMessage, F53OSCEncryptionHandshakeMessageRequest, @"Handshake lastProcessedMessage should be .Request");
}

- (void)testThat_handshakeCannotGenerateApproveMessagesWithoutPublicKeyData
{
    F53OSCEncrypt *encrypter = [[F53OSCEncrypt alloc] init];

    // Generate salt but no key pair.
    [encrypter generateSalt];

    F53OSCEncryptHandshake *handshake = [F53OSCEncryptHandshake handshakeWithEncrypter:encrypter];

    XCTAssertNil(encrypter.publicKeyData, @"Encrypter publicKeyData should be nil");
    XCTAssertNotNil(encrypter.salt, @"Encrypter salt should not be nil");

    F53OSCMessage *approveMessage = [handshake approveEncryptionMessage];
    XCTAssertNil(approveMessage, @"Should not generate approve message without publicKeyData");
    XCTAssertFalse([F53OSCEncryptHandshake isEncryptHandshakeMessage:approveMessage], @"Nil should not be identified as handshake message");
    XCTAssertFalse(handshake.handshakeComplete, @"Handshake should not be complete");
    XCTAssertEqual(handshake.lastProcessedMessage, F53OSCEncryptionHandshakeMessageNone, @"Handshake lastProcessedMessage should be .None");
}

- (void)testThat_handshakeCannotGenerateApproveMessagesWithoutSalt
{
    F53OSCEncrypt *encrypter = [[F53OSCEncrypt alloc] init];

    // Generate key pair but no salt.
    XCTAssertNotNil([encrypter generateKeyPair]);

    F53OSCEncryptHandshake *handshake = [F53OSCEncryptHandshake handshakeWithEncrypter:encrypter];

    XCTAssertNotNil(encrypter.publicKeyData, @"Encrypter publicKeyData should not be nil");
    XCTAssertNil(encrypter.salt, @"Encrypter salt should be nil");

    F53OSCMessage *approveMessage = [handshake approveEncryptionMessage];
    XCTAssertNil(approveMessage, @"Should not generate approve message without salt");
    XCTAssertFalse([F53OSCEncryptHandshake isEncryptHandshakeMessage:approveMessage], @"Nil should not be identified as handshake message");
    XCTAssertFalse(handshake.handshakeComplete, @"Handshake should not be complete");
    XCTAssertEqual(handshake.lastProcessedMessage, F53OSCEncryptionHandshakeMessageNone, @"Handshake lastProcessedMessage should be .None");
}

- (void)testThat_handshakeCannotGenerateApproveMessagesWithoutPublicKeyDataOrSalt
{
    F53OSCEncrypt *encrypter = [[F53OSCEncrypt alloc] init];

    // Generate neither salt nor key pair.

    F53OSCEncryptHandshake *handshake = [F53OSCEncryptHandshake handshakeWithEncrypter:encrypter];

    XCTAssertNil(encrypter.publicKeyData, @"Encrypter publicKeyData should be nil");
    XCTAssertNil(encrypter.salt, @"Encrypter salt should be nil.");

    F53OSCMessage *approveMessage = [handshake approveEncryptionMessage];
    XCTAssertNil(approveMessage, @"Should not generate approve message without publicKeyData and salt");
    XCTAssertFalse([F53OSCEncryptHandshake isEncryptHandshakeMessage:approveMessage], @"Nil should not be identified as handshake message");
    XCTAssertFalse(handshake.handshakeComplete, @"Handshake should not be complete");
    XCTAssertEqual(handshake.lastProcessedMessage, F53OSCEncryptionHandshakeMessageNone, @"Handshake lastProcessedMessage should be .None");
}

- (void)testThat_handshakeDoesNotProcessInvalidApproveMessages
{
    F53OSCEncrypt *encrypter = [[F53OSCEncrypt alloc] init];

    XCTAssertNotNil([encrypter generateKeyPair]);
    [encrypter generateSalt];

    F53OSCEncryptHandshake *handshake = [F53OSCEncryptHandshake handshakeWithEncrypter:encrypter];

    XCTAssertNotNil(encrypter.publicKeyData, @"Encrypter publicKeyData should not be nil");
    XCTAssertNotNil(encrypter.salt, @"Encrypter salt should not be nil");

    F53OSCMessage *approveMessage = [handshake approveEncryptionMessage];
    XCTAssertNotNil(approveMessage, @"Should generate approve message");
    XCTAssertTrue([F53OSCEncryptHandshake isEncryptHandshakeMessage:approveMessage], @"Nil should not be identified as handshake message");
    XCTAssertFalse(handshake.handshakeComplete, @"Handshake should not be complete");
    XCTAssertEqual(handshake.lastProcessedMessage, F53OSCEncryptionHandshakeMessageNone, @"Handshake lastProcessedMessage should be .None");

    NSArray<id> *validArguments = approveMessage.arguments;

    approveMessage.arguments = @[validArguments[0], validArguments[1]];
    XCTAssertFalse([handshake processHandshakeMessage:approveMessage], @"Should not process approve message without 3 arguments");
    XCTAssertFalse(handshake.handshakeComplete, @"Handshake should not be complete");
    XCTAssertEqual(handshake.lastProcessedMessage, F53OSCEncryptionHandshakeMessageNone, @"Handshake lastProcessedMessage should be .None");

    approveMessage.arguments = @[validArguments[0], @"invalid_peer_key_data_string", validArguments[2]];
    XCTAssertFalse([handshake processHandshakeMessage:approveMessage], @"Should not process approve message with invalid publicKeyData argument");
    XCTAssertFalse(handshake.handshakeComplete, @"Handshake should not be complete");
    XCTAssertEqual(handshake.lastProcessedMessage, F53OSCEncryptionHandshakeMessageNone, @"Handshake lastProcessedMessage should be .None");

    approveMessage.arguments = @[validArguments[0], validArguments[1], @"invalid_salt_data_string"];
    XCTAssertFalse([handshake processHandshakeMessage:approveMessage], @"Should not process approve message with invalid salt argument");
    XCTAssertFalse(handshake.handshakeComplete, @"Handshake should not be complete");
    XCTAssertEqual(handshake.lastProcessedMessage, F53OSCEncryptionHandshakeMessageNone, @"Handshake lastProcessedMessage should be .None");

    NSData *invalidPeerKey = [@"invalid_peer_key_data" dataUsingEncoding:NSUTF8StringEncoding];
    approveMessage.arguments = @[validArguments[0], invalidPeerKey, validArguments[2]];
    XCTAssertFalse([handshake processHandshakeMessage:approveMessage], @"Should not process approve message with invalid publicKeyData argument");
    XCTAssertFalse(handshake.handshakeComplete, @"Handshake should not be complete");
    XCTAssertEqual(handshake.lastProcessedMessage, F53OSCEncryptionHandshakeMessageNone, @"Handshake lastProcessedMessage should be .None");

    approveMessage.arguments = @[@([F53OSCEncryptHandshake protocolVersion] + 1), validArguments[1], validArguments[2]];
    XCTAssertTrue([handshake processHandshakeMessage:approveMessage], @"Should still process approve message even with invalid protocol version");
    XCTAssertFalse(handshake.handshakeComplete, @"Handshake should not be complete");
    XCTAssertEqual(handshake.lastProcessedMessage, F53OSCEncryptionHandshakeMessageApprove, @"Handshake lastProcessedMessage should be .Approve");
}

- (void)testThat_handshakeCanGenerateBeginMessagesWithoutPublicKeyDataOrSalt
{
    F53OSCEncrypt *encrypter = [[F53OSCEncrypt alloc] init];

    F53OSCEncryptHandshake *handshake = [F53OSCEncryptHandshake handshakeWithEncrypter:encrypter];

    XCTAssertNil(encrypter.publicKeyData, @"Encrypter publicKeyData should be nil");
    XCTAssertNil(encrypter.salt, @"Encrypter salt should be nil");

    F53OSCMessage *beginMessage = [handshake beginEncryptionMessage];
    XCTAssertNotNil(beginMessage, @"Should generate begin message without publicKeyData or salt");
    XCTAssertTrue([F53OSCEncryptHandshake isEncryptHandshakeMessage:beginMessage], @"Should be identified as handshake message");
    XCTAssertFalse(handshake.handshakeComplete, @"Handshake should not be complete");
    XCTAssertEqual(handshake.lastProcessedMessage, F53OSCEncryptionHandshakeMessageNone, @"Handshake lastProcessedMessage should be .None");
}

- (void)testThat_handshakeDoesNotProcessInvalidBeginMessages
{
    F53OSCEncrypt *encrypter = [[F53OSCEncrypt alloc] init];

    XCTAssertNotNil([encrypter generateKeyPair]);
    [encrypter generateSalt];

    F53OSCEncryptHandshake *handshake = [F53OSCEncryptHandshake handshakeWithEncrypter:encrypter];

    XCTAssertNotNil(encrypter.publicKeyData, @"Encrypter publicKeyData should not be nil");
    XCTAssertNotNil(encrypter.salt, @"Encrypter salt should not be nil");

    F53OSCMessage *beginMessage = [handshake beginEncryptionMessage];
    XCTAssertNotNil(beginMessage, @"Should generate begin message");
    XCTAssertTrue([F53OSCEncryptHandshake isEncryptHandshakeMessage:beginMessage], @"Nil should not be identified as handshake message");
    XCTAssertFalse(handshake.handshakeComplete, @"Handshake should not be complete");
    XCTAssertEqual(handshake.lastProcessedMessage, F53OSCEncryptionHandshakeMessageNone, @"Handshake lastProcessedMessage should be .None");

    beginMessage.arguments = @[];
    XCTAssertFalse([handshake processHandshakeMessage:beginMessage], @"Should not process begin message without 1 argument");
    XCTAssertFalse(handshake.handshakeComplete, @"Handshake should not be complete");
    XCTAssertEqual(handshake.lastProcessedMessage, F53OSCEncryptionHandshakeMessageNone, @"Handshake lastProcessedMessage should be .None");

    beginMessage.arguments = @[@([F53OSCEncryptHandshake protocolVersion] + 1)];
    XCTAssertTrue([handshake processHandshakeMessage:beginMessage], @"Should not process begin message with invalid protocol version");
    XCTAssertTrue(handshake.handshakeComplete, @"Handshake should be complete");
    XCTAssertEqual(handshake.lastProcessedMessage, F53OSCEncryptionHandshakeMessageBegin, @"Handshake lastProcessedMessage should be .Begin");
}

- (void)testThat_handshakeCanIdentifyHandshakeMessages
{
    F53OSCEncrypt *encrypter = [[F53OSCEncrypt alloc] init];

    XCTAssertNotNil([encrypter generateKeyPair]);
    [encrypter generateSalt];

    F53OSCEncryptHandshake *handshake = [F53OSCEncryptHandshake handshakeWithEncrypter:encrypter];

    // Test with handshake message.
    F53OSCMessage *handshakeMessage = [handshake requestEncryptionMessage];
    BOOL isHandshakeMessage = [F53OSCEncryptHandshake isEncryptHandshakeMessage:handshakeMessage];
    XCTAssertTrue(isHandshakeMessage, @"Should identify handshake message correctly");

    // Test with regular OSC message.
    F53OSCMessage *regularMessage = [F53OSCMessage messageWithAddressPattern:@"/test/message" arguments:@[@"hello"]];
    BOOL isRegularMessage = [F53OSCEncryptHandshake isEncryptHandshakeMessage:regularMessage];
    XCTAssertFalse(isRegularMessage, @"Should not identify regular message as handshake");
}


#pragma mark - Performance tests

- (void)testThat_encryptionPerformanceIsReasonable
{
    F53OSCEncrypt *encrypterA = [[F53OSCEncrypt alloc] init];
    F53OSCEncrypt *encrypterB = [[F53OSCEncrypt alloc] init];
    [self setupEncryptionBetweenPeer:encrypterA andPeer:encrypterB];

    // Test encryption performance with moderate-sized data.
    NSString *testString = @"This is a test message for performance measurement. ";
    NSMutableString *largerString = [NSMutableString stringWithCapacity:1000];
    for (int i = 0; i < 20; i++)
        [largerString appendString:testString];
    NSData *testData = [largerString dataUsingEncoding:NSUTF8StringEncoding];

    NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];

    int iterations = 100;
    for (int i = 0; i < iterations; i++)
    {
        NSData *encrypted = [encrypterA encryptDataWithClearData:testData];
        NSData *decrypted = [encrypterB decryptDataWithEncryptedData:encrypted];

        XCTAssertNotNil(encrypted, @"Encryption should succeed in performance test");
        XCTAssertNotNil(decrypted, @"Decryption should succeed in performance test");
        XCTAssertEqualObjects(decrypted, testData, @"Data should match in performance test");
    }

    NSTimeInterval elapsed = [NSDate timeIntervalSinceReferenceDate] - startTime;
    double operationsPerSecond = (iterations * 2) / elapsed; // 2 operations per iteration (encrypt + decrypt)

    NSLog(@"Encryption performance: %.0f operations/second (%.3f seconds for %lu encrypt/decrypt cycles)",
          operationsPerSecond, elapsed, (unsigned long)iterations);

    XCTAssertGreaterThan(operationsPerSecond, 100.0, @"Should maintain reasonable encryption performance");
}

- (void)testThat_keyGenerationPerformanceIsReasonable
{
    NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];

    int iterations = 10;
    for (int i = 0; i < iterations; i++)
    {
        F53OSCEncrypt *encrypter = [[F53OSCEncrypt alloc] init];
        NSData *keyPair = [encrypter generateKeyPair];
        XCTAssertNotNil(keyPair, @"Key generation should succeed");
    }

    NSTimeInterval elapsed = [NSDate timeIntervalSinceReferenceDate] - startTime;
    double keysPerSecond = iterations / elapsed;

    NSLog(@"Key generation performance: %.1f keys/second", keysPerSecond);

    XCTAssertGreaterThan(keysPerSecond, 1.0, @"Should generate at least 1 key pair per second");
}

- (void)testThat_encryptDataHandlesExtremeMemoryPressure
{
    F53OSCEncrypt *encrypterA = [[F53OSCEncrypt alloc] init];
    F53OSCEncrypt *encrypterB = [[F53OSCEncrypt alloc] init];
    [self setupEncryptionBetweenPeer:encrypterA andPeer:encrypterB];

    // Try multiple approaches to trigger the `catch` block in F53OSCEncrypt `encryptData(clearData:)`.

    // Approach 1: Try extremely large data
    // NOTE: This may not work on all systems, but attempts to exercise the error path.
    NSData *result = nil;
    @try
    {
        // Create data that is larger than reasonable memory limits for encryption.
        // Start with a very large size that might cause memory pressure.
        for (NSUInteger size = 1024 * 1024 * 1024; size >= 64 * 1024 * 1024; size /= 2)
        {
            @autoreleasepool {
                NSMutableData *largeData = [NSMutableData dataWithLength:size];
                if (largeData)
                {
                    // Try to encrypt it.
                    result = [encrypterA encryptDataWithClearData:largeData];
                    if (!result)
                    {
                        // Encryption failed - this might have triggered the catch block.
                        NSLog(@"Encryption failed with %lu MB data - catch block likely triggered", size / (1024 * 1024));
                        break;
                    }
                    else
                    {
                        NSLog(@"Successfully encrypted %lu MB data", size / (1024 * 1024));
                    }

                    // Clear the result to free memory.
                    result = nil;
                }
                else
                {
                    NSLog(@"Could not allocate %lu MB for test", size / (1024 * 1024));
                }
            }
        }
    }
    @catch (NSException *exception)
    {
        NSLog(@"Exception during large data test: %@", exception);
    }

    // Approach 2: Multiple concurrent encryption attempts to stress memory
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    int iterations = 10;
    for (int i = 0; i < iterations; i++)
    {
        dispatch_group_async(group, queue, ^{
            @autoreleasepool {
                NSMutableData *testData = [NSMutableData dataWithLength:50 * 1024 * 1024]; // 50MB each
                if (testData)
                {
                    NSData *encrypted = [encrypterA encryptDataWithClearData:testData];
                    if (!encrypted)
                        NSLog(@"Concurrent encryption failed - catch block likely triggered");
                }
            }
        });
    }

    dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC));

    // The goal is to attempt various scenarios that might trigger ChaChaPoly.seal to throw.
    // While we can't guarantee the catch block will be hit, these tests exercise
    // the encryption under stress conditions that are more likely to cause failures.
}


#pragma mark - processHandshakeMessage tests

- (void)testThat_processHandshakeMessageHandlesNilMessage
{
    F53OSCEncrypt *encrypter = [[F53OSCEncrypt alloc] init];
    F53OSCEncryptHandshake *handshake = [F53OSCEncryptHandshake handshakeWithEncrypter:encrypter];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertFalse([handshake processHandshakeMessage:nil], @"Should handle nil message gracefully");
#pragma clang diagnostic pop
    XCTAssertFalse(handshake.handshakeComplete, @"Handshake should not be complete");
    XCTAssertEqual(handshake.lastProcessedMessage, F53OSCEncryptionHandshakeMessageNone, @"Handshake lastProcessedMessage should be .None");
}

- (void)testThat_processHandshakeMessageHandlesNonHandshakeMessage
{
    F53OSCEncrypt *encrypter = [[F53OSCEncrypt alloc] init];
    F53OSCEncryptHandshake *handshake = [F53OSCEncryptHandshake handshakeWithEncrypter:encrypter];

    // Non-handshake message
    F53OSCMessage *regularMessage = [F53OSCMessage messageWithAddressPattern:@"/regular/message" arguments:@[@"not_handshake"]];

    XCTAssertFalse([handshake processHandshakeMessage:regularMessage], @"Should handle non-handshake message gracefully");
    XCTAssertFalse(handshake.handshakeComplete, @"Handshake should not be complete");
    XCTAssertEqual(handshake.lastProcessedMessage, F53OSCEncryptionHandshakeMessageNone, @"Handshake lastProcessedMessage should be .None");
}

- (void)testThat_processHandshakeMessageHandlesMalformedHandshakeMessage
{
    F53OSCEncrypt *encrypter = [[F53OSCEncrypt alloc] init];
    F53OSCEncryptHandshake *handshake = [F53OSCEncryptHandshake handshakeWithEncrypter:encrypter];

    // Malformed handshake message with wrong arguments
    F53OSCMessage *malformedMessage = [F53OSCMessage messageWithAddressPattern:@"!/encrypt/request" arguments:@[@"wrong_args", @123]];

    XCTAssertFalse([handshake processHandshakeMessage:malformedMessage], @"Should handle malformed handshake message gracefully");
    XCTAssertFalse(handshake.handshakeComplete, @"Handshake should not be complete");
    XCTAssertEqual(handshake.lastProcessedMessage, F53OSCEncryptionHandshakeMessageNone, @"Handshake lastProcessedMessage should be .None");
}

- (void)testThat_processHandshakeMessageHandlesInvalidArguments
{
    F53OSCEncrypt *encrypter = [[F53OSCEncrypt alloc] init];
    F53OSCEncryptHandshake *handshake = [F53OSCEncryptHandshake handshakeWithEncrypter:encrypter];

    // Test handshake message with no arguments
    F53OSCMessage *noArgsMessage = [F53OSCMessage messageWithAddressPattern:@"!/encrypt/approve" arguments:@[]];
    XCTAssertFalse([handshake processHandshakeMessage:noArgsMessage], @"Should handle message with no arguments gracefully");
    XCTAssertFalse(handshake.handshakeComplete, @"Handshake should not be complete");
    XCTAssertEqual(handshake.lastProcessedMessage, F53OSCEncryptionHandshakeMessageNone, @"Handshake lastProcessedMessage should be .None");

    // Test handshake message with nil arguments
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    F53OSCMessage *nilArgsMessage = [F53OSCMessage messageWithAddressPattern:@"!/encrypt/begin" arguments:nil];
#pragma clang diagnostic pop
    XCTAssertFalse([handshake processHandshakeMessage:nilArgsMessage], @"Should handle message with nil arguments gracefully");
    XCTAssertFalse(handshake.handshakeComplete, @"Handshake should not be complete");
    XCTAssertEqual(handshake.lastProcessedMessage, F53OSCEncryptionHandshakeMessageNone, @"Handshake lastProcessedMessage should be .None");
}

- (void)testThat_processHandshakeMessageHandlesInvalidMessageTypes
{
    F53OSCEncrypt *encrypter = [[F53OSCEncrypt alloc] init];
    F53OSCEncryptHandshake *handshake = [F53OSCEncryptHandshake handshakeWithEncrypter:encrypter];

    // Test with various invalid handshake message types
    NSArray *invalidAddresses = @[
        @"!/encrypt/invalid",
        @"!/encrypt/",
        @"!/encrypt",
        @"!/wrong/request",
        @"!/encrypt/REQUEST", // wrong case
        @"!/encrypt/request/extra"
    ];

    for (NSString *address in invalidAddresses)
    {
        F53OSCMessage *invalidMessage = [F53OSCMessage messageWithAddressPattern:address arguments:@[@"test"]];
        XCTAssertFalse([handshake processHandshakeMessage:invalidMessage], @"Should handle invalid address '%@' gracefully", address);
        XCTAssertFalse(handshake.handshakeComplete, @"Handshake should not be complete");
        XCTAssertEqual(handshake.lastProcessedMessage, F53OSCEncryptionHandshakeMessageNone, @"Handshake lastProcessedMessage should be .None");
    }
}

- (void)testThat_processHandshakeMessageHandlesInvalidDataFormats
{
    F53OSCEncrypt *encrypter = [[F53OSCEncrypt alloc] init];
    F53OSCEncryptHandshake *handshake = [F53OSCEncryptHandshake handshakeWithEncrypter:encrypter];

    // Test with invalid data types in arguments
    NSArray *invalidArguments = @[
        @[@123], // number instead of expected data
        @[@"string"], // string instead of expected data
        @[[[NSObject alloc] init]], // arbitrary object
        @[[NSNull null]], // null value
        @[@123, @"mixed", [NSData data]] // mixed types
    ];

    for (NSArray *args in invalidArguments)
    {
        F53OSCMessage *invalidMessage = [F53OSCMessage messageWithAddressPattern:@"!/encrypt/request" arguments:args];
        XCTAssertFalse([handshake processHandshakeMessage:invalidMessage], @"Should handle invalid arguments %@ gracefully", args);
        XCTAssertFalse(handshake.handshakeComplete, @"Handshake should not be complete");
        XCTAssertEqual(handshake.lastProcessedMessage, F53OSCEncryptionHandshakeMessageNone, @"Handshake lastProcessedMessage should be .None");
    }
}

- (void)testThat_processHandshakeMessageHandlesCorruptedData
{
    F53OSCEncrypt *encrypter = [[F53OSCEncrypt alloc] init];
    F53OSCEncryptHandshake *handshake = [F53OSCEncryptHandshake handshakeWithEncrypter:encrypter];

    // Test with corrupted NSData arguments
    NSMutableData *corruptedData = [NSMutableData dataWithLength:32];
    // Fill with random bytes
    for (NSUInteger i = 0; i < 32; i++)
        ((char*)corruptedData.mutableBytes)[i] = (char)(arc4random() % 256);

    F53OSCMessage *corruptedMessage = [F53OSCMessage messageWithAddressPattern:@"!/encrypt/approve" arguments:@[corruptedData]];
    XCTAssertFalse([handshake processHandshakeMessage:corruptedMessage], @"Should handle corrupted data gracefully");
    XCTAssertFalse(handshake.handshakeComplete, @"Handshake should not be complete");
    XCTAssertEqual(handshake.lastProcessedMessage, F53OSCEncryptionHandshakeMessageNone, @"Handshake lastProcessedMessage should be .None");

    // Test with empty data
    NSData *emptyData = [NSData data];
    F53OSCMessage *emptyDataMessage = [F53OSCMessage messageWithAddressPattern:@"!/encrypt/begin" arguments:@[emptyData]];
    XCTAssertFalse([handshake processHandshakeMessage:emptyDataMessage], @"Should handle empty data gracefully");
    XCTAssertFalse(handshake.handshakeComplete, @"Handshake should not be complete");
    XCTAssertEqual(handshake.lastProcessedMessage, F53OSCEncryptionHandshakeMessageNone, @"Handshake lastProcessedMessage should be .None");
}

- (void)testThat_processHandshakeMessageHandlesOutOfSequenceMessages
{
    F53OSCEncrypt *encrypter = [[F53OSCEncrypt alloc] init];

    XCTAssertNotNil([encrypter generateKeyPair]);
    [encrypter generateSalt];

    F53OSCEncryptHandshake *handshake = [F53OSCEncryptHandshake handshakeWithEncrypter:encrypter];

    // Test processing messages out of sequence

    // Try processing approve before request
    F53OSCMessage *approveMessage = [handshake approveEncryptionMessage];
    XCTAssertTrue([handshake processHandshakeMessage:approveMessage], @"Should handle out-of-sequence approve message");
    XCTAssertFalse(handshake.handshakeComplete, @"Handshake should not be complete");
    XCTAssertEqual(handshake.lastProcessedMessage, F53OSCEncryptionHandshakeMessageApprove, @"Handshake lastProcessedMessage should be .Approve");

    // Try processing begin before proper setup
    F53OSCMessage *beginMessage = [handshake beginEncryptionMessage];
    XCTAssertTrue([handshake processHandshakeMessage:beginMessage], @"Should handle out-of-sequence begin message");
    XCTAssertTrue(handshake.handshakeComplete, @"Handshake should be complete");
    XCTAssertEqual(handshake.lastProcessedMessage, F53OSCEncryptionHandshakeMessageBegin, @"Handshake lastProcessedMessage should be .Begin");

    // Try processing duplicate requests
    F53OSCMessage *requestMessage = [handshake requestEncryptionMessage];
    XCTAssertTrue([handshake processHandshakeMessage:requestMessage], @"Should handle duplicate request message");
    XCTAssertTrue([handshake processHandshakeMessage:requestMessage], @"Should handle second duplicate request message");
    XCTAssertTrue(handshake.handshakeComplete, @"Handshake should still be complete from prior handling of begin message");
    XCTAssertEqual(handshake.lastProcessedMessage, F53OSCEncryptionHandshakeMessageRequest, @"Handshake lastProcessedMessage should be .Request");
}

@end

NS_ASSUME_NONNULL_END
