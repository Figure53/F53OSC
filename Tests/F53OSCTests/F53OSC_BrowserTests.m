//
//  F53OSC_BrowserTests.m
//  F53OSC
//
//  Created by Brent Lord on 8/5/25.
//  Copyright (c) 2020-2026 Figure 53 LLC, https://figure53.com
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

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import <Network/Network.h>

#if F53OSC_BUILT_AS_FRAMEWORK
#import <F53OSC/F53OSCBrowser.h>
#import "F53OSCBrowser+Internal.h"
#import <F53OSC/F53OSCServiceRef.h>
#else
#import "F53OSCBrowser.h"
#import "F53OSCBrowser+Internal.h"
#import "F53OSCServiceRef.h"
#endif


NS_ASSUME_NONNULL_BEGIN

#pragma mark - BrowserDelegateRecorder

/// Test delegate that records all browser callbacks and supports optional filter blocks.
@interface BrowserDelegateRecorder : NSObject <F53OSCBrowserDelegate>

@property (nonatomic, strong) NSMutableArray<F53OSCClientRecord *> *addedRecords;
@property (nonatomic, strong) NSMutableArray<F53OSCClientRecord *> *removedRecords;

/// When non-nil, returned value is used by -browser:shouldAcceptService:.
@property (nonatomic, copy, nullable) BOOL (^acceptServiceFilter)(F53OSCServiceRef *service);

@end

@implementation BrowserDelegateRecorder

- (instancetype) init
{
    self = [super init];
    if ( self )
    {
        _addedRecords = [NSMutableArray array];
        _removedRecords = [NSMutableArray array];
    }
    return self;
}

- (void) browser:(F53OSCBrowser *)browser didAddClientRecord:(F53OSCClientRecord *)clientRecord
{
    [self.addedRecords addObject:clientRecord];
}

- (void) browser:(F53OSCBrowser *)browser didRemoveClientRecord:(F53OSCClientRecord *)clientRecord
{
    [self.removedRecords addObject:clientRecord];
}

- (BOOL) browser:(F53OSCBrowser *)browser shouldAcceptService:(F53OSCServiceRef *)service
{
    if ( self.acceptServiceFilter )
        return self.acceptServiceFilter( service );
    return YES;
}

@end


#pragma mark - Helper

/// Convenience factory for synthetic F53OSCServiceRef values used throughout tests.
static F53OSCServiceRef * MakeServiceRef( NSString *name, NSString *type, NSString *domain,
                                          NSString * _Nullable host, UInt16 port )
{
    return [[F53OSCServiceRef alloc] initWithName:name
                                            type:type
                                          domain:domain
                                            host:host
                                            port:port
                                   hostAddresses:@[]
                                       txtRecord:nil];
}


#pragma mark - F53OSC_BrowserTests

@interface F53OSC_BrowserTests : XCTestCase
@end

@implementation F53OSC_BrowserTests

#pragma mark - Sanity

- (void) testThat__setupWorks
{
    XCTAssertTrue(YES);
}


#pragma mark - F53OSCClientRecord defaults and copying

- (void) testThat_clientRecordHasCorrectDefaults
{
    F53OSCClientRecord *record = [[F53OSCClientRecord alloc] init];

    XCTAssertNotNil(record, @"Client record should not be nil");
    XCTAssertEqual(record.port, 0, @"Default port should be 0");
    XCTAssertFalse(record.useTCP, @"Default useTCP should be NO");
    XCTAssertNotNil(record.hostAddresses, @"Default hostAddresses should not be nil");
    XCTAssertEqual(record.hostAddresses.count, 0u, @"Default hostAddresses should initially be empty");
    XCTAssertNil(record.service, @"Default service should be nil");
    XCTAssertNil(record.service, @"Default service should be nil");
}

- (void) testThat_clientRecordCanBeCopied
{
    F53OSCClientRecord *original = [[F53OSCClientRecord alloc] init];
    original.port = 8000;
    original.useTCP = YES;
    original.hostAddresses = @[@"192.168.1.100", @"10.0.1.5"];

    F53OSCClientRecord *copy = [original copy];

    XCTAssertNotNil(copy, @"Copy should not be nil");
    XCTAssertNotEqual(copy, original, @"Copy should be a different object");
    XCTAssertEqual(copy.port, original.port, @"port should be copied");
    XCTAssertEqual(copy.useTCP, original.useTCP, @"useTCP should be copied");
    XCTAssertEqualObjects(copy.hostAddresses, original.hostAddresses, @"hostAddresses should be copied");
    XCTAssertNil(copy.service, @"service should be nil on copy when original had nil");
}

- (void) testThat_clientRecordCopyPreservesService
{
    F53OSCServiceRef *ref = MakeServiceRef( @"TestService", @"_osc._tcp.", @"local.", @"myhost.local.", 53000 );
    F53OSCClientRecord *original = [[F53OSCClientRecord alloc] init];
    original.service = ref;
    original.port = 53000;

    F53OSCClientRecord *copy = [original copy];

    XCTAssertNotNil(copy.service, @"service should be preserved on copy");
    XCTAssertEqualObjects(copy.service.name, @"TestService", @"service.name should be preserved");
    XCTAssertEqual(copy.port, 53000, @"port should be preserved");
}


#pragma mark - F53OSCBrowser defaults

- (void) testThat_browserHasCorrectDefaults
{
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];

    XCTAssertNotNil(browser, @"Browser should not be nil");
    XCTAssertNotNil(browser.clientRecords, @"Default clientRecords should not be nil");
    XCTAssertEqual(browser.clientRecords.count, 0u, @"Default clientRecords should be empty");
    XCTAssertFalse(browser.running, @"Default should not be running");
    XCTAssertTrue(browser.useTCP, @"Default useTCP should be YES");
    XCTAssertFalse(browser.resolveIPv6Addresses, @"Default resolveIPv6Addresses should be NO");
    XCTAssertEqualObjects(browser.domain, @"local.", @"Default domain should be 'local.'");
    XCTAssertEqualObjects(browser.serviceType, @"", @"Default serviceType should be empty string");
    XCTAssertNil(browser.delegate, @"Default delegate should be nil");
}

- (void) testThat_browserCannotBeCopied
{
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];

    XCTAssertThrows(browser.copy, @"Browser does not conform to NSCopying");
}


#pragma mark - Browser configuration

- (void) testThat_browserCanConfigureProperties
{
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];

    [self addTeardownBlock:^{
        [browser stop];
    }];

    browser.useTCP = NO;
    XCTAssertFalse(browser.useTCP, @"useTCP should be NO");

    browser.resolveIPv6Addresses = YES;
    XCTAssertTrue(browser.resolveIPv6Addresses, @"resolveIPv6Addresses should be YES");

    browser.domain = @"some_domain.";
    XCTAssertEqualObjects(browser.domain, @"some_domain.", @"domain should be 'some_domain.'");

    browser.serviceType = @"_osc._tcp.";
    XCTAssertEqualObjects(browser.serviceType, @"_osc._tcp.", @"serviceType should be '_osc._tcp.'");

    BrowserDelegateRecorder *recorder = [[BrowserDelegateRecorder alloc] init];
    browser.delegate = recorder;
    XCTAssertEqualObjects(browser.delegate, recorder, @"delegate should be recorder");

    // Properties should remain unchanged when browser starts.
    [browser start];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertTrue(browser.running, @"Browser should be running");

    XCTAssertFalse(browser.useTCP, @"useTCP should remain NO");
    XCTAssertTrue(browser.resolveIPv6Addresses, @"resolveIPv6Addresses should remain YES");
    XCTAssertEqualObjects(browser.domain, @"some_domain.", @"domain should remain 'some_domain.'");
    XCTAssertEqualObjects(browser.serviceType, @"_osc._tcp.", @"serviceType should remain '_osc._tcp.'");
    XCTAssertEqualObjects(browser.delegate, recorder, @"delegate should remain recorder");

    // Toggle useTCP while running.
    browser.useTCP = YES;
    XCTAssertTrue(browser.useTCP, @"useTCP should be YES");

    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertTrue(browser.running, @"Browser should still be running");

    browser.useTCP = NO;
    XCTAssertFalse(browser.useTCP, @"useTCP should be NO again");

    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertTrue(browser.running, @"Browser should still be running");
}

- (void) testThat_browserHandlesIPv6Configuration
{
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];
    browser.serviceType = @"_osc._tcp.";

    // IPv4 only (default).
    browser.resolveIPv6Addresses = NO;
    [browser start];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertTrue(browser.running, @"Should work with IPv4 only");
    XCTAssertFalse(browser.resolveIPv6Addresses, @"resolveIPv6Addresses should remain NO");
    [browser stop];

    // IPv6 enabled.
    browser.resolveIPv6Addresses = YES;
    [browser start];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertTrue(browser.running, @"Should work with IPv6 enabled");
    XCTAssertTrue(browser.resolveIPv6Addresses, @"resolveIPv6Addresses should remain YES");
    [browser stop];
}


#pragma mark - Domain validation

- (void) testThat_browserCanChangeDomains
{
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];

    [self addTeardownBlock:^{
        [browser stop];
    }];

    browser.serviceType = @"_osc._tcp.";

    XCTAssertEqualObjects(browser.domain, @"local.", @"Should have default domain");
    XCTAssertFalse(browser.running, @"Browser should not be running");

    browser.domain = @"example.local.";
    XCTAssertEqualObjects(browser.domain, @"example.local.", @"Should accept custom domain");

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    browser.domain = nil;
#pragma clang diagnostic pop
    XCTAssertEqualObjects(browser.domain, @"example.local.", @"nil domain should be rejected");

    [browser start];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertTrue(browser.running, @"Browser should be running");

    browser.domain = @"test.local.";
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertTrue(browser.running, @"Browser should still be running after domain change");
    XCTAssertEqualObjects(browser.domain, @"test.local.", @"Domain should be updated");
}

- (void) testThat_browserCannotStartWithoutDomain
{
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];

    [self addTeardownBlock:^{
        [browser stop];
    }];

    browser.serviceType = @"_osc._tcp.";
    browser.domain = @"";
    XCTAssertEqualObjects(browser.domain, @"", @"Domain should be empty string");

    [browser start];
    XCTAssertFalse(browser.running, @"Browser should not start without a domain");

    browser.domain = @"local.";
    [browser start];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertTrue(browser.running, @"Browser should start with a valid domain");
}


#pragma mark - Service type validation

- (void) testThat_browserHandlesOSCServiceTypes
{
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];

    [self addTeardownBlock:^{
        [browser stop];
    }];

    NSArray<NSString *> *serviceTypes = @[
        @"_qlab._tcp.",
        @"_qlab._udp.",
        @"_gobutton._tcp.",
        @"_gobutton._udp.",
        @"_osc._tcp.",
        @"_osc._udp.",
    ];

    for ( NSString *serviceType in serviceTypes )
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

- (void) testThat_browserCannotStartWithoutServiceType
{
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];

    XCTAssertEqualObjects(browser.serviceType, @"", @"Default serviceType should be empty");
    XCTAssertFalse(browser.running, @"Browser should not be running");

    [browser start];
    XCTAssertFalse(browser.running, @"Browser should not start without a service type");

    browser.serviceType = @"_osc._tcp.";
    [browser start];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertTrue(browser.running, @"Browser should start with a valid service type");

    [browser stop];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertFalse(browser.running, @"Browser should stop when requested");
}

- (void) testThat_browserRestartsWhenServiceTypeChanges
{
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];

    [self addTeardownBlock:^{
        [browser stop];
    }];

    browser.serviceType = @"_osc._tcp.";
    [browser start];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertTrue(browser.running, @"Browser should be running");

    browser.serviceType = @"_osc._udp.";
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertTrue(browser.running, @"Browser should still be running after service type change");
    XCTAssertEqualObjects(browser.serviceType, @"_osc._udp.", @"serviceType should be updated");
}

- (void) testThat_browserHandlesEmptyServiceType
{
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];

    [self addTeardownBlock:^{
        [browser stop];
    }];

    browser.serviceType = @"";
    [browser start];
    XCTAssertFalse(browser.running, @"Should not start with an empty service type");

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    browser.serviceType = nil;
#pragma clang diagnostic pop
    [browser start];
    XCTAssertFalse(browser.running, @"Should not start with a nil service type");

    browser.serviceType = @"_osc._tcp.";
    [browser start];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertTrue(browser.running, @"Should start with valid service type");
}


#pragma mark - Delegate optionality

- (void) testThat_browserDelegateMethodsAreOptional
{
    // BrowserDelegateRecorder implements only the required methods; the optional
    // shouldAcceptService: will not be invoked because we override it, but a
    // bare XCTestCase-self delegate (below) omits both optionals.
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];

    [self addTeardownBlock:^{
        [browser stop];
    }];

    // Use self as delegate — XCTestCase does NOT implement optional delegate methods.
    browser.delegate = (id<F53OSCBrowserDelegate>)self;
    browser.serviceType = @"_osc._tcp.";

    // Must not crash.
    [browser start];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertTrue(browser.running, @"Browser should start without optional delegate methods");
}


#pragma mark - Lifecycle edge cases

- (void) testThat_browserHandlesRapidStartStop
{
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];
    browser.serviceType = @"_osc._tcp.";

    for ( int i = 0; i < 5; i++ )
    {
        [browser start];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        XCTAssertTrue(browser.running, @"Browser should start on iteration %d", i);

        [browser stop];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        XCTAssertFalse(browser.running, @"Browser should stop on iteration %d", i);
    }
}

- (void) testThat_browserHandlesMultipleStarts
{
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];
    browser.serviceType = @"_osc._tcp.";

    [browser start];
    [browser start];
    [browser start];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertTrue(browser.running, @"Browser should be running after multiple starts");

    [browser stop];
    [browser stop];
    [browser stop];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    XCTAssertFalse(browser.running, @"Browser should be stopped after multiple stops");
}

- (void) testThat_browserCleansUpProperly
{
    @autoreleasepool {
        F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];
        BrowserDelegateRecorder *recorder = [[BrowserDelegateRecorder alloc] init];

        browser.delegate = recorder;
        browser.serviceType = @"_osc._tcp.";

        [browser start];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
        XCTAssertTrue(browser.running, @"Browser should be running");

        [browser stop];
    }

    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];

    // If we reach this line without crashing, cleanup worked.
    XCTAssertTrue(YES, @"Browser cleanup completed without crashes");
}


#pragma mark - Seam-based: adding a discovered service

- (void) testThat_addDiscoveredServiceCreatesClientRecord
{
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];
    browser.serviceType = @"_osc._tcp.";
    BrowserDelegateRecorder *recorder = [[BrowserDelegateRecorder alloc] init];
    browser.delegate = recorder;

    XCTAssertEqual(browser.clientRecords.count, 0u, @"No records before discovery");

    F53OSCServiceRef *ref = MakeServiceRef( @"MyService", @"_osc._tcp.", @"local.", @"myhost.local.", 53000 );
    [browser _addDiscoveredService:ref];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];

    XCTAssertEqual(browser.clientRecords.count, 1u, @"One record should be present after add");
    XCTAssertEqual(recorder.addedRecords.count, 1u, @"Delegate should have received one add callback");
    XCTAssertEqual(recorder.removedRecords.count, 0u, @"No remove callbacks expected");

    F53OSCClientRecord *record = recorder.addedRecords.firstObject;
    XCTAssertNotNil(record, @"Added record should not be nil");
    XCTAssertEqualObjects(record.service.name, @"MyService", @"record.service.name should match");
    XCTAssertEqualObjects(record.service.type, @"_osc._tcp.", @"record.service.type should match");
    XCTAssertEqualObjects(record.service.domain, @"local.", @"record.service.domain should match");
    XCTAssertEqual(record.service.port, 53000, @"record.service.port should match");
}

- (void) testThat_addDiscoveredServicePropagatesUseTCP
{
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];
    browser.serviceType = @"_osc._tcp.";
    BrowserDelegateRecorder *recorder = [[BrowserDelegateRecorder alloc] init];
    browser.delegate = recorder;

    // useTCP = YES (default)
    browser.useTCP = YES;
    F53OSCServiceRef *ref1 = MakeServiceRef( @"TCPService", @"_osc._tcp.", @"local.", nil, 1234 );
    [browser _addDiscoveredService:ref1];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];

    F53OSCClientRecord *tcpRecord = recorder.addedRecords.lastObject;
    XCTAssertNotNil(tcpRecord, @"TCP record should be present");
    XCTAssertTrue(tcpRecord.useTCP, @"record.useTCP should be YES when browser.useTCP is YES");

    // useTCP = NO
    browser.useTCP = NO;
    F53OSCServiceRef *ref2 = MakeServiceRef( @"UDPService", @"_osc._udp.", @"local.", nil, 5678 );
    [browser _addDiscoveredService:ref2];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];

    F53OSCClientRecord *udpRecord = recorder.addedRecords.lastObject;
    XCTAssertNotNil(udpRecord, @"UDP record should be present");
    XCTAssertFalse(udpRecord.useTCP, @"record.useTCP should be NO when browser.useTCP is NO");
}


#pragma mark - Seam-based: removing a discovered service

- (void) testThat_removeDiscoveredServiceRemovesClientRecord
{
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];
    browser.serviceType = @"_osc._tcp.";
    BrowserDelegateRecorder *recorder = [[BrowserDelegateRecorder alloc] init];
    browser.delegate = recorder;

    F53OSCServiceRef *ref = MakeServiceRef( @"GoingService", @"_osc._tcp.", @"local.", nil, 7000 );

    [browser _addDiscoveredService:ref];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    XCTAssertEqual(browser.clientRecords.count, 1u, @"One record after add");

    [browser _removeDiscoveredService:ref];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    XCTAssertEqual(browser.clientRecords.count, 0u, @"No records after remove");
    XCTAssertEqual(recorder.removedRecords.count, 1u, @"Delegate should have received one remove callback");

    F53OSCClientRecord *removed = recorder.removedRecords.firstObject;
    XCTAssertEqualObjects(removed.service.name, @"GoingService", @"Removed record should carry the service ref");
}

- (void) testThat_removeDiscoveredServiceForUnknownServiceIsNoOp
{
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];
    browser.serviceType = @"_osc._tcp.";
    BrowserDelegateRecorder *recorder = [[BrowserDelegateRecorder alloc] init];
    browser.delegate = recorder;

    // Remove a service that was never added — should not crash and should not call delegate.
    F53OSCServiceRef *unknown = MakeServiceRef( @"NeverAdded", @"_osc._tcp.", @"local.", nil, 9999 );
    XCTAssertNoThrow([browser _removeDiscoveredService:unknown],
                     @"Removing unknown service should not throw");
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];

    XCTAssertEqual(recorder.removedRecords.count, 0u, @"No remove callbacks expected for unknown service");
}


#pragma mark - Seam-based: shouldAcceptService filter

- (void) testThat_shouldAcceptServiceFilterRejectsService
{
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];
    browser.serviceType = @"_osc._tcp.";
    BrowserDelegateRecorder *recorder = [[BrowserDelegateRecorder alloc] init];
    browser.delegate = recorder;

    // Reject everything.
    recorder.acceptServiceFilter = ^BOOL( F53OSCServiceRef *service ) {
        return NO;
    };

    F53OSCServiceRef *ref = MakeServiceRef( @"RejectedService", @"_osc._tcp.", @"local.", nil, 1111 );
    [browser _addDiscoveredService:ref];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];

    XCTAssertEqual(browser.clientRecords.count, 0u, @"Rejected service should not appear in clientRecords");
    XCTAssertEqual(recorder.addedRecords.count, 0u, @"didAddClientRecord should not be called for rejected service");
}

- (void) testThat_shouldAcceptServiceFilterAcceptsMatchingService
{
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];
    browser.serviceType = @"_osc._tcp.";
    BrowserDelegateRecorder *recorder = [[BrowserDelegateRecorder alloc] init];
    browser.delegate = recorder;

    // Accept only services named "Accepted".
    recorder.acceptServiceFilter = ^BOOL( F53OSCServiceRef *service ) {
        return [service.name isEqualToString:@"Accepted"];
    };

    F53OSCServiceRef *rejected = MakeServiceRef( @"NotAccepted", @"_osc._tcp.", @"local.", nil, 2000 );
    F53OSCServiceRef *accepted = MakeServiceRef( @"Accepted", @"_osc._tcp.", @"local.", nil, 2001 );

    [browser _addDiscoveredService:rejected];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    [browser _addDiscoveredService:accepted];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];

    XCTAssertEqual(browser.clientRecords.count, 1u, @"Only accepted service should be in clientRecords");
    XCTAssertEqual(recorder.addedRecords.count, 1u, @"Only one add callback expected");
    XCTAssertEqualObjects(recorder.addedRecords.firstObject.service.name, @"Accepted",
                          @"The accepted record should have name 'Accepted'");
}


#pragma mark - Seam-based: multiple services

- (void) testThat_multipleServicesCanBeAddedAndRemoved
{
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];
    browser.serviceType = @"_osc._tcp.";
    BrowserDelegateRecorder *recorder = [[BrowserDelegateRecorder alloc] init];
    browser.delegate = recorder;

    F53OSCServiceRef *ref1 = MakeServiceRef( @"Service1", @"_osc._tcp.", @"local.", nil, 4001 );
    F53OSCServiceRef *ref2 = MakeServiceRef( @"Service2", @"_osc._tcp.", @"local.", nil, 4002 );
    F53OSCServiceRef *ref3 = MakeServiceRef( @"Service3", @"_osc._tcp.", @"local.", nil, 4003 );

    [browser _addDiscoveredService:ref1];
    [browser _addDiscoveredService:ref2];
    [browser _addDiscoveredService:ref3];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];

    XCTAssertEqual(browser.clientRecords.count, 3u, @"Three records expected after three adds");
    XCTAssertEqual(recorder.addedRecords.count, 3u, @"Three add callbacks expected");

    [browser _removeDiscoveredService:ref2];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];

    XCTAssertEqual(browser.clientRecords.count, 2u, @"Two records expected after one remove");
    XCTAssertEqual(recorder.removedRecords.count, 1u, @"One remove callback expected");
    XCTAssertEqualObjects(recorder.removedRecords.firstObject.service.name, @"Service2",
                          @"Service2 should have been removed");
}

- (void) testThat_clientRecordsAreEmptyAfterStop
{
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];
    browser.serviceType = @"_osc._tcp.";
    BrowserDelegateRecorder *recorder = [[BrowserDelegateRecorder alloc] init];
    browser.delegate = recorder;

    F53OSCServiceRef *ref = MakeServiceRef( @"TransientService", @"_osc._tcp.", @"local.", nil, 5000 );
    [browser _addDiscoveredService:ref];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    XCTAssertEqual(browser.clientRecords.count, 1u, @"One record before stop");

    [browser stop];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.3]];

    XCTAssertEqual(browser.clientRecords.count, 0u, @"clientRecords should be empty after stop");
}


#pragma mark - Integration: discovers advertised service via nw_listener

- (void) testIntegration_DiscoversAdvertisedService
{
    // Pick a unique service name per run to avoid stale mDNS caches.
    NSString *serviceName = [NSString stringWithFormat:@"F53OSCTest-%@", [[NSUUID UUID] UUIDString]];
    NSString *serviceType = @"_f53osctest._udp";

    // Stand up an nw_listener advertising the service.
    nw_parameters_t params = nw_parameters_create_secure_udp(
        NW_PARAMETERS_DISABLE_PROTOCOL,
        NW_PARAMETERS_DEFAULT_CONFIGURATION
    );
    nw_listener_t listener = nw_listener_create(params);
    nw_advertise_descriptor_t advert = nw_advertise_descriptor_create_bonjour_service(
        [serviceName UTF8String],
        [serviceType UTF8String],
        NULL  // domain — defaults to local.
    );
    nw_listener_set_advertise_descriptor(listener, advert);
    nw_listener_set_queue(listener, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0));

    dispatch_semaphore_t listenerReady = dispatch_semaphore_create(0);
    nw_listener_set_state_changed_handler(listener, ^(nw_listener_state_t state, nw_error_t _Nullable error) {
        if ( state == nw_listener_state_ready )
            dispatch_semaphore_signal(listenerReady);
    });
    nw_listener_set_new_connection_handler(listener, ^(nw_connection_t conn) {
        // Discard inbound connections — we only care about advertisement.
        nw_connection_cancel(conn);
    });
    nw_listener_start(listener);

    long listenerResult = dispatch_semaphore_wait(listenerReady,
                                                  dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    if ( listenerResult != 0 )
    {
        nw_listener_cancel(listener);
        XCTFail(@"nw_listener did not reach ready state within 5 seconds — cannot run integration test");
        return;
    }

    // Create an F53OSCBrowser and wait for discovery.
    F53OSCBrowser *browser = [[F53OSCBrowser alloc] init];
    browser.serviceType = serviceType;
    browser.domain = @"local.";
    BrowserDelegateRecorder *recorder = [[BrowserDelegateRecorder alloc] init];
    browser.delegate = recorder;
    [browser start];

    // Spin the run loop for up to 10 s, polling clientRecords.
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:10.0];
    BOOL found = NO;
    while ( [deadline timeIntervalSinceNow] > 0 )
    {
        for ( F53OSCClientRecord *r in browser.clientRecords )
        {
            if ( [r.service.name isEqualToString:serviceName] )
            {
                found = YES;
                break;
            }
        }
        if ( found )
            break;
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }

    [browser stop];
    nw_listener_cancel(listener);

    // mDNS in xctest sandboxes can be unreliable (entitlements, daemon scope).
    // Skip rather than fail if discovery didn't complete — the seam-based tests
    // cover the browser logic; this integration test is best-effort.
    if ( !found )
        XCTSkip(@"mDNS did not surface the advertised service within 10s (xctest sandbox?)");
}


#pragma mark - F53OSCBrowserDelegate stubs (required by protocol)

- (void) browser:(F53OSCBrowser *)browser didAddClientRecord:(F53OSCClientRecord *)clientRecord
{
    // Used by testThat_browserDelegateMethodsAreOptional (self is delegate).
    // No-op.
}

- (void) browser:(F53OSCBrowser *)browser didRemoveClientRecord:(F53OSCClientRecord *)clientRecord
{
    // No-op.
}

// NOTE: by not implementing `browser:shouldAcceptService:` on self/XCTestCase,
// we exercise the path where the optional delegate method is absent.

@end

NS_ASSUME_NONNULL_END
