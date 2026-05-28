//
//  F53OSC_CodecBenchmark.m
//  F53OSC Tests
//
//  Created by Christopher Cahoon on 5/23/26.
//  Copyright (c) 2026 Figure 53 LLC, https://figure53.com
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
//  Codec-only microbenchmarks for the SLIP encoder and decoder. No network involved.
//  End-to-end throughput tests are dominated by kernel syscall overhead, which can
//  mask a 2x codec regression. These run in microseconds and surface codec changes
//  directly.
//
//  Set baselines via the Xcode Test Navigator (right-click → "Set Baseline") so
//  future regressions over 10% fail the build automatically.
//

#if !__has_feature(objc_arc)
#error This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#import <XCTest/XCTest.h>

#if F53OSC_BUILT_AS_FRAMEWORK
#import <F53OSC/F53OSCMessage.h>
#import <F53OSC/F53OSCParser.h>
#import <F53OSC/F53OSCSocket.h>
#else
#import "F53OSCMessage.h"
#import "F53OSCParser.h"
#import "F53OSCSocket.h"
#endif


NS_ASSUME_NONNULL_BEGIN

// SLIP framing bytes for synthetic payload construction.
static const uint8_t kSlipEND     = 0xC0;
static const uint8_t kSlipESC     = 0xDB;
static const uint8_t kSlipESC_END = 0xDC;
static const uint8_t kSlipESC_ESC = 0xDD;


#pragma mark - Legacy (pre-vectorization) implementations, here for A/B comparison

// Byte-at-a-time SLIP encoder, restored from the pre-modernization implementation
// (one -appendBytes:length:1 call per input byte plus per-escape). Kept in this
// test file so the production code stays vectorized. Running both variants of the
// benchmark side-by-side measures the vectorization speedup.
static NSData *SlipFrameDataLegacy(NSData *data)
{
    NSMutableData *slipData = [NSMutableData data];
    Byte end[1]     = { kSlipEND };
    Byte esc_end[2] = { kSlipESC, kSlipESC_END };
    Byte esc_esc[2] = { kSlipESC, kSlipESC_ESC };

    [slipData appendBytes:end length:1];

    const Byte *buffer = data.bytes;
    NSUInteger length  = data.length;
    for ( NSUInteger i = 0; i < length; i++ )
    {
        if ( buffer[i] == kSlipEND )
            [slipData appendBytes:esc_end length:2];
        else if ( buffer[i] == kSlipESC )
            [slipData appendBytes:esc_esc length:2];
        else
            [slipData appendBytes:&buffer[i] length:1];
    }

    [slipData appendBytes:end length:1];
    return slipData;
}

// Byte-at-a-time SLIP decoder body, restored from the pre-modernization parser.
// Decodes a chunk into `out` (caller-provided NSMutableData) and reports complete
// frames via the `dispatch` block, which the caller hooks to count messages.
// Cross-chunk danglingESC state is owned by the caller via the `state` pointer.
typedef void (^SlipFrameHandler)(NSData *frame);

// Scan-for-runs SLIP decoder, the same algorithmic shape as the production
// F53OSCParser translateSlipData: minus the processOscData / destination dispatch.
// Calls the `dispatch` block once per complete SLIP frame for fair comparison
// with the legacy variant.
static void SlipDecodeVectorized(NSData *in,
                                 NSMutableData *out,
                                 BOOL *danglingESC,
                                 SlipFrameHandler dispatch)
{
    const Byte *buffer = in.bytes;
    NSUInteger length  = in.length;
    NSUInteger i       = 0;

    Byte end[1] = { kSlipEND };
    Byte esc[1] = { kSlipESC };

    if ( *danglingESC && length > 0 )
    {
        Byte b = buffer[0];
        Byte writeByte;
        if      ( b == kSlipESC_END ) writeByte = kSlipEND;
        else if ( b == kSlipESC_ESC ) writeByte = kSlipESC;
        else                           writeByte = b;
        [out appendBytes:&writeByte length:1];
        *danglingESC = NO;
        i = 1;
    }

    NSUInteger runStart = i;
    while ( i < length )
    {
        Byte b = buffer[i];
        if ( b == kSlipEND )
        {
            if ( i > runStart )
                [out appendBytes:(buffer + runStart) length:(i - runStart)];
            dispatch([NSData dataWithData:out]);
            [out setData:[NSData data]];
            i++;
            runStart = i;
        }
        else if ( b == kSlipESC )
        {
            if ( i > runStart )
                [out appendBytes:(buffer + runStart) length:(i - runStart)];
            if ( i + 1 < length )
            {
                Byte next = buffer[i + 1];
                Byte writeByte;
                if      ( next == kSlipESC_END ) writeByte = kSlipEND;
                else if ( next == kSlipESC_ESC ) writeByte = kSlipESC;
                else                              writeByte = next;
                [out appendBytes:&writeByte length:1];
                i += 2;
                runStart = i;
            }
            else
            {
                *danglingESC = YES;
                i++;
                runStart = i;
                break;
            }
        }
        else
        {
            i++;
        }
    }

    if ( runStart < length )
        [out appendBytes:(buffer + runStart) length:(length - runStart)];

    (void)end; (void)esc; // legacy decoder uses these directly. Vectorized uses inline bytes
}

static void SlipDecodeLegacy(NSData *in,
                             NSMutableData *out,
                             BOOL *danglingESC,
                             SlipFrameHandler dispatch)
{
    const Byte *buffer = in.bytes;
    NSUInteger length  = in.length;

    Byte end[1] = { kSlipEND };
    Byte esc[1] = { kSlipESC };

    for ( NSUInteger i = 0; i < length; i++ )
    {
        if ( *danglingESC )
        {
            *danglingESC = NO;
            if      ( buffer[i] == kSlipESC_END ) [out appendBytes:end length:1];
            else if ( buffer[i] == kSlipESC_ESC ) [out appendBytes:esc length:1];
            else                                   [out appendBytes:&buffer[i] length:1];
        }
        else if ( buffer[i] == kSlipEND )
        {
            dispatch([NSData dataWithData:out]);
            [out setData:[NSData data]];
        }
        else if ( buffer[i] == kSlipESC )
        {
            if ( i + 1 < length )
            {
                i++;
                if      ( buffer[i] == kSlipESC_END ) [out appendBytes:end length:1];
                else if ( buffer[i] == kSlipESC_ESC ) [out appendBytes:esc length:1];
                else                                   [out appendBytes:&buffer[i] length:1];
            }
            else
            {
                *danglingESC = YES;
            }
        }
        else
        {
            [out appendBytes:&buffer[i] length:1];
        }
    }
}


#pragma mark - CodecCapture

// Minimal F53OSCPacketDestination that counts messages. The decoder dispatches
// each fully-framed OSC packet to its destination. We don't care about content.
@interface CodecCapture : NSObject <F53OSCPacketDestination>
@property (atomic) NSInteger count;
@end

@implementation CodecCapture

- (void) takeMessage:(nullable F53OSCMessage *)message
{
    self.count++;
}

@end


#pragma mark - F53OSC_CodecBenchmark

@interface F53OSC_CodecBenchmark : XCTestCase
@end

@implementation F53OSC_CodecBenchmark

// Build a synthetic OSC message payload large enough to be representative but
// small enough that codec work dominates over allocation overhead. ~256 bytes.
- (NSData *) syntheticPayload
{
    F53OSCMessage *msg = [F53OSCMessage messageWithAddressPattern:@"/codec/bench"
                                                       arguments:@[ @"hello",
                                                                    @(42),
                                                                    @(3.14159f),
                                                                    [@"some-blob-content-here" dataUsingEncoding:NSUTF8StringEncoding] ]];
    return msg.packetData;
}

// Synthetic payload with high special-byte density: half the bytes are END or ESC.
// Exercises the vectorized encoder/decoder's escape paths.
- (NSData *) syntheticHighDensitySpecialsPayload:(NSUInteger)length
{
    NSMutableData *data = [NSMutableData dataWithCapacity:length];
    for ( NSUInteger i = 0; i < length; i++ )
    {
        uint8_t b;
        if      ( (i & 3) == 0 ) b = kSlipEND;
        else if ( (i & 3) == 1 ) b = kSlipESC;
        else                      b = (uint8_t)(i & 0xFF);
        [data appendBytes:&b length:1];
    }
    return data;
}


#pragma mark - Encoder: vectorized (production) vs legacy (byte-at-a-time)

// Pair each test with a _Legacy variant. Side-by-side numbers in the test report
// give the vectorization speedup ratio for that payload shape.

- (void) testEncode_OSCMessagePayload_10kIterations
{
    NSData *payload = [self syntheticPayload];
    [self measureBlock:^{
        for ( NSInteger i = 0; i < 10000; i++ )
            (void)[F53OSCParser slipFrameData:payload];
    }];
}

- (void) testEncode_OSCMessagePayload_10kIterations_Legacy
{
    NSData *payload = [self syntheticPayload];
    [self measureBlock:^{
        for ( NSInteger i = 0; i < 10000; i++ )
            (void)SlipFrameDataLegacy(payload);
    }];
}

- (void) testEncode_HighSpecialDensity_10kIterations
{
    NSData *payload = [self syntheticHighDensitySpecialsPayload:256];
    [self measureBlock:^{
        for ( NSInteger i = 0; i < 10000; i++ )
            (void)[F53OSCParser slipFrameData:payload];
    }];
}

- (void) testEncode_HighSpecialDensity_10kIterations_Legacy
{
    NSData *payload = [self syntheticHighDensitySpecialsPayload:256];
    [self measureBlock:^{
        for ( NSInteger i = 0; i < 10000; i++ )
            (void)SlipFrameDataLegacy(payload);
    }];
}

- (void) testEncode_LargeBlob_1kIterations
{
    // 64 KB payload, no specials. Exercises the run-scanning path for long runs.
    NSMutableData *payload = [NSMutableData dataWithCapacity:64 * 1024];
    for ( NSUInteger i = 0; i < 64 * 1024; i++ )
    {
        uint8_t b = (uint8_t)((i * 31) & 0x7F); // stays under 0xC0, no specials
        [payload appendBytes:&b length:1];
    }
    [self measureBlock:^{
        for ( NSInteger i = 0; i < 1000; i++ )
            (void)[F53OSCParser slipFrameData:payload];
    }];
}

- (void) testEncode_LargeBlob_1kIterations_Legacy
{
    NSMutableData *payload = [NSMutableData dataWithCapacity:64 * 1024];
    for ( NSUInteger i = 0; i < 64 * 1024; i++ )
    {
        uint8_t b = (uint8_t)((i * 31) & 0x7F);
        [payload appendBytes:&b length:1];
    }
    [self measureBlock:^{
        for ( NSInteger i = 0; i < 1000; i++ )
            (void)SlipFrameDataLegacy(payload);
    }];
}


#pragma mark - Decoder: vectorized vs legacy

// SlipDecode{Vectorized,Legacy} both call the dispatch block on each complete frame.
// neither parses OSC bytes (no processOscData), so the delta IS the codec speedup.

- (void) testDecode_OSCMessagePayload_10kIterations
{
    NSData *encoded = [F53OSCParser slipFrameData:[self syntheticPayload]];
    [self measureBlock:^{
        __block NSInteger frames = 0;
        SlipFrameHandler dispatch = ^( NSData *f ) { frames++; (void)f; };
        for ( NSInteger i = 0; i < 10000; i++ )
        {
            NSMutableData *out = [NSMutableData data];
            BOOL dang = NO;
            SlipDecodeVectorized(encoded, out, &dang, dispatch);
        }
        (void)frames;
    }];
}

- (void) testDecode_OSCMessagePayload_10kIterations_Legacy
{
    NSData *encoded = [F53OSCParser slipFrameData:[self syntheticPayload]];
    [self measureBlock:^{
        __block NSInteger frames = 0;
        SlipFrameHandler dispatch = ^( NSData *f ) { frames++; (void)f; };
        for ( NSInteger i = 0; i < 10000; i++ )
        {
            NSMutableData *out = [NSMutableData data];
            BOOL dang = NO;
            SlipDecodeLegacy(encoded, out, &dang, dispatch);
        }
        (void)frames;
    }];
}

- (void) testDecode_HighSpecialDensity_10kIterations
{
    NSData *encoded = [F53OSCParser slipFrameData:[self syntheticHighDensitySpecialsPayload:256]];
    [self measureBlock:^{
        __block NSInteger frames = 0;
        SlipFrameHandler dispatch = ^( NSData *f ) { frames++; (void)f; };
        for ( NSInteger i = 0; i < 10000; i++ )
        {
            NSMutableData *out = [NSMutableData data];
            BOOL dang = NO;
            SlipDecodeVectorized(encoded, out, &dang, dispatch);
        }
        (void)frames;
    }];
}

- (void) testDecode_HighSpecialDensity_10kIterations_Legacy
{
    NSData *encoded = [F53OSCParser slipFrameData:[self syntheticHighDensitySpecialsPayload:256]];
    [self measureBlock:^{
        __block NSInteger frames = 0;
        SlipFrameHandler dispatch = ^( NSData *f ) { frames++; (void)f; };
        for ( NSInteger i = 0; i < 10000; i++ )
        {
            NSMutableData *out = [NSMutableData data];
            BOOL dang = NO;
            SlipDecodeLegacy(encoded, out, &dang, dispatch);
        }
        (void)frames;
    }];
}


#pragma mark - Roundtrip + correctness sanity

// Spot-check: encode + decode produces a delivered OSC message. Not perf-measured.
// (The decoder calls processOscData: on each fully-framed packet, which parses the
// bytes back into an F53OSCMessage and dispatches via the destination protocol.)
- (void) testRoundtripDeliversOSCMessage
{
    NSData *payload = [self syntheticPayload];
    NSData *encoded = [F53OSCParser slipFrameData:payload];

    // translateSlipData: requires state[@"socket"] to be non-nil. Supply a dummy.
    F53OSCSocket *dummySocket = [F53OSCSocket outboundTcpSocketWithCallbackQueue:dispatch_get_main_queue()];
    NSMutableData *out = [NSMutableData data];
    NSMutableDictionary *state = [@{ @"dangling_ESC" : @NO,
                                     @"socket"       : dummySocket } mutableCopy];
    CodecCapture *capture = [[CodecCapture alloc] init];
    [F53OSCParser translateSlipData:encoded
                             toData:out
                          withState:state
                        destination:capture
                     controlHandler:nil];

    XCTAssertEqual(capture.count, 1, @"Roundtrip should deliver exactly one OSC message");
}

@end

NS_ASSUME_NONNULL_END
