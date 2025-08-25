//
//  F53OSC_BrowserTests.m
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

#import "F53OSCBrowser.h"


NS_ASSUME_NONNULL_BEGIN

@interface F53OSCBrowser (F53OSC_BrowserTestsAccess) <NSNetServiceBrowserDelegate, NSNetServiceDelegate>
@property (nonatomic, strong, nullable)         NSNetServiceBrowser *netServiceDomainsBrowser;
@property (nonatomic, strong, nullable)         NSNetServiceBrowser *netServiceBrowser;
- (void)setNeedsBeginResolvingNetServices;
- (void)beginResolvingNetServices;
- (nullable F53OSCClientRecord *)clientRecordForHost:(NSString *)host port:(UInt16)port;
- (nullable F53OSCClientRecord *)clientRecordForNetService:(NSNetService *)netService;
+ (nullable NSString *)IPAddressFromData:(NSData *)data resolveIPv6Addresses:(BOOL)resolveIPv6Addresses;
@end


#pragma mark -

@interface F53OSC_BrowserTests : XCTestCase <F53OSCBrowserDelegate>
@end


@implementation F53OSC_BrowserTests

//- (void)setUp
//{
//    [super setUp];
//}

//- (void)tearDown
//{
//    [super tearDown];
//}


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

- (void)testThat_clientRecordHasCorrectDefaults
{
    F53OSCClientRecord *record = [[F53OSCClientRecord alloc] init];

    XCTAssertNotNil(record, @"Client record should not be nil");
    XCTAssertEqual(record.port, 0, @"Default port should be 0");
    XCTAssertFalse(record.useTCP, @"Default should not use TCP");
    XCTAssertNotNil(record.hostAddresses, @"Default hostAddresses should not be nil");
    XCTAssertEqual(record.hostAddresses.count, 0, @"Default hostAddresses should initially be empty");
    XCTAssertNil(record.netService, @"Default netService should be nil");
}

- (void)testThat_clientRecordCanBeCopied
{
    F53OSCClientRecord *original = [[F53OSCClientRecord alloc] init];
    original.port = 8000;
    original.useTCP = YES;
    original.hostAddresses = @[@"192.168.1.100", @"10.0.1.5"];

    F53OSCClientRecord *copy = [original copy];

    XCTAssertNotNil(copy, @"Copy should not be nil");
    XCTAssertNotEqual(copy, original, @"Copy should be a different object");
    XCTAssertEqual(copy.port, original.port, @"port should be copied");
    XCTAssertEqual(copy.useTCP, original.useTCP, @"useTCP setting should be copied");
    XCTAssertEqualObjects(copy.hostAddresses, original.hostAddresses, @"hostAddresses should be copied");
    XCTAssertNil(copy.netService, @"Copy netService should be nil");
}

- (void)testThat_browserHasCorrectDefaults
{
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];

    XCTAssertNotNil(browser, @"Browser should not be nil");
    XCTAssertNotNil(browser.clientRecords, @"Default clientRecords should not be nil");
    XCTAssertEqual(browser.clientRecords.count, 0, @"Default clientRecords should be empty");
    XCTAssertFalse(browser.running, @"Default should not be running");
    XCTAssertTrue(browser.useTCP, @"Default useTCP should be YES");
    XCTAssertFalse(browser.resolveIPv6Addresses, @"Default resolveIPv6Addresses be NO");
    XCTAssertEqualObjects(browser.domain, @"local.", @"Default domain should be 'local.'");
    XCTAssertEqualObjects(browser.serviceType, @"", @"Default serviceType should be empty");
    XCTAssertNil(browser.delegate, @"Default delegate should be nil");

    XCTAssertNil(browser.netServiceDomainsBrowser.delegate, @"Browser netServiceDomainsBrowser delegate should be nil util started");
    XCTAssertNil(browser.netServiceBrowser.delegate, @"Browser netServiceBrowser delegate should be nil until netServiceBrowser finds a domain");
}

- (void)testThat_browserCanConfigureProperties
{
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];

    [self addTeardownBlock:^{
        [browser stop];
    }];

    browser.useTCP = NO;
    XCTAssertFalse(browser.useTCP, @"Browser useTCP should be NO");

    browser.resolveIPv6Addresses = YES;
    XCTAssertTrue(browser.resolveIPv6Addresses, @"Browser resolveIPv6Addresses should be YES");

    browser.domain = @"some_domain.";
    XCTAssertEqualObjects(browser.domain, @"some_domain.", @"Browser domain should be 'some_domain.'");

    browser.serviceType = @"_osc._tcp.";
    XCTAssertEqualObjects(browser.serviceType, @"_osc._tcp.", @"Browser serviceType should be '_osc._tcp.'");

    browser.delegate = self;
    XCTAssertEqualObjects(browser.delegate, self, @"Browser delegate should be self");

    // Test that properties remain unchanged when browser starts.
    [browser start];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertTrue(browser.running, @"Browser should be running");

    XCTAssertFalse(browser.useTCP, @"Browser useTCP should remain NO");
    XCTAssertTrue(browser.resolveIPv6Addresses, @"Browser resolveIPv6Addresses should remain YES");
    XCTAssertEqualObjects(browser.domain, @"some_domain.", @"Browser domain should remain 'some_domain.'");
    XCTAssertEqualObjects(browser.serviceType, @"_osc._tcp.", @"Browser serviceType should remain '_osc._tcp.'");
    XCTAssertEqualObjects(browser.delegate, self, @"Browser delegate should remain self");

    // Test toggling useTCP while running
    browser.useTCP = YES;
    XCTAssertTrue(browser.useTCP, @"Browser useTCP should be YES");

    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertTrue(browser.running, @"Browser should still be running");

    browser.useTCP = NO;
    XCTAssertFalse(browser.useTCP, @"Browser useTCP should be NO");

    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertTrue(browser.running, @"Browser should still be running");
}

- (void)testThat_browserCannotBeCopied
{
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];

    XCTAssertThrows(browser.copy, "Browser does not conform to NSCopying");
}

- (void)testThat_browserHandlesIPv6Configuration
{
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];

    // Test IPv4 only (default).
    browser.serviceType = @"_osc._tcp.";
    browser.resolveIPv6Addresses = NO;

    [browser start];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertTrue(browser.running, @"Should work with IPv4 only");

    XCTAssertFalse(browser.resolveIPv6Addresses, @"Initial resolveIPv6Addresses should remain disabled");

    [browser stop];

    // Test IPv6 enabled.
    browser.resolveIPv6Addresses = YES;

    [browser start];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertTrue(browser.running, @"Should work with IPv6 enabled");

    XCTAssertTrue(browser.resolveIPv6Addresses, @"Initial resolveIPv6Addresses should remain enabled");
}


#pragma mark - Domain tests

- (void)testThat_browserCanChangeDomains
{
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];

    [self addTeardownBlock:^{
        [browser stop];
    }];

    browser.serviceType = @"_osc._tcp.";

    // Test default domain.
    XCTAssertEqualObjects(browser.domain, @"local.", @"Should have default domain");
    XCTAssertFalse(browser.running, @"Browser should not be running");

    // Test custom domain.
    browser.domain = @"example.local.";
    XCTAssertEqualObjects(browser.domain, @"example.local.", @"Should accept custom domain");
    XCTAssertFalse(browser.running, @"Browser should not be running");

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    browser.domain = nil;
#pragma clang diagnostic pop
    XCTAssertEqualObjects(browser.domain, @"example.local.", @"nil domain should be rejected");

    // Test that changing domain while running restarts browser.
    [browser start];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertTrue(browser.running, @"Browser should be running");

    browser.domain = @"test.local.";
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertTrue(browser.running, @"Browser should still be running after domain change");

    XCTAssertEqualObjects(browser.domain, @"test.local.", @"Domain should be updated");
}

- (void)testThat_browserCannotStartWithoutDomain
{
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];

    [self addTeardownBlock:^{
        [browser stop];
    }];

    browser.serviceType = @"_osc._tcp.";

    browser.domain = @"";
    XCTAssertEqualObjects(browser.domain, @"", @"Browser domain should be empty string");
    XCTAssertFalse(browser.running, @"Browser should not be running");

    // Should not start with empty domain.
    [browser start];
    XCTAssertFalse(browser.running, @"Browser should not start without a domain");

    browser.domain = @"local.";

    // Test that browser starts with a valid domain.
    [browser start];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertTrue(browser.running, @"Browser should start with a valid domain");
}


#pragma mark - Service type tests

- (void)testThat_browserHandlesOSCServiceTypes
{
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];

    [self addTeardownBlock:^{
        [browser stop];
    }];

    // Test common OSC service types.
    NSArray<NSString *> *serviceTypes = @[
        @"_qlab._tcp.",
        @"_qlab._udp.",
        @"_gobutton._tcp.",
        @"_gobutton._udp.",
        @"_osc._tcp.",
        @"_osc._udp.",
    ];

    for (NSString *serviceType in serviceTypes)
    {
        [browser stop];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
        XCTAssertFalse(browser.running, @"Browser should not be running");

        browser.serviceType = serviceType;
        XCTAssertEqualObjects(browser.serviceType, serviceType, 
                              @"Browser should accept service type '%@'", serviceType);

        [browser start];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
        XCTAssertTrue(browser.running, @"Browser should be running with service type '%@'", serviceType);
    }
}

- (void)testThat_browserCannotStartWithoutServiceType
{
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];

    XCTAssertEqualObjects(browser.serviceType, @"", @"Default serviceType should be empty");
    XCTAssertFalse(browser.running, @"Browser should not be running");

    // Should not start with empty service type.
    [browser start];
    XCTAssertFalse(browser.running, @"Browser should not start without a service type");

    browser.serviceType = @"_osc._tcp.";

    // Test that browser starts with a valid service type.
    [browser start];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertTrue(browser.running, @"Browser should start with a valid service type");

    [browser stop];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertFalse(browser.running, @"Browser should stop when requested");
}

- (void)testThat_browserRestartsWhenServiceTypeChanges
{
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];

    [self addTeardownBlock:^{
        [browser stop];
    }];

    browser.serviceType = @"_osc._tcp.";
    XCTAssertFalse(browser.running, @"Browser should not be running");

    [browser start];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertTrue(browser.running, @"Browser should be running");

    // Change service type - should restart automatically.
    browser.serviceType = @"_osc._udp.";

    // Wait for restart.
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertTrue(browser.running, @"Browser should still be running after service type change");
    XCTAssertEqualObjects(browser.serviceType, @"_osc._udp.", @"Service type should be updated to '_osc._udp.'");
}


#pragma mark - F53OSCBrowserDelegate tests

- (void)testThat_browserDelegateMethodsAreOptional
{
    // Test that we can create a browser without implementing optional delegate methods.
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];

    [self addTeardownBlock:^{
        [browser stop];
    }];

    browser.delegate = self; // We implement the required methods.
    browser.serviceType = @"_osc._tcp.";

    // This should not crash even though we don't implement `browser:shouldAcceptNetService:`.
    [browser start];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertTrue(browser.running, @"Browser should start without optional delegate methods");
}


#pragma mark - Performance / edge case tests

- (void)testThat_browserHandlesRapidStartStop
{
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];
    browser.serviceType = @"_osc._tcp.";

    // Test rapid start/stop cycles.
    for (int i = 0; i < 5; i++)
    {
        [browser start];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        XCTAssertTrue(browser.running, @"Browser should start on iteration %d", i);

        [browser stop];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        XCTAssertFalse(browser.running, @"Browser should stop on iteration %d", i);
    }
}

- (void)testThat_browserHandlesMultipleStarts
{
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];
    browser.serviceType = @"_osc._tcp.";

    // Multiple start calls should be safe.
    [browser start];
    [browser start];
    [browser start];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertTrue(browser.running, @"Browser should be running after multiple starts");

    // Multiple stop calls should be safe.
    [browser stop];
    [browser stop];
    [browser stop];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertFalse(browser.running, @"Browser should be stopped after multiple stops");
}

- (void)testThat_browserHandlesEmptyServiceType
{
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];

    [self addTeardownBlock:^{
        [browser stop];
    }];

    // Empty service type should prevent starting.
    browser.serviceType = @"";
    [browser start];
    XCTAssertFalse(browser.running, @"Should not start with an empty service type");

    // Nil service type should also prevent starting.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    browser.serviceType = nil;
#pragma clang diagnostic pop
    [browser start];
    XCTAssertFalse(browser.running, @"Should not start with a nil service type");

    // Setting valid service type should allow starting.
    browser.serviceType = @"_osc._tcp.";
    [browser start];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertTrue(browser.running, @"Should start with valid service type");
}


#pragma mark - Memory management tests

- (void)testThat_browserCleansUpProperly
{
    // Create browser in separate scope to test cleanup.
    @autoreleasepool {
        F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];

        browser.delegate = self;
        browser.serviceType = @"_osc._tcp.";

        [browser start];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
        XCTAssertTrue(browser.running, @"Browser should be running");

        // Proper cleanup should happen automatically when browser is deallocated
        [browser stop];
    }

    // Force memory cleanup.
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];

    // If we get here without crashing, cleanup worked properly.
    XCTAssertTrue(YES, @"Browser cleanup completed without crashes");
}


#pragma mark - Service discovery and resolution tests

- (void)testThat_browserHandlesServiceResolution
{
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];
    browser.delegate = self;

    // Test needs begin resolving net services method
    XCTAssertNoThrow([browser setNeedsBeginResolvingNetServices], @"Should handle setNeedsBeginResolvingNetServices gracefully");

    // Test begin resolving net services method
    XCTAssertNoThrow([browser beginResolvingNetServices], @"Should handle beginResolvingNetServices gracefully");
}

- (void)testThat_browserHandlesClientRecordLookup
{
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];

    // Test client record lookup by host and port
    F53OSCClientRecord *record1 = [browser clientRecordForHost:@"localhost" port:8000];
    XCTAssertNil(record1, @"Should return nil for non-existent client record");

    // Test client record lookup by net service
    NSNetService *netService = [[NSNetService alloc] initWithDomain:@"local." type:@"_osc._udp" name:@"TestService" port:8001];
    F53OSCClientRecord *record2 = [browser clientRecordForNetService:netService];
    XCTAssertNil(record2, @"Should return nil for non-existent net service");
}

- (void)testThat_browserHandlesBrowserDelegateCallbacks
{
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];

    NSNetServiceBrowser *netServiceBrowser = [[NSNetServiceBrowser alloc] init];

    XCTAssertNoThrow([browser netServiceBrowserDidStopSearch:netServiceBrowser], @"Should handle netServiceBrowserDidStopSearch gracefully");

    NSError *searchError = [NSError errorWithDomain:@"TestErrorDomain" code:300 userInfo:@{NSLocalizedDescriptionKey: @"Test search error"}];
    NSDictionary *errorDict = @{NSNetServicesErrorCode: @(searchError.code)};
    XCTAssertNoThrow([browser netServiceBrowser:netServiceBrowser didNotSearch:errorDict], @"Should handle didNotSearch error gracefully");
}

- (void)testThat_browserHandlesServiceDiscoveryCallbacks
{
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];

    NSNetServiceBrowser *netServiceBrowser = [[NSNetServiceBrowser alloc] init];
    NSNetService *netService = [[NSNetService alloc] initWithDomain:@"local." type:@"_osc._udp" name:@"TestOSCService" port:8002];

    XCTAssertNoThrow([browser netServiceBrowser:netServiceBrowser didFindService:netService moreComing:NO], @"Should handle didFindService gracefully");
    XCTAssertNoThrow([browser netServiceBrowser:netServiceBrowser didRemoveService:netService moreComing:NO], @"Should handle didRemoveService gracefully");
}

- (void)testThat_browserHandlesNetServiceResolutionCallbacks
{
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];

    NSNetService *netService = [[NSNetService alloc] initWithDomain:@"local." type:@"_osc._udp" name:@"ResolveTestService" port:8003];

    XCTAssertNoThrow([browser netServiceDidResolveAddress:netService], @"Should handle netServiceDidResolveAddress gracefully");

    NSError *resolveError = [NSError errorWithDomain:@"TestErrorDomain" code:400 userInfo:@{NSLocalizedDescriptionKey: @"Test resolve error"}];
    NSDictionary *errorDict = @{NSNetServicesErrorCode: @(resolveError.code)};
    XCTAssertNoThrow([browser netService:netService didNotResolve:errorDict], @"Should handle didNotResolve error gracefully");
}


#pragma mark - IPAddressFromData:resolveIPv6Addresses: tests

- (void)testThat_browserIPAddressFromDataHandlesValidData
{
    NSData *data;
    NSString *address;

    // Test IPv4 address parsing
    struct sockaddr_in ipv4Addr;
    memset(&ipv4Addr, 0, sizeof(ipv4Addr));
    ipv4Addr.sin_family = AF_INET;
    ipv4Addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK); // 127.0.0.1
    ipv4Addr.sin_port = htons(8004);
    data = [NSData dataWithBytes:&ipv4Addr length:sizeof(ipv4Addr)];
    address = [F53OSCBrowser IPAddressFromData:data resolveIPv6Addresses:NO];
    XCTAssertNotNil(address, @"Should parse IPv4 address");
    XCTAssertTrue([address containsString:@"127.0.0.1"], @"Should contain localhost address");
    address = [F53OSCBrowser IPAddressFromData:data resolveIPv6Addresses:YES];
    XCTAssertNotNil(address, @"Should parse IPv4 address even when resolveIPv6Addresses is YES");

    // Test IPv6 address parsing
    struct sockaddr_in6 ipv6Addr;
    memset(&ipv6Addr, 0, sizeof(ipv6Addr));
    ipv6Addr.sin6_family = AF_INET6;
    ipv6Addr.sin6_addr = in6addr_loopback; // ::1
    ipv6Addr.sin6_port = htons(8005);
    data = [NSData dataWithBytes:&ipv6Addr length:sizeof(ipv6Addr)];

    address = [F53OSCBrowser IPAddressFromData:data resolveIPv6Addresses:NO];
    XCTAssertNil(address, @"Should not parse IPv6 address when resolveIPv6Addresses is NO");
    address = [F53OSCBrowser IPAddressFromData:data resolveIPv6Addresses:YES];
    XCTAssertNotNil(address, @"Should parse IPv6 address when resolveIPv6Addresses is YES");
}

- (void)testThat_browserIPAddressFromDataHandlesInvalidData
{
    // Test with nil data
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    NSString *nilAddress = [F53OSCBrowser IPAddressFromData:nil resolveIPv6Addresses:NO];
#pragma clang diagnostic pop
    XCTAssertNil(nilAddress, @"Should return nil for nil data");

    NSData *data;
    NSString *address;

    // Test with malformed data
    data = [@"not_an_address" dataUsingEncoding:NSUTF8StringEncoding];
    address = [F53OSCBrowser IPAddressFromData:data resolveIPv6Addresses:NO];
    XCTAssertNil(address, @"Should return nil for malformed IPv4 data");
    address = [F53OSCBrowser IPAddressFromData:data resolveIPv6Addresses:YES];
    XCTAssertNil(address, @"Should return nil for malformed IPv6 data");

    // Test with empty data
    data = [NSData data];
    address = [F53OSCBrowser IPAddressFromData:data resolveIPv6Addresses:NO];
    XCTAssertNil(address, @"Should return nil for malformed IPv4 data");
    address = [F53OSCBrowser IPAddressFromData:data resolveIPv6Addresses:YES];
    XCTAssertNil(address, @"Should return nil for malformed IPv6 data");

    // Test with truncated sockaddr_in structure
    // Too short - missing required fields
    data = [NSData dataWithBytes:(char[]){AF_INET, 0} length:2];
    address = [F53OSCBrowser IPAddressFromData:data resolveIPv6Addresses:NO];
    XCTAssertNil(address, @"Should return nil for truncated sockaddr_in structure");

    // Misaligned data that doesn't properly represent a sockaddr_in
    // Leave rest uninitialized or with invalid values
    char bytes[sizeof(struct sockaddr_in)] = {AF_INET};
    data = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    address = [F53OSCBrowser IPAddressFromData:data resolveIPv6Addresses:NO];
    XCTAssertNil(address, @"Should return nil for misaligned data");

    // Test with truncated sockaddr_in6 structure
    data = [NSData dataWithBytes:(char[]){0, 0, AF_INET6} length:3];
    address = [F53OSCBrowser IPAddressFromData:data resolveIPv6Addresses:YES];
    XCTAssertNil(address, @"Should return nil for truncated sockaddr_in structure");
}


#pragma mark - F53OSCBrowserDelegate

- (void)browser:(F53OSCBrowser *)browser didAddClientRecord:(F53OSCClientRecord *)clientRecord
{
}

- (void)browser:(F53OSCBrowser *)browser didRemoveClientRecord:(F53OSCClientRecord *)clientRecord
{
}

// NOTE: By not implementing `browser:shouldAcceptNetService:`,
// we can test that the browser works without optional delegate methods.

@end

NS_ASSUME_NONNULL_END
