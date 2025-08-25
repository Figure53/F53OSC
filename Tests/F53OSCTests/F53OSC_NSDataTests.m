//
//  F53OSC_NSDataTests.m
//  F53OSC
//
//  Created by Brent Lord on 8/19/25.
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

#import "NSData+F53OSCBlob.h"


NS_ASSUME_NONNULL_BEGIN

@interface F53OSC_NSDataTests : XCTestCase
@end


@implementation F53OSC_NSDataTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
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


#pragma mark - 



#pragma mark - F53OSCBlobAdditions tests

- (void)testThat_oscBlobDataEncodesCorrectly
{
    // Test empty data.
    NSData *emptyData = [NSData data];
    NSData *emptyBlobData = [emptyData oscBlobData];

    XCTAssertNotNil(emptyBlobData, @"Empty data should produce valid blob");
    XCTAssertEqual(emptyBlobData.length, 4, @"Empty blob should be 4 bytes (size only)");

    // Verify the size is encoded as big-endian 0.
    UInt32 *sizePtr = (UInt32 *)emptyBlobData.bytes;
    UInt32 size = OSSwapBigToHostInt32(*sizePtr);
    XCTAssertEqual(size, 0, @"Empty blob size should be 0");

    // Test single byte data.
    char singleByte = 0x42;
    NSData *singleData = [NSData dataWithBytes:&singleByte length:1];
    NSData *singleBlobData = [singleData oscBlobData];

    XCTAssertNotNil(singleBlobData, @"Single byte data should produce valid blob");
    XCTAssertEqual(singleBlobData.length, 8, @"Single byte blob should be 8 bytes (size + data + padding)");

    // Verify size and data.
    sizePtr = (UInt32 *)singleBlobData.bytes;
    size = OSSwapBigToHostInt32(*sizePtr);
    XCTAssertEqual(size, 1, @"Single byte blob size should be 1");

    const char *dataPtr = (const char *)singleBlobData.bytes + 4;
    XCTAssertEqual(dataPtr[0], 0x42, @"First data byte should be correct");
    XCTAssertEqual(dataPtr[1], 0, @"Padding byte 1 should be null");
    XCTAssertEqual(dataPtr[2], 0, @"Padding byte 2 should be null");
    XCTAssertEqual(dataPtr[3], 0, @"Padding byte 3 should be null");
}

- (void)testThat_oscBlobDataHandlesDifferentSizes
{
    // Test data that requires different amounts of padding.
    NSArray<NSNumber *> *testSizes = @[@2, @3, @4, @5, @6, @7, @8, @100, @255, @256];

    for (NSNumber *sizeNum in testSizes)
    {
        NSUInteger testSize = [sizeNum unsignedIntegerValue];
        NSMutableData *testData = [NSMutableData dataWithCapacity:testSize];

        // Fill with incrementing bytes.
        for (NSUInteger i = 0; i < testSize; i++)
        {
            char byte = (char)(i % 256);
            [testData appendBytes:&byte length:1];
        }

        NSData *blobData = [testData oscBlobData];

        // Verify size field.
        UInt32 *sizePtr = (UInt32 *)blobData.bytes;
        UInt32 encodedSize = OSSwapBigToHostInt32(*sizePtr);
        XCTAssertEqual(encodedSize, testSize, @"Blob size should match original for size %@", sizeNum);

        // Verify total length is multiple of 4.
        XCTAssertEqual(blobData.length % 4, 0, @"Blob length should be multiple of 4 for size %@", sizeNum);

        // Calculate expected length: 4 bytes for size + data + padding to next multiple of 4.
        NSUInteger expectedLength = 4 + testSize;
        NSUInteger remainder = expectedLength % 4;
        if (remainder != 0)
            expectedLength += (4 - remainder);

        XCTAssertEqual(blobData.length, expectedLength, @"Blob length should be correct for size %@", sizeNum);

        // Verify data content.
        const char *dataPtr = (const char *)blobData.bytes + 4;
        for (NSUInteger i = 0; i < testSize; i++)
        {
            char expectedByte = (char)(i % 256);
            XCTAssertEqual(dataPtr[i], expectedByte, @"Data byte %zu should be correct for size %@", i, sizeNum);
        }
    }
}

- (void)testThat_dataWithOSCBlobBytesHandlesValidInput
{
    // Create test blob data manually.
    NSMutableData *testBlob = [NSMutableData data];

    // Add size (big-endian).
    UInt32 size = OSSwapHostToBigInt32(5);
    [testBlob appendBytes:&size length:sizeof(UInt32)];

    // Add data.
    const char testData[] = "hello";
    [testBlob appendBytes:testData length:5];

    // Add padding to make it multiple of 4.
    const char padding[] = {0, 0, 0};
    [testBlob appendBytes:padding length:3];

    NSUInteger bytesRead = 0;
    NSData *result = [NSData dataWithOSCBlobBytes:testBlob.bytes maxLength:testBlob.length bytesRead:&bytesRead];

    XCTAssertNotNil(result, @"Should successfully parse valid blob");
    XCTAssertEqual(result.length, 5, @"Result should have correct length");
    XCTAssertEqual(bytesRead, 12, @"Should read 12 bytes total (4 + 5 + 3 padding)");

    // Verify data content.
    XCTAssertTrue([result isEqualToData:[NSData dataWithBytes:testData length:5]], @"Data should match original");
}

- (void)testThat_dataWithOSCBlobBytesHandlesNullAndZeroInput
{
    NSUInteger bytesRead = 999; // Initialize to non-zero value

    // Test NULL buffer.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    NSData *result1 = [NSData dataWithOSCBlobBytes:NULL maxLength:10 bytesRead:&bytesRead];
#pragma clang diagnostic pop

    XCTAssertNil(result1, @"Should return nil for NULL buffer");
    XCTAssertEqual(bytesRead, 0, @"Should set bytesRead to 0 for NULL buffer");

    // Test zero maxLength.
    char validBuffer[8] = {0, 0, 0, 1, 0x42, 0, 0, 0}; // size=1, data=0x42, padding
    bytesRead = 999;
    NSData *result2 = [NSData dataWithOSCBlobBytes:validBuffer maxLength:0 bytesRead:&bytesRead];

    XCTAssertNil(result2, @"Should return nil for zero maxLength");
    XCTAssertEqual(bytesRead, 0, @"Should set bytesRead to 0 for zero maxLength");

    // Test with NULL bytesRead pointer.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    NSData *result3 = [NSData dataWithOSCBlobBytes:NULL maxLength:10 bytesRead:NULL];
#pragma clang diagnostic pop
    XCTAssertNil(result3, @"Should return nil for NULL buffer even with NULL bytesRead pointer");
}

- (void)testThat_dataWithOSCBlobBytesHandlesInvalidSizes
{
    // Test blob size larger than available data.
    NSMutableData *invalidBlob = [NSMutableData data];
    UInt32 size = OSSwapHostToBigInt32(100); // Claim 100 bytes
    [invalidBlob appendBytes:&size length:sizeof(UInt32)];
    const char shortData[] = "short";
    [invalidBlob appendBytes:shortData length:5]; // Only provide 5 bytes

    NSUInteger bytesRead = 999;
    NSData *result = [NSData dataWithOSCBlobBytes:invalidBlob.bytes maxLength:invalidBlob.length bytesRead:&bytesRead];

    XCTAssertNil(result, @"Should return nil when blob size exceeds available data");
    XCTAssertEqual(bytesRead, 0, @"Should set bytesRead to 0 for invalid size");

    // Test insufficient buffer for size field.
    char tinyBuffer[2] = {0x01, 0x02};
    bytesRead = 999;
    NSData *result2 = [NSData dataWithOSCBlobBytes:tinyBuffer maxLength:2 bytesRead:&bytesRead];

    XCTAssertNil(result2, @"Should return nil when buffer too small for size field");
    XCTAssertEqual(bytesRead, 0, @"Should set bytesRead to 0 for tiny buffer");
}

- (void)testThat_oscBlobDataRoundTripWorks
{
    // Test round trip for various data sizes.
    NSArray<NSData *> *testDataArray = @[
        [NSData data], // Empty
        [@"a" dataUsingEncoding:NSUTF8StringEncoding], // 1 byte
        [@"ab" dataUsingEncoding:NSUTF8StringEncoding], // 2 bytes
        [@"abc" dataUsingEncoding:NSUTF8StringEncoding], // 3 bytes
        [@"abcd" dataUsingEncoding:NSUTF8StringEncoding], // 4 bytes (no padding needed)
        [@"abcde" dataUsingEncoding:NSUTF8StringEncoding], // 5 bytes
        [@"Hello, World!" dataUsingEncoding:NSUTF8StringEncoding], // Longer string
    ];

    for (NSData *originalData in testDataArray)
    {
        // Encode to blob.
        NSData *blobData = [originalData oscBlobData];
        XCTAssertNotNil(blobData, @"Should encode to blob: %@", originalData);

        // Decode from blob.
        NSUInteger bytesRead = 0;
        NSData *decodedData = [NSData dataWithOSCBlobBytes:blobData.bytes maxLength:blobData.length bytesRead:&bytesRead];

        XCTAssertNotNil(decodedData, @"Should decode from blob: %@", originalData);
        XCTAssertTrue([decodedData isEqualToData:originalData], @"Round trip should preserve data: %@", originalData);
        XCTAssertEqual(bytesRead, blobData.length, @"Should read entire blob: %@", originalData);
    }
}

- (void)testThat_dataWithOSCBlobBytesCalculatesBytesReadCorrectly
{
    // Test various blob sizes and verify bytesRead calculation.
    NSArray<NSNumber *> *testSizes = @[@0, @1, @2, @3, @4, @5, @8, @16, @33];

    for (NSNumber *sizeNum in testSizes)
    {
        NSUInteger dataSize = [sizeNum unsignedIntegerValue];

        // Create test data.
        NSMutableData *testData = [NSMutableData dataWithCapacity:dataSize];
        for (NSUInteger i = 0; i < dataSize; i++)
        {
            char byte = (char)(i % 256);
            [testData appendBytes:&byte length:1];
        }

        // Encode to blob.
        NSData *blobData = [testData oscBlobData];

        // Decode and verify bytesRead.
        NSUInteger bytesRead = 0;
        NSData *decodedData = [NSData dataWithOSCBlobBytes:blobData.bytes maxLength:blobData.length bytesRead:&bytesRead];

        XCTAssertNotNil(decodedData, @"Should decode blob for size %@", sizeNum);
        XCTAssertEqual(decodedData.length, dataSize, @"Decoded data should have correct size for %@", sizeNum);
        XCTAssertEqual(bytesRead, blobData.length, @"bytesRead should equal blob length for size %@", sizeNum);
        XCTAssertEqual(bytesRead % 4, 0, @"bytesRead should be multiple of 4 for size %@", sizeNum);

        // Verify bytesRead calculation: 4 bytes for size + data + padding to multiple of 4.
        NSUInteger expectedBytesRead = 4 + dataSize;
        NSUInteger remainder = expectedBytesRead % 4;
        if (remainder != 0)
        {
            expectedBytesRead += (4 - remainder);
        }
        XCTAssertEqual(bytesRead, expectedBytesRead, @"bytesRead calculation should be correct for size %@", sizeNum);
    }
}

- (void)testThat_dataWithOSCBlobBytesHandlesLargeData
{
    // Test with larger data to ensure robustness.
    NSUInteger largeSize = 1024;
    NSMutableData *largeData = [NSMutableData dataWithCapacity:largeSize];

    // Fill with pattern data.
    for (NSUInteger i = 0; i < largeSize; i++)
    {
        char byte = (char)(i % 256);
        [largeData appendBytes:&byte length:1];
    }

    NSData *blobData = [largeData oscBlobData];
    XCTAssertNotNil(blobData, @"Should encode large data");

    NSUInteger bytesRead = 0;
    NSData *decodedData = [NSData dataWithOSCBlobBytes:blobData.bytes maxLength:blobData.length bytesRead:&bytesRead];

    XCTAssertNotNil(decodedData, @"Should decode large data");
    XCTAssertEqual(decodedData.length, largeSize, @"Large data should have correct size");
    XCTAssertTrue([decodedData isEqualToData:largeData], @"Large data should round trip correctly");
}

- (void)testThat_deprecatedDataWithOSCBlobBytesMethodWorks
{
    // Test the deprecated method to ensure it still works correctly.
    NSData *testData = [@"test data" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *blobData = [testData oscBlobData];

    NSUInteger length = 0;
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSData *decodedData = [NSData dataWithOSCBlobBytes:blobData.bytes maxLength:blobData.length length:&length];
    #pragma clang diagnostic pop

    XCTAssertNotNil(decodedData, @"Deprecated method should still work");
    XCTAssertTrue([decodedData isEqualToData:testData], @"Deprecated method should decode correctly");
    XCTAssertEqual(length, blobData.length, @"Deprecated method should set length correctly");
}

- (void)testThat_deprecatedMethodHandlesNullAndZeroLength
{
    // Test deprecated method with NULL buffer.
    NSUInteger length = 999;
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    #pragma clang diagnostic ignored "-Wnonnull"
    NSData *result1 = [NSData dataWithOSCBlobBytes:NULL maxLength:10 length:&length];
    #pragma clang diagnostic pop

    XCTAssertNil(result1, @"Deprecated method should return nil for NULL buffer");
    XCTAssertEqual(length, 0, @"Deprecated method should set length to 0 for NULL buffer");

    // Test with zero maxLength.
    char validBuffer[8] = {0, 0, 0, 1, 0x42, 0, 0, 0};
    length = 999;
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSData *result2 = [NSData dataWithOSCBlobBytes:validBuffer maxLength:0 length:&length];
    #pragma clang diagnostic pop

    XCTAssertNil(result2, @"Deprecated method should return nil for zero maxLength");
    XCTAssertEqual(length, 0, @"Deprecated method should set length to 0 for zero maxLength");
}

- (void)testThat_oscBlobDataHandlesBinaryData
{
    // Test with binary data containing null bytes and high values.
    char binaryData[] = {0x00, 0x01, 0xFF, 0x80, 0x7F, 0x00, 0xAB, 0xCD, 0xEF};
    NSData *testData = [NSData dataWithBytes:binaryData length:sizeof(binaryData)];

    NSData *blobData = [testData oscBlobData];
    XCTAssertNotNil(blobData, @"Should handle binary data");

    NSUInteger bytesRead = 0;
    NSData *decodedData = [NSData dataWithOSCBlobBytes:blobData.bytes maxLength:blobData.length bytesRead:&bytesRead];

    XCTAssertNotNil(decodedData, @"Should decode binary data");
    XCTAssertTrue([decodedData isEqualToData:testData], @"Binary data should round trip correctly");

    // Verify specific bytes.
    const char *decodedBytes = (const char *)decodedData.bytes;
    for (NSUInteger i = 0; i < sizeof(binaryData); i++)
        XCTAssertEqual(decodedBytes[i], binaryData[i], @"Binary byte %zu should be correct", i);
}

@end

NS_ASSUME_NONNULL_END
