//
//  main.m
//  F53OSCBench
//
//  Copyright (c) 2026 Figure 53 LLC.  https://figure53.com
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
#import "F53OSC.h"

// MARK: - Constants

static const NSInteger kThroughputMessageCount  = 10000;
static const NSInteger kWarmupCount             = 100;
static const NSInteger kConcurrencyClientCount  = 10;
static const NSInteger kConcurrencyMsgPerClient = 1000;
static const NSInteger kPayloadIterations       = 10000;
static const NSInteger kBlobSize                = 65536;
static const NSInteger kBundleDepth             = 5;

// MARK: - Monotonic Clock

#include <mach/mach_time.h>

/// Returns monotonic wall-clock time in seconds using mach_continuous_time.
/// Unlike CFAbsoluteTimeGetCurrent, this is not affected by NTP adjustments.
static double monotonicTimeSeconds(void)
{
    static mach_timebase_info_data_t timebase;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mach_timebase_info(&timebase);
    });
    uint64_t time = mach_continuous_time();
    uint64_t nanos = time * timebase.numer / timebase.denom;
    return (double)nanos / 1e9;
}

// Fixed port reused across tests. F53OSCSocket listeners set
// nw_parameters_set_reuse_local_address, so stop/start on the same port works.
static const UInt16 kBasePort = 53100;

// MARK: - BenchDelegate

/// Delegate that counts received messages for throughput/concurrency benchmarks.
@interface BenchDelegate : NSObject <F53OSCPacketDestination, F53OSCServerDelegate>

@property (atomic, assign) NSInteger receivedCount;
@property (atomic, assign) NSInteger targetCount;
@property (atomic, assign) BOOL done;

- (void)resetWithTarget:(NSInteger)target;
- (NSInteger)waitUntilDoneOrTimeout:(NSTimeInterval)timeout;

@end

@implementation BenchDelegate

- (instancetype)init
{
    self = [super init];
    if ( self )
    {
        _receivedCount = 0;
        _targetCount = 0;
        _done = NO;
    }
    return self;
}

- (void)resetWithTarget:(NSInteger)target
{
    self.receivedCount = 0;
    self.targetCount = target;
    self.done = NO;
}

- (void)takeMessage:(nullable F53OSCMessage *)message
{
    self.receivedCount++;
    if ( self.receivedCount >= self.targetCount )
        self.done = YES;
}

- (NSInteger)waitUntilDoneOrTimeout:(NSTimeInterval)timeout
{
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    while ( !self.done && [deadline timeIntervalSinceNow] > 0 )
        usleep(100); // 0.1ms spin - delegate callbacks arrive on background queue
    return self.receivedCount;
}

@end

// MARK: - ReplyDelegate

/// Delegate that counts received reply messages, optionally filtered by address.
@interface ReplyDelegate : NSObject <F53OSCPacketDestination, F53OSCClientDelegate, F53OSCServerDelegate>

@property (atomic, assign) NSInteger receivedCount;
@property (nonatomic, copy, nullable) NSString *addressFilter;

- (void)resetCount;

@end

@implementation ReplyDelegate

- (instancetype)initWithAddressFilter:(nullable NSString *)filter
{
    self = [super init];
    if ( self )
    {
        _receivedCount = 0;
        _addressFilter = [filter copy];
    }
    return self;
}

- (void)resetCount
{
    self.receivedCount = 0;
}

- (void)takeMessage:(nullable F53OSCMessage *)message
{
    if ( self.addressFilter && ![message.addressPattern isEqualToString:self.addressFilter] )
        return;
    self.receivedCount++;
}

@end

// MARK: - Formatting Helpers

static NSString *formattedNumber(NSInteger value)
{
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US"];
    return [formatter stringFromNumber:@(value)];
}

static NSString *formattedBytes(double bytes)
{
    if ( bytes >= 1e9 )
        return [NSString stringWithFormat:@"%.2f GB", bytes / 1e9];
    if ( bytes >= 1e6 )
        return [NSString stringWithFormat:@"%.1f MB", bytes / 1e6];
    if ( bytes >= 1e3 )
        return [NSString stringWithFormat:@"%.0f KB", bytes / 1e3];
    return [NSString stringWithFormat:@"%.0f bytes", bytes];
}

static NSString *formattedBytesPerSec(double bytesPerSec)
{
    return [NSString stringWithFormat:@"%@/sec", formattedBytes(bytesPerSec)];
}

static void printResult(NSString *name, NSInteger messageCount, double elapsed, int64_t totalBytes)
{
    double throughput = (elapsed > 0) ? (double)messageCount / elapsed : 0;
    double bandwidth = (elapsed > 0) ? (double)totalBytes / elapsed : 0;

    printf("\n");
    printf("  %s\n", name.UTF8String);

    NSString *dashes = [@"" stringByPaddingToLength:name.length withString:@"-" startingAtIndex:0];
    printf("  %s\n", dashes.UTF8String);
    printf("  Messages:     %s\n", formattedNumber(messageCount).UTF8String);
    printf("  Total time:   %.3fs\n", elapsed);
    printf("  Throughput:   %.0f msg/sec\n", throughput);
    if ( totalBytes > 0 )
    {
        printf("  Bandwidth:    %s\n", formattedBytesPerSec(bandwidth).UTF8String);
        printf("  Total bytes:  %s\n", formattedBytes(totalBytes).UTF8String);
    }
}

static void printHeader(NSString *title)
{
    NSString *header = [NSString stringWithFormat:@"F53OSCBench -- %@ (nw_connection_t)", title];
    printf("\n%s\n", header.UTF8String);

    NSString *separator = [@"" stringByPaddingToLength:50 withString:@"=" startingAtIndex:0];
    printf("%s\n", separator.UTF8String);
}

// MARK: - Helpers

static UInt16 actualPort(F53OSCServer *server)
{
    return server.port;
}

// MARK: - Throughput Benchmark

static void runThroughput(BOOL useTcp)
{
    @autoreleasepool
    {
        NSString *transport = useTcp ? @"TCP" : @"UDP";
        NSString *label = [NSString stringWithFormat:@"Throughput (%@, nw_connection_t)", transport];

        // Create server with a background delegate queue so socket I/O
        // isn't blocked by the main queue in this command-line tool.
        dispatch_queue_t serverQueue = dispatch_queue_create("com.figure53.F53OSCBench.server", DISPATCH_QUEUE_SERIAL);
        BenchDelegate *delegate = [[BenchDelegate alloc] init];
        F53OSCServer *server = [[F53OSCServer alloc] initWithDelegateQueue:serverQueue];
        server.port = kBasePort;
        server.delegate = delegate;

        if ( ![server startListening] )
        {
            printf("  ERROR: Failed to start server for %s throughput test.\n", transport.UTF8String);
            return;
        }

        UInt16 port = actualPort(server);

        // Create client with a background delegate queue so socket
        // callbacks don't deadlock against the main thread send loop.
        dispatch_queue_t clientQueue = dispatch_queue_create("com.figure53.F53OSCBench.client", DISPATCH_QUEUE_SERIAL);
        F53OSCClient *client = [[F53OSCClient alloc] init];
        client.socketDelegateQueue = clientQueue;
        client.host = @"127.0.0.1";
        client.port = port;
        client.useTcp = useTcp;

        if ( useTcp )
        {
            [client connect];
            usleep(200000); // 200ms for TCP handshake
        }

        // Build test message
        F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:@"/bench/throughput"
                                                                arguments:@[@(42), @(3.14f), @"benchmark"]];
        NSData *packetData = [message packetData];
        int64_t encodedSize = (int64_t)[packetData length];

        // Warmup
        [delegate resetWithTarget:kWarmupCount];
        for ( NSInteger i = 0; i < kWarmupCount; i++ )
            [client sendPacket:message];
        [delegate waitUntilDoneOrTimeout:5.0];

        // Timed run
        [delegate resetWithTarget:kThroughputMessageCount];

        double start = monotonicTimeSeconds();

        for ( NSInteger i = 0; i < kThroughputMessageCount; i++ )
            [client sendPacket:message];

        NSInteger received = [delegate waitUntilDoneOrTimeout:5.0];

        double elapsed = monotonicTimeSeconds() - start;

        if ( received < kThroughputMessageCount )
            printf("  Received %ld of %ld messages within timeout.\n",
                   (long)received, (long)kThroughputMessageCount);

        int64_t totalBytes = (int64_t)received * encodedSize;
        printResult(label, received, elapsed, totalBytes);

        // Cleanup: stop server first, then disconnect client, then
        // let background queues drain before the autoreleasepool tears
        // down the objects.
        [server stopListening];
        [client disconnect];
        usleep(500000);
    }
}

// MARK: - Concurrency Benchmark

static void runConcurrency(void)
{
    @autoreleasepool
    {
        NSInteger totalMessages = kConcurrencyClientCount * kConcurrencyMsgPerClient;
        NSString *label = [NSString stringWithFormat:@"Concurrency (%ld clients x %ld msgs, TCP, nw_connection_t)",
                           (long)kConcurrencyClientCount, (long)kConcurrencyMsgPerClient];

        // Create server with a background delegate queue.
        dispatch_queue_t serverQueue = dispatch_queue_create("com.figure53.F53OSCBench.server", DISPATCH_QUEUE_SERIAL);
        BenchDelegate *delegate = [[BenchDelegate alloc] init];
        F53OSCServer *server = [[F53OSCServer alloc] initWithDelegateQueue:serverQueue];
        server.port = kBasePort;
        server.delegate = delegate;

        if ( ![server startListening] )
        {
            printf("  ERROR: Failed to start server for concurrency test.\n");
            return;
        }

        UInt16 port = actualPort(server);

        // Build test message
        F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:@"/bench/concurrency"
                                                                arguments:@[@(1), @"test"]];
        NSData *packetData = [message packetData];
        int64_t encodedSize = (int64_t)[packetData length];

        // Create and connect clients with background delegate queues
        NSMutableArray<F53OSCClient *> *clients = [NSMutableArray arrayWithCapacity:kConcurrencyClientCount];
        for ( NSInteger i = 0; i < kConcurrencyClientCount; i++ )
        {
            dispatch_queue_t clientQueue = dispatch_queue_create("com.figure53.F53OSCBench.client", DISPATCH_QUEUE_SERIAL);
            F53OSCClient *client = [[F53OSCClient alloc] init];
            client.socketDelegateQueue = clientQueue;
            client.host = @"127.0.0.1";
            client.port = port;
            client.useTcp = YES;
            [client connect];
            [clients addObject:client];
        }
        usleep(300000); // 300ms for all TCP handshakes

        // Warmup
        [delegate resetWithTarget:kConcurrencyClientCount * 10];
        for ( F53OSCClient *client in clients )
        {
            for ( NSInteger i = 0; i < 10; i++ )
                [client sendPacket:message];
        }
        [delegate waitUntilDoneOrTimeout:5.0];

        // Timed run
        [delegate resetWithTarget:totalMessages];

        double start = monotonicTimeSeconds();

        for ( F53OSCClient *client in clients )
        {
            for ( NSInteger i = 0; i < kConcurrencyMsgPerClient; i++ )
                [client sendPacket:message];
        }

        NSInteger received = [delegate waitUntilDoneOrTimeout:5.0];

        double elapsed = monotonicTimeSeconds() - start;

        if ( received < totalMessages )
            printf("  Received %ld of %ld messages within timeout.\n",
                   (long)received, (long)totalMessages);

        int64_t totalBytes = (int64_t)received * encodedSize;
        printResult(label, received, elapsed, totalBytes);

        // Cleanup
        [server stopListening];
        for ( F53OSCClient *client in clients )
            [client disconnect];
        usleep(500000);
    }
}

// MARK: - Payload Benchmark

static void benchEncodeDecode(NSString *label, F53OSCPacket *packet)
{
    @autoreleasepool
    {
        NSData *encoded = [packet packetData];
        if ( !encoded )
        {
            printf("  %s: failed to encode\n", label.UTF8String);
            return;
        }
        int64_t encodedSize = (int64_t)[encoded length];

        // Encode
        double encodeStart = monotonicTimeSeconds();
        for ( NSInteger i = 0; i < kPayloadIterations; i++ )
        {
            @autoreleasepool
            {
                (void)[packet packetData];
            }
        }
        double encodeElapsed = monotonicTimeSeconds() - encodeStart;

        NSString *encodeLabel = [NSString stringWithFormat:@"%@ - encode (nw_connection_t)", label];
        printResult(encodeLabel, kPayloadIterations, encodeElapsed, (int64_t)kPayloadIterations * encodedSize);

        // Decode
        double decodeStart = monotonicTimeSeconds();
        for ( NSInteger i = 0; i < kPayloadIterations; i++ )
        {
            @autoreleasepool
            {
                (void)[F53OSCParser packetFromData:encoded];
            }
        }
        double decodeElapsed = monotonicTimeSeconds() - decodeStart;

        NSString *decodeLabel = [NSString stringWithFormat:@"%@ - decode (nw_connection_t)", label];
        printResult(decodeLabel, kPayloadIterations, decodeElapsed, (int64_t)kPayloadIterations * encodedSize);
    }
}

static void runPayload(void)
{
    @autoreleasepool
    {
        // 1. Minimal message (address only, no args)
        F53OSCMessage *minimal = [F53OSCMessage messageWithAddressPattern:@"/bench/minimal"
                                                                arguments:@[]];
        benchEncodeDecode(@"Minimal message (no args)", minimal);

        // 2. Typical message (int + float + string)
        F53OSCMessage *typical = [F53OSCMessage messageWithAddressPattern:@"/bench/typical"
                                                                arguments:@[@(42), @(3.14f), @"hello world"]];
        benchEncodeDecode(@"Typical message (int + float + string)", typical);

        // 3. Large blob (64 KB)
        NSMutableData *blobData = [NSMutableData dataWithLength:kBlobSize];
        memset(blobData.mutableBytes, 0xAB, kBlobSize);
        F53OSCMessage *blobMsg = [F53OSCMessage messageWithAddressPattern:@"/bench/blob"
                                                                arguments:@[blobData]];
        NSString *blobLabel = [NSString stringWithFormat:@"Large blob (%@)", formattedBytes(kBlobSize)];
        benchEncodeDecode(blobLabel, blobMsg);

        // 4. Large bundle (100 messages)
        NSMutableArray<NSData *> *bundleElements = [NSMutableArray arrayWithCapacity:100];
        for ( NSInteger i = 0; i < 100; i++ )
        {
            NSString *addr = [NSString stringWithFormat:@"/bench/bundle/%ld", (long)i];
            F53OSCMessage *msg = [F53OSCMessage messageWithAddressPattern:addr
                                                                arguments:@[@(i)]];
            NSData *msgData = [msg packetData];
            if ( msgData )
                [bundleElements addObject:msgData];
        }
        F53OSCTimeTag *timeTag = [F53OSCTimeTag immediateTimeTag];
        F53OSCBundle *largeBundle = [F53OSCBundle bundleWithTimeTag:timeTag elements:bundleElements];
        benchEncodeDecode(@"Large bundle (100 messages)", largeBundle);

        // 5. Nested bundles (depth 5)
        F53OSCMessage *innerMsg = [F53OSCMessage messageWithAddressPattern:@"/bench/nested"
                                                                 arguments:@[@(1)]];
        NSData *innerData = [innerMsg packetData];
        F53OSCBundle *nested = [F53OSCBundle bundleWithTimeTag:timeTag elements:@[innerData]];
        for ( NSInteger d = 1; d < kBundleDepth; d++ )
        {
            NSData *nestedData = [nested packetData];
            if ( !nestedData )
            {
                printf("  Nested bundles: failed to encode at depth %ld\n", (long)d);
                return;
            }
            nested = [F53OSCBundle bundleWithTimeTag:timeTag elements:@[nestedData]];
        }
        NSString *nestedLabel = [NSString stringWithFormat:@"Nested bundles (depth %ld)", (long)kBundleDepth];
        benchEncodeDecode(nestedLabel, nested);
    }
}

// MARK: - Remote Benchmark

static void runRemote(NSString *host, UInt16 port, NSInteger count, BOOL useTcp,
                      NSString *addressPattern, BOOL waitForReply,
                      NSString *replyAddress, NSString * _Nullable qlabPasscode,
                      UInt16 udpReplyPort, double targetRate)
{
    @autoreleasepool
    {
        NSString *transport = useTcp ? @"TCP" : @"UDP";
        NSString *mode = waitForReply ? @"round-trip" : @"send-only";
        NSString *label = [NSString stringWithFormat:@"Remote %@ (%@, nw_connection_t)", mode, transport];

        printHeader([NSString stringWithFormat:@"Remote %@", mode]);
        printf("  Target: %s:%u (%s)\n", host.UTF8String, port, transport.UTF8String);
        printf("  Message: %s\n", addressPattern.UTF8String);

        // Create client
        dispatch_queue_t clientQueue = dispatch_queue_create("com.figure53.F53OSCBench.client", DISPATCH_QUEUE_SERIAL);
        F53OSCClient *client = [[F53OSCClient alloc] init];
        client.socketDelegateQueue = clientQueue;
        client.host = host;
        client.port = port;
        client.useTcp = useTcp;

        // For round-trip, set up reply counting.
        // TCP: set delegate on the client to receive replies on the same connection.
        // UDP: start a local server on udpReplyPort.
        ReplyDelegate *replyDelegate = nil;
        F53OSCServer *replyServer = nil;

        if ( waitForReply && !useTcp )
        {
            dispatch_queue_t serverQueue = dispatch_queue_create("com.figure53.F53OSCBench.reply", DISPATCH_QUEUE_SERIAL);
            replyDelegate = [[ReplyDelegate alloc] initWithAddressFilter:replyAddress];
            replyServer = [[F53OSCServer alloc] initWithDelegateQueue:serverQueue];
            replyServer.port = udpReplyPort;
            replyServer.delegate = replyDelegate;
            NSError *listenError = nil;
            if ( ![replyServer startListening:&listenError] )
            {
                printf("  ERROR: Failed to start reply server on port %u: %s\n",
                       udpReplyPort, listenError.localizedDescription.UTF8String);
                return;
            }
            printf("  Reply port: %u (UDP + TCP)\n", replyServer.port);
        }

        if ( waitForReply && useTcp )
        {
            replyDelegate = [[ReplyDelegate alloc] initWithAddressFilter:replyAddress];
            client.delegate = replyDelegate;
        }

        if ( useTcp )
        {
            [client connect];
            // Pump the run loop to let the TCP handshake complete.
            // F53OSCClient delivers delegate callbacks on the main queue.
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.2, false);
        }

        // QLab handshake
        if ( qlabPasscode )
        {
            F53OSCMessage *connectMsg = [F53OSCMessage messageWithAddressPattern:@"/connect"
                                                                       arguments:@[qlabPasscode]];
            [client sendPacket:connectMsg];
            printf("  Sent /connect \"%s\"\n", qlabPasscode.UTF8String);

            F53OSCMessage *alwaysReplyMsg = [F53OSCMessage messageWithAddressPattern:@"/alwaysReply"
                                                                           arguments:@[@(1)]];
            [client sendPacket:alwaysReplyMsg];
            printf("  Sent /alwaysReply 1\n");

            if ( waitForReply && !useTcp )
            {
                F53OSCMessage *replyPortMsg = [F53OSCMessage messageWithAddressPattern:@"/udpReplyPort"
                                                                             arguments:@[@(udpReplyPort)]];
                [client sendPacket:replyPortMsg];
                printf("  Sent /udpReplyPort %u\n", udpReplyPort);
            }

            // Pump the run loop to let handshake replies settle
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.5, false);
        }

        // Reset reply counter so handshake replies aren't counted
        [replyDelegate resetCount];

        // Estimate encoded size
        F53OSCMessage *sampleMessage = [F53OSCMessage messageWithAddressPattern:addressPattern
                                                                      arguments:@[@(1)]];
        int64_t encodedSize = (int64_t)[[sampleMessage packetData] length];

        // Timed run: send unique messages to avoid dedup throttling.
        // Yield to the run loop periodically so that main-queue
        // delegate callbacks (e.g. TCP reply delivery) can fire.
        if ( targetRate > 0 )
            printf("  Rate limit: %.0f msg/sec\n", targetRate);

        double sendInterval = (targetRate > 0) ? (1.0 / targetRate) : 0;
        NSInteger progressInterval = (targetRate > 0) ? MAX((NSInteger)targetRate, 1) : 1000;
        double start = monotonicTimeSeconds();

        for ( NSInteger i = 0; i < count; i++ )
        {
            F53OSCMessage *msg = [F53OSCMessage messageWithAddressPattern:addressPattern
                                                                arguments:@[@(i + 1)]];
            [client sendPacket:msg];

            if ( sendInterval > 0 )
            {
                // Pace sends by pumping the run loop for the remaining interval.
                // This also allows delegate callbacks to fire between sends.
                double nextSendTime = start + (double)(i + 1) * sendInterval;
                double remaining = nextSendTime - monotonicTimeSeconds();
                if ( remaining > 0 )
                    CFRunLoopRunInMode(kCFRunLoopDefaultMode, remaining, false);
            }
            else if ( (i + 1) % 100 == 0 )
            {
                CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, false);
            }

            if ( (i + 1) % progressInterval == 0 )
            {
                double elapsed = monotonicTimeSeconds() - start;
                double currentRate = (double)(i + 1) / elapsed;
                printf("  [%ld/%ld] %.0f msg/sec\n", (long)(i + 1), (long)count, currentRate);
            }
        }

        // Wait for replies, pumping the run loop so main-queue
        // delegate callbacks are delivered.
        if ( waitForReply && replyDelegate )
        {
            double maxWait = 30.0;
            NSInteger stallLimit = 10; // 10 x 500ms = 5s with no progress
            double waitStart = monotonicTimeSeconds();
            NSInteger lastCount = 0;
            NSInteger stalledCycles = 0;

            while ( YES )
            {
                CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.5, false);
                NSInteger current = replyDelegate.receivedCount;
                if ( current >= count )
                    break;

                double waited = monotonicTimeSeconds() - waitStart;
                if ( waited > maxWait )
                {
                    printf("  Replies: %ld/%ld (max wait of 30s reached)\n", (long)current, (long)count);
                    break;
                }

                if ( current == lastCount )
                {
                    stalledCycles++;
                    double stallRemaining = (double)(stallLimit - stalledCycles) * 0.5;
                    printf("  Replies: %ld/%ld (no progress, %.0fs until timeout)\n", (long)current, (long)count, stallRemaining);
                    if ( stalledCycles >= stallLimit )
                        break;
                }
                else
                {
                    stalledCycles = 0;
                    printf("  Replies: %ld/%ld (%.1fs elapsed)\n", (long)current, (long)count, waited);
                }
                lastCount = current;
            }

            NSInteger replyCount = replyDelegate.receivedCount;
            double elapsed = monotonicTimeSeconds() - start;

            int64_t totalBytes = (int64_t)count * encodedSize;
            printResult(label, count, elapsed, totalBytes);
            printf("  Replies:      %ld/%ld (%.1f%%)\n", (long)replyCount, (long)count,
                   (double)replyCount / (double)count * 100.0);
        }
        else
        {
            double elapsed = monotonicTimeSeconds() - start;
            int64_t totalBytes = (int64_t)count * encodedSize;
            printResult(label, count, elapsed, totalBytes);
        }

        // Disconnect from QLab session before tearing down the connection.
        // Without this, QLab keeps the session alive (especially over UDP)
        // and rejects subsequent /connect attempts.
        if ( qlabPasscode )
        {
            F53OSCMessage *disconnectMsg = [F53OSCMessage messageWithAddressPattern:@"/disconnect"
                                                                          arguments:@[]];
            [client sendPacket:disconnectMsg];
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.2, false);
        }

        // Cleanup: disconnect client, stop reply server, then pump
        // the run loop to let GCD delegate queues drain and sockets
        // fully close before the autoreleasepool tears down objects.
        [client disconnect];
        [replyServer stopListening];
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 1.0, false);
    }
}

// MARK: - Argument Parsing Helpers

static NSString * _Nullable argValue(int argc, const char *argv[], NSString *flag)
{
    for ( int i = 1; i < argc - 1; i++ )
    {
        if ( [flag isEqualToString:@(argv[i])] )
            return @(argv[i + 1]);
    }
    return nil;
}

static BOOL argPresent(int argc, const char *argv[], NSString *flag)
{
    for ( int i = 1; i < argc; i++ )
    {
        if ( [flag isEqualToString:@(argv[i])] )
            return YES;
    }
    return NO;
}

// MARK: - Main

int main(int argc, const char *argv[])
{
    @autoreleasepool
    {
        NSString *subcommand = (argc > 1) ? @(argv[1]) : @"all";

        if ( [subcommand isEqualToString:@"remote"] )
        {
            NSString *host = argValue(argc, argv, @"--host") ?: @"127.0.0.1";
            UInt16 port = (UInt16)[argValue(argc, argv, @"--port") ?: @"53000" integerValue];
            NSInteger count = [argValue(argc, argv, @"--count") ?: @"10000" integerValue];
            BOOL useTcp = argPresent(argc, argv, @"--tcp");
            NSString *message = argValue(argc, argv, @"--message") ?: @"/thump";
            BOOL reply = argPresent(argc, argv, @"--reply");
            NSString *replyAddress = argValue(argc, argv, @"--reply-address") ?: [NSString stringWithFormat:@"/reply%@", message];
            NSString *qlabPasscode = argValue(argc, argv, @"--qlab");
            UInt16 udpReplyPort = (UInt16)[argValue(argc, argv, @"--udp-reply-port") ?: @"53001" integerValue];
            double targetRate = [argValue(argc, argv, @"--rate") ?: @"0" doubleValue];
            // --qlab implies --reply
            if ( qlabPasscode )
                reply = YES;

            runRemote(host, port, count, useTcp, message, reply, replyAddress, qlabPasscode, udpReplyPort, targetRate);
        }
        else
        {
            // Run all loopback benchmarks

            // Payload (no networking)
            printHeader(@"Payload");
            runPayload();

            printHeader(@"Throughput");
            runThroughput(NO);  // UDP
            runThroughput(YES); // TCP

            // Concurrency (TCP)
            printHeader(@"Concurrency");
            runConcurrency();

            printf("\n");
        }
    }
    return 0;
}
