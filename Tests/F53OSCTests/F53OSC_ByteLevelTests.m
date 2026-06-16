//
//  F53OSC_ByteLevelTests.m
//  F53OSC
//
//  Copyright (c) 2026 Figure 53 LLC.  https://figure53.com
//
//  Byte-level conformance tests for the OSC 1.0/1.1 wire format.
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

#import "F53OSCBundle.h"
#import "F53OSCMessage.h"
#import "F53OSCParser.h"
#import "F53OSCSocket.h"
#import "F53OSCTimeTag.h"
#import "F53OSCValue.h"


NS_ASSUME_NONNULL_BEGIN

#pragma mark - MockPacketDestination

/// Collects messages delivered by F53OSCParser during bundle decode.
@interface ByteLevelMockDestination : NSObject <F53OSCPacketDestination>
@property (nonatomic, strong) NSMutableArray<F53OSCMessage *> *messages;
@end

@implementation ByteLevelMockDestination

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        self.messages = [NSMutableArray array];
    }
    return self;
}

- (void)takeMessage:(nullable F53OSCMessage *)message
{
    if (message != nil)
        [self.messages addObject:(F53OSCMessage * _Nonnull)message];
}

@end


#pragma mark - F53OSC_ByteLevelTests

@interface F53OSC_ByteLevelTests : XCTestCase
@property (nonatomic, strong, nullable) F53OSCSocket *mockSocket;
@end

@implementation F53OSC_ByteLevelTests

- (void)setUp
{
    [super setUp];

    // F53OSCParser's processOscData API requires a non-nil socket to reply
    // through. None of these tests actually send anything, but we give it a
    // real socket object to satisfy the contract.
    self.mockSocket = [F53OSCSocket outboundTcpSocketWithCallbackQueue:dispatch_get_main_queue()];
}


#pragma mark - Required OSC 1.0 Type Tags

- (void)testByteLevel_emptyMessage
{
    // Address pattern "/test" with no arguments.
    static const uint8_t bytes[] = {
        0x2F, 0x74, 0x65, 0x73, 0x74, 0x00, 0x00, 0x00, // "/test\0\0\0"
        0x2C, 0x00, 0x00, 0x00,                         // ",\0\0\0"
    };
    [self assertMessageRoundTripWithBytes:bytes
                                   length:sizeof(bytes)
                           addressPattern:@"/test"
                                arguments:@[]];
}

- (void)testByteLevel_int32
{
    // "/test" ,i 255
    static const uint8_t bytes[] = {
        0x2F, 0x74, 0x65, 0x73, 0x74, 0x00, 0x00, 0x00, // "/test\0\0\0"
        0x2C, 0x69, 0x00, 0x00,                         // ",i\0\0"
        0x00, 0x00, 0x00, 0xFF,                         // 255 (big-endian)
    };
    [self assertMessageRoundTripWithBytes:bytes
                                   length:sizeof(bytes)
                           addressPattern:@"/test"
                                arguments:@[@((int32_t)255)]];
}

- (void)testByteLevel_int32Negative
{
    // "/test" ,i -1
    static const uint8_t bytes[] = {
        0x2F, 0x74, 0x65, 0x73, 0x74, 0x00, 0x00, 0x00, // "/test\0\0\0"
        0x2C, 0x69, 0x00, 0x00,                         // ",i\0\0"
        0xFF, 0xFF, 0xFF, 0xFF,                         // -1 (two's complement)
    };
    [self assertMessageRoundTripWithBytes:bytes
                                   length:sizeof(bytes)
                           addressPattern:@"/test"
                                arguments:@[@((int32_t)-1)]];
}

- (void)testByteLevel_float32
{
    // "/test" ,f 1.0  (IEEE 754 binary32: 0x3F800000)
    static const uint8_t bytes[] = {
        0x2F, 0x74, 0x65, 0x73, 0x74, 0x00, 0x00, 0x00, // "/test\0\0\0"
        0x2C, 0x66, 0x00, 0x00,                         // ",f\0\0"
        0x3F, 0x80, 0x00, 0x00,                         // 1.0
    };
    [self assertMessageRoundTripWithBytes:bytes
                                   length:sizeof(bytes)
                           addressPattern:@"/test"
                                arguments:@[@((float)1.0f)]];
}

- (void)testByteLevel_float32Negative
{
    // "/test" ,f -0.5  (IEEE 754 binary32: 0xBF000000)
    static const uint8_t bytes[] = {
        0x2F, 0x74, 0x65, 0x73, 0x74, 0x00, 0x00, 0x00, // "/test\0\0\0"
        0x2C, 0x66, 0x00, 0x00,                         // ",f\0\0"
        0xBF, 0x00, 0x00, 0x00,                         // -0.5
    };
    [self assertMessageRoundTripWithBytes:bytes
                                   length:sizeof(bytes)
                           addressPattern:@"/test"
                                arguments:@[@((float)-0.5f)]];
}

- (void)testByteLevel_string
{
    // "/test" ,s "hello"
    static const uint8_t bytes[] = {
        0x2F, 0x74, 0x65, 0x73, 0x74, 0x00, 0x00, 0x00, // "/test\0\0\0"
        0x2C, 0x73, 0x00, 0x00,                         // ",s\0\0"
        0x68, 0x65, 0x6C, 0x6C, 0x6F, 0x00, 0x00, 0x00, // "hello\0\0\0"
    };
    [self assertMessageRoundTripWithBytes:bytes
                                   length:sizeof(bytes)
                           addressPattern:@"/test"
                                arguments:@[@"hello"]];
}

- (void)testByteLevel_stringEmpty
{
    // "/test" ,s ""
    static const uint8_t bytes[] = {
        0x2F, 0x74, 0x65, 0x73, 0x74, 0x00, 0x00, 0x00, // "/test\0\0\0"
        0x2C, 0x73, 0x00, 0x00,                         // ",s\0\0"
        0x00, 0x00, 0x00, 0x00,                         // "\0\0\0\0"
    };
    [self assertMessageRoundTripWithBytes:bytes
                                   length:sizeof(bytes)
                           addressPattern:@"/test"
                                arguments:@[@""]];
}

- (void)testByteLevel_stringExactFourByteMultiple
{
    // "/test" ,s "foo" - already 4-aligned with just the null terminator.
    static const uint8_t bytes[] = {
        0x2F, 0x74, 0x65, 0x73, 0x74, 0x00, 0x00, 0x00, // "/test\0\0\0"
        0x2C, 0x73, 0x00, 0x00,                         // ",s\0\0"
        0x66, 0x6F, 0x6F, 0x00,                         // "foo\0"
    };
    [self assertMessageRoundTripWithBytes:bytes
                                   length:sizeof(bytes)
                           addressPattern:@"/test"
                                arguments:@[@"foo"]];
}

- (void)testByteLevel_blob
{
    // "/test" ,b <5 bytes>
    static const uint8_t bytes[] = {
        0x2F, 0x74, 0x65, 0x73, 0x74, 0x00, 0x00, 0x00, // "/test\0\0\0"
        0x2C, 0x62, 0x00, 0x00,                         // ",b\0\0"
        0x00, 0x00, 0x00, 0x05,                         // size = 5
        0x01, 0x02, 0x03, 0x04, 0x05,                   // payload
        0x00, 0x00, 0x00,                               // pad
    };
    uint8_t blobBytes[] = { 0x01, 0x02, 0x03, 0x04, 0x05 };
    NSData *blob = [NSData dataWithBytes:blobBytes length:sizeof(blobBytes)];
    [self assertMessageRoundTripWithBytes:bytes
                                   length:sizeof(bytes)
                           addressPattern:@"/test"
                                arguments:@[blob]];
}

- (void)testByteLevel_blobEmpty
{
    // "/test" ,b <empty>
    static const uint8_t bytes[] = {
        0x2F, 0x74, 0x65, 0x73, 0x74, 0x00, 0x00, 0x00, // "/test\0\0\0"
        0x2C, 0x62, 0x00, 0x00,                         // ",b\0\0"
        0x00, 0x00, 0x00, 0x00,                         // size = 0
    };
    [self assertMessageRoundTripWithBytes:bytes
                                   length:sizeof(bytes)
                           addressPattern:@"/test"
                                arguments:@[[NSData data]]];
}

- (void)testByteLevel_blobExactFourByteMultiple
{
    // "/test" ,b <4 bytes> - no padding needed.
    static const uint8_t bytes[] = {
        0x2F, 0x74, 0x65, 0x73, 0x74, 0x00, 0x00, 0x00, // "/test\0\0\0"
        0x2C, 0x62, 0x00, 0x00,                         // ",b\0\0"
        0x00, 0x00, 0x00, 0x04,                         // size = 4
        0xDE, 0xAD, 0xBE, 0xEF,                         // payload
    };
    uint8_t blobBytes[] = { 0xDE, 0xAD, 0xBE, 0xEF };
    NSData *blob = [NSData dataWithBytes:blobBytes length:sizeof(blobBytes)];
    [self assertMessageRoundTripWithBytes:bytes
                                   length:sizeof(bytes)
                           addressPattern:@"/test"
                                arguments:@[blob]];
}


#pragma mark - OSC 1.1 Type Tags

- (void)testByteLevel_true
{
    // "/test" ,T  - no argument bytes.
    static const uint8_t bytes[] = {
        0x2F, 0x74, 0x65, 0x73, 0x74, 0x00, 0x00, 0x00, // "/test\0\0\0"
        0x2C, 0x54, 0x00, 0x00,                         // ",T\0\0"
    };
    [self assertMessageRoundTripWithBytes:bytes
                                   length:sizeof(bytes)
                           addressPattern:@"/test"
                                arguments:@[[F53OSCValue oscTrue]]];
}

- (void)testByteLevel_false
{
    // "/test" ,F
    static const uint8_t bytes[] = {
        0x2F, 0x74, 0x65, 0x73, 0x74, 0x00, 0x00, 0x00, // "/test\0\0\0"
        0x2C, 0x46, 0x00, 0x00,                         // ",F\0\0"
    };
    [self assertMessageRoundTripWithBytes:bytes
                                   length:sizeof(bytes)
                           addressPattern:@"/test"
                                arguments:@[[F53OSCValue oscFalse]]];
}

- (void)testByteLevel_null
{
    // "/test" ,N
    static const uint8_t bytes[] = {
        0x2F, 0x74, 0x65, 0x73, 0x74, 0x00, 0x00, 0x00, // "/test\0\0\0"
        0x2C, 0x4E, 0x00, 0x00,                         // ",N\0\0"
    };
    [self assertMessageRoundTripWithBytes:bytes
                                   length:sizeof(bytes)
                           addressPattern:@"/test"
                                arguments:@[[F53OSCValue oscNull]]];
}

- (void)testByteLevel_impulse
{
    // "/test" ,I
    static const uint8_t bytes[] = {
        0x2F, 0x74, 0x65, 0x73, 0x74, 0x00, 0x00, 0x00, // "/test\0\0\0"
        0x2C, 0x49, 0x00, 0x00,                         // ",I\0\0"
    };
    [self assertMessageRoundTripWithBytes:bytes
                                   length:sizeof(bytes)
                           addressPattern:@"/test"
                                arguments:@[[F53OSCValue oscImpulse]]];
}


#pragma mark - Multi-Argument Messages

- (void)testByteLevel_multipleArguments
{
    // "/mixer/1/level" ,ifs 53 0.5 "hello"
    static const uint8_t bytes[] = {
        0x2F, 0x6D, 0x69, 0x78, 0x65, 0x72, 0x2F, 0x31, // "/mixer/1"
        0x2F, 0x6C, 0x65, 0x76, 0x65, 0x6C, 0x00, 0x00, // "/level\0\0"
        0x2C, 0x69, 0x66, 0x73, 0x00, 0x00, 0x00, 0x00, // ",ifs\0\0\0\0"
        0x00, 0x00, 0x00, 0x35,                         // int32 = 53
        0x3F, 0x00, 0x00, 0x00,                         // float32 = 0.5
        0x68, 0x65, 0x6C, 0x6C, 0x6F, 0x00, 0x00, 0x00, // string = "hello\0\0\0"
    };
    [self assertMessageRoundTripWithBytes:bytes
                                   length:sizeof(bytes)
                           addressPattern:@"/mixer/1/level"
                                arguments:@[@((int32_t)53), @((float)0.5f), @"hello"]];
}

- (void)testByteLevel_mixed11Arguments
{
    // "/sys" ,TFNI
    static const uint8_t bytes[] = {
        0x2F, 0x73, 0x79, 0x73, 0x00, 0x00, 0x00, 0x00, // "/sys\0\0\0\0"
        0x2C, 0x54, 0x46, 0x4E, 0x49, 0x00, 0x00, 0x00, // ",TFNI\0\0\0"
    };
    [self assertMessageRoundTripWithBytes:bytes
                                   length:sizeof(bytes)
                           addressPattern:@"/sys"
                                arguments:@[[F53OSCValue oscTrue],
                                            [F53OSCValue oscFalse],
                                            [F53OSCValue oscNull],
                                            [F53OSCValue oscImpulse]]];
}

- (void)testByteLevel_argumentOrderMatters
{
    // "/test" ,fi 1.0 2
    static const uint8_t bytes[] = {
        0x2F, 0x74, 0x65, 0x73, 0x74, 0x00, 0x00, 0x00, // "/test\0\0\0"
        0x2C, 0x66, 0x69, 0x00,                         // ",fi\0"
        0x3F, 0x80, 0x00, 0x00,                         // float32 = 1.0
        0x00, 0x00, 0x00, 0x02,                         // int32 = 2
    };
    [self assertMessageRoundTripWithBytes:bytes
                                   length:sizeof(bytes)
                           addressPattern:@"/test"
                                arguments:@[@((float)1.0f), @((int32_t)2)]];
}


#pragma mark - Bundles
//
// v1's F53OSCBundle stores its elements as NSData (packetData of the inner
// message/bundle) rather than as parsed packet objects. Encode-direction
// tests construct the bundle from those NSData elements. Decode-direction
// tests use F53OSCParser's destination-callback API, which recursively
// flattens bundles and delivers leaf messages to a collecting destination.

- (void)testByteLevel_bundleEmpty
{
    // #bundle <immediate>  - no elements.
    static const uint8_t bytes[] = {
        0x23, 0x62, 0x75, 0x6E, 0x64, 0x6C, 0x65, 0x00, // "#bundle\0"
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, // time tag = immediate (0, 1)
    };
    F53OSCBundle *bundle = [F53OSCBundle bundleWithTimeTag:[F53OSCTimeTag immediateTimeTag]
                                                  elements:@[]];
    [self assertBundleEncodeBundle:bundle matchesBytes:bytes length:sizeof(bytes)];
    [self assertBundleDecodeBytes:bytes length:sizeof(bytes) yieldsMessages:@[]];
}

- (void)testByteLevel_bundleOneMessage
{
    // #bundle <immediate> [ /test ,i 255 ]
    static const uint8_t bytes[] = {
        0x23, 0x62, 0x75, 0x6E, 0x64, 0x6C, 0x65, 0x00, // "#bundle\0"
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, // time tag = immediate
        0x00, 0x00, 0x00, 0x10,                         // element size = 16
        0x2F, 0x74, 0x65, 0x73, 0x74, 0x00, 0x00, 0x00, // "/test\0\0\0"
        0x2C, 0x69, 0x00, 0x00,                         // ",i\0\0"
        0x00, 0x00, 0x00, 0xFF,                         // int32 = 255
    };
    F53OSCMessage *inner = [F53OSCMessage messageWithAddressPattern:@"/test"
                                                          arguments:@[@((int32_t)255)]];
    F53OSCBundle *bundle = [F53OSCBundle bundleWithTimeTag:[F53OSCTimeTag immediateTimeTag]
                                                  elements:@[inner.packetData]];
    [self assertBundleEncodeBundle:bundle matchesBytes:bytes length:sizeof(bytes)];
    [self assertBundleDecodeBytes:bytes length:sizeof(bytes) yieldsMessages:@[inner]];
}

- (void)testByteLevel_bundleExplicitTimeTag
{
    // #bundle with a non-immediate time tag, no elements.
    static const uint8_t bytes[] = {
        0x23, 0x62, 0x75, 0x6E, 0x64, 0x6C, 0x65, 0x00, // "#bundle\0"
        0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE, 0xF0, // time tag = (0x12345678, 0x9ABCDEF0)
    };
    F53OSCTimeTag *timeTag = [[F53OSCTimeTag alloc] init];
    timeTag.seconds = 0x12345678;
    timeTag.fraction = 0x9ABCDEF0;
    F53OSCBundle *bundle = [F53OSCBundle bundleWithTimeTag:timeTag elements:@[]];
    [self assertBundleEncodeBundle:bundle matchesBytes:bytes length:sizeof(bytes)];
    [self assertBundleDecodeBytes:bytes length:sizeof(bytes) yieldsMessages:@[]];
}

- (void)testByteLevel_bundleMultipleMessages
{
    // #bundle <immediate> [ /a ,i 1 , /b ,i 2 ]
    static const uint8_t bytes[] = {
        0x23, 0x62, 0x75, 0x6E, 0x64, 0x6C, 0x65, 0x00, // "#bundle\0"
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, // time tag = immediate
        0x00, 0x00, 0x00, 0x0C,                         // element 1 size = 12
        0x2F, 0x61, 0x00, 0x00,                         // "/a\0\0"
        0x2C, 0x69, 0x00, 0x00,                         // ",i\0\0"
        0x00, 0x00, 0x00, 0x01,                         // int32 = 1
        0x00, 0x00, 0x00, 0x0C,                         // element 2 size = 12
        0x2F, 0x62, 0x00, 0x00,                         // "/b\0\0"
        0x2C, 0x69, 0x00, 0x00,                         // ",i\0\0"
        0x00, 0x00, 0x00, 0x02,                         // int32 = 2
    };
    F53OSCMessage *a = [F53OSCMessage messageWithAddressPattern:@"/a"
                                                      arguments:@[@((int32_t)1)]];
    F53OSCMessage *b = [F53OSCMessage messageWithAddressPattern:@"/b"
                                                      arguments:@[@((int32_t)2)]];
    F53OSCBundle *bundle = [F53OSCBundle bundleWithTimeTag:[F53OSCTimeTag immediateTimeTag]
                                                  elements:@[a.packetData, b.packetData]];
    [self assertBundleEncodeBundle:bundle matchesBytes:bytes length:sizeof(bytes)];
    [self assertBundleDecodeBytes:bytes length:sizeof(bytes) yieldsMessages:@[a, b]];
}

- (void)testByteLevel_bundleNested
{
    // Outer bundle contains one inner bundle, which contains one message.
    static const uint8_t bytes[] = {
        0x23, 0x62, 0x75, 0x6E, 0x64, 0x6C, 0x65, 0x00, // outer: "#bundle\0"
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, // outer: time tag = immediate
        0x00, 0x00, 0x00, 0x24,                         // outer: inner bundle size = 36
        0x23, 0x62, 0x75, 0x6E, 0x64, 0x6C, 0x65, 0x00, // inner: "#bundle\0"
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, // inner: time tag = immediate
        0x00, 0x00, 0x00, 0x10,                         // inner: message size = 16
        0x2F, 0x74, 0x65, 0x73, 0x74, 0x00, 0x00, 0x00, // "/test\0\0\0"
        0x2C, 0x69, 0x00, 0x00,                         // ",i\0\0"
        0x00, 0x00, 0x00, 0xFF,                         // int32 = 255
    };
    F53OSCMessage *leaf = [F53OSCMessage messageWithAddressPattern:@"/test"
                                                         arguments:@[@((int32_t)255)]];
    F53OSCBundle *inner = [F53OSCBundle bundleWithTimeTag:[F53OSCTimeTag immediateTimeTag]
                                                 elements:@[leaf.packetData]];
    F53OSCBundle *outer = [F53OSCBundle bundleWithTimeTag:[F53OSCTimeTag immediateTimeTag]
                                                 elements:@[inner.packetData]];
    [self assertBundleEncodeBundle:outer matchesBytes:bytes length:sizeof(bytes)];
    [self assertBundleDecodeBytes:bytes length:sizeof(bytes) yieldsMessages:@[leaf]];
}


#pragma mark - Helpers

/// Round-trip a message fixture: construct from arguments and verify bytes
/// match, then parse the bytes and verify address and arguments match.
- (void)assertMessageRoundTripWithBytes:(const uint8_t *)bytes
                                 length:(NSUInteger)length
                         addressPattern:(NSString *)addressPattern
                              arguments:(NSArray<id> *)arguments
{
    NSData *expectedData = [NSData dataWithBytes:bytes length:length];

    // Encode direction: build the message, check bytes.
    F53OSCMessage *built = [F53OSCMessage messageWithAddressPattern:addressPattern
                                                          arguments:arguments];
    XCTAssertEqualObjects(built.packetData, expectedData,
                          @"Encoded bytes did not match fixture (address = %@). Got %@, expected %@.",
                          addressPattern, [self hexFromData:built.packetData], [self hexFromData:expectedData]);

    // Decode direction: parse the bytes, check structure.
    F53OSCMessage *parsed = [F53OSCParser parseOscMessageData:expectedData];
    XCTAssertNotNil(parsed, @"Parser returned nil for fixture (address = %@).", addressPattern);
    XCTAssertEqualObjects(parsed.addressPattern, addressPattern,
                          @"Parsed address did not match fixture.");
    XCTAssertEqualObjects(parsed.arguments, arguments,
                          @"Parsed arguments did not match fixture (address = %@).", addressPattern);
}

/// Check that a constructed bundle's packetData matches the expected bytes.
- (void)assertBundleEncodeBundle:(F53OSCBundle *)bundle
                    matchesBytes:(const uint8_t *)bytes
                          length:(NSUInteger)length
{
    NSData *expectedData = [NSData dataWithBytes:bytes length:length];
    XCTAssertEqualObjects(bundle.packetData, expectedData,
                          @"Encoded bundle bytes did not match fixture. Got %@, expected %@.",
                          [self hexFromData:bundle.packetData], [self hexFromData:expectedData]);
}

/// Parse bundle bytes through F53OSCParser and verify the flattened sequence
/// of leaf messages matches `expectedMessages`.
- (void)assertBundleDecodeBytes:(const uint8_t *)bytes
                         length:(NSUInteger)length
                 yieldsMessages:(NSArray<F53OSCMessage *> *)expectedMessages
{
    NSData *data = [NSData dataWithBytes:bytes length:length];

    ByteLevelMockDestination *destination = [[ByteLevelMockDestination alloc] init];
    [F53OSCParser processOscData:data
                  forDestination:destination
                   replyToSocket:(F53OSCSocket * _Nonnull)self.mockSocket
                  controlHandler:nil
                    wasEncrypted:NO];

    XCTAssertEqual(destination.messages.count, expectedMessages.count,
                   @"Expected %lu messages, got %lu.",
                   (unsigned long)expectedMessages.count,
                   (unsigned long)destination.messages.count);

    NSUInteger pairs = MIN(destination.messages.count, expectedMessages.count);
    for (NSUInteger i = 0; i < pairs; i++)
    {
        F53OSCMessage *actual = destination.messages[i];
        F53OSCMessage *expected = expectedMessages[i];
        XCTAssertEqualObjects(actual.addressPattern, expected.addressPattern,
                              @"Decoded message %lu address mismatch.", (unsigned long)i);
        XCTAssertEqualObjects(actual.arguments, expected.arguments,
                              @"Decoded message %lu arguments mismatch.", (unsigned long)i);
    }
}

/// Format NSData as a space-separated hex string for readable test failures.
- (NSString *)hexFromData:(nullable NSData *)data
{
    if (data == nil) return @"(nil)";
    NSMutableString *hex = [NSMutableString stringWithCapacity:data.length * 3];
    const uint8_t *b = data.bytes;
    for (NSUInteger i = 0; i < data.length; i++)
    {
        [hex appendFormat:(i == 0 ? @"%02X" : @" %02X"), b[i]];
    }
    return hex;
}

@end

NS_ASSUME_NONNULL_END
