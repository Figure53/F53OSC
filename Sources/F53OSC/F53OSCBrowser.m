//
//  F53OSCBrowser.m
//  F53OSC
//
//  Created by Brent Lord on 8/27/20.
//  Adapted from QLKBrowser by Zach Waugh.
//  Copyright (c) 2013-2026 Figure 53 LLC, https://figure53.com
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

#import <Network/Network.h>

#import "F53OSCBrowser.h"
#import "F53OSCServiceRef.h"


#define F53_OSC_BROWSER_DEBUG 0


NS_ASSUME_NONNULL_BEGIN


#pragma mark - F53OSCClientRecord

@implementation F53OSCClientRecord

- (instancetype) init
{
    self = [super init];
    if ( self )
    {
        self.port = 0;
        self.useTCP = NO;
        self.hostAddresses = @[];
        self.service = nil;
    }
    return self;
}

- (id) copyWithZone:(nullable NSZone *)zone
{
    F53OSCClientRecord *copy = [[F53OSCClientRecord allocWithZone:zone] init];
    copy.port = self.port;
    copy.useTCP = self.useTCP;
    copy.hostAddresses = [self.hostAddresses copyWithZone:zone];
    copy.service = self.service;
    return copy;
}

@end


#pragma mark - F53OSCBrowser private interface

@interface F53OSCBrowser ()

@property (assign, readwrite)                   BOOL running;

// Private serial queue; all nw_browser / nw_connection callbacks land here.
@property (nonatomic, strong)               dispatch_queue_t callbackQueue;

// The live nw_browser. ARC retains via property storage.
@property (nonatomic, strong, nullable)     nw_browser_t nwBrowser;

// Endpoints that have been discovered but not yet handed to resolve operations.
// Keyed by a stable service-identity string ("name.type.domain.").
// Value is an NSArray of two elements: [nw_endpoint_t, NSDictionary txtRecord (or NSNull)].
@property (nonatomic, strong)               NSMutableDictionary<NSString *, NSArray *> *pendingResolveEndpoints;

// Whether a resolve-coalesce timer is already scheduled.
@property (nonatomic, assign)               BOOL resolveScheduled;

// Short-lived nw_connection_t objects used to resolve host/port.
// Keyed by the same service-identity string used in pendingResolveEndpoints.
@property (nonatomic, strong)               NSMutableDictionary<NSString *, nw_connection_t> *resolvingConnections;

// The resolved client records.
@property (nonatomic, strong)                   NSMutableArray<F53OSCClientRecord *> *mutableClientRecords;

@end


#pragma mark - F53OSCBrowser implementation

@implementation F53OSCBrowser

- (instancetype) init
{
    self = [super init];
    if ( self )
    {
        self.domain = @"local.";
        self.serviceType = @"";
        self.useTCP = YES;
        self.resolveIPv6Addresses = NO;
        
        self.running = NO;
        
        self.callbackQueue = dispatch_queue_create( "com.figure53.F53OSCBrowser", DISPATCH_QUEUE_SERIAL );

        self.nwBrowser = nil;
        self.pendingResolveEndpoints = [NSMutableDictionary dictionary];
        self.resolveScheduled = NO;
        self.resolvingConnections = [NSMutableDictionary dictionary];
        self.mutableClientRecords = [NSMutableArray array];
    }
    return self;
}

- (void) dealloc
{
    [self stop];
}


#pragma mark - Custom getters/setters

- (NSArray<F53OSCClientRecord *> *) clientRecords
{
    return self.mutableClientRecords.copy;
}

- (void) setDomain:(NSString *)domain
{
    if ( !domain )
        return;
    
    if ( [_domain isEqualToString:domain] == NO )
    {
        BOOL wasRunning = self.running;
        if ( wasRunning )
            [self stop];
        
        _domain = [domain copy];
        
        if ( wasRunning )
            [self start];
    }
}

- (void) setServiceType:(NSString *)serviceType
{
    if ( !serviceType )
        return;
    
    if ( [_serviceType isEqualToString:serviceType] == NO )
    {
        BOOL wasRunning = self.running;
        if ( wasRunning )
            [self stop];
        
        _serviceType = [serviceType copy];
        
        if ( wasRunning )
            [self start];
    }
}

- (void) setUseTCP:(BOOL)useTCP
{
    if ( _useTCP != useTCP )
    {
        BOOL wasRunning = self.running;
        if ( wasRunning )
            [self stop];
        
        _useTCP = useTCP;
        
        if ( wasRunning )
            [self start];
    }
}


#pragma mark - Start / Stop

- (void) start
{
#if F53_OSC_BROWSER_DEBUG
    if ( self.running )
        NSLog( @"[browser] start - already running" );
    else
        NSLog( @"[browser] start" );
#endif
    
    if ( self.running )
        return;
    
    if ( self.serviceType.length == 0 )
    {
        NSLog( @"[browser] start - serviceType is empty; not starting" );
        return;
    }

    if ( self.domain.length == 0 )
        return;
    
    // Strip the trailing "." from domain if present — nw_browse_descriptor
    // accepts it either way but the Swift layer normalises it so we follow suit.
    NSString *browseType   = self.serviceType;
    NSString *browseDomain = self.domain;
    
    nw_browse_descriptor_t descriptor = nw_browse_descriptor_create_bonjour_service(
        [browseType   cStringUsingEncoding:NSUTF8StringEncoding],
        [browseDomain cStringUsingEncoding:NSUTF8StringEncoding]
    );
    nw_parameters_t params = nw_parameters_create();
    nw_browser_t browser = nw_browser_create( descriptor, params );

    nw_browser_set_queue( browser, self.callbackQueue );

    __weak typeof(self) weakSelf = self;

    nw_browser_set_state_changed_handler( browser, ^( nw_browser_state_t state, nw_error_t _Nullable error ) {
        [weakSelf handleBrowserStateChange:state error:error];
    });

    nw_browser_set_browse_results_changed_handler( browser, ^( nw_browse_result_t _Nullable old_result, nw_browse_result_t _Nullable new_result, bool batch_complete ) {
        [weakSelf handleBrowseResultChangedFrom:old_result to:new_result batchComplete:batch_complete];
    });

    self.nwBrowser = browser;

    nw_browser_start( browser );

    // `running` is set to YES in the state-changed handler when nw_browser_state_ready fires,
    // not here, so `running` reflects actual readiness rather than intent.
}

- (void) stop
{
#if F53_OSC_BROWSER_DEBUG
    NSLog( @"[browser] stop" );
#endif

    // Set running = NO immediately so that restart-on-property-change is safe.
    self.running = NO;

    // Nil the delegate before tearing down so removal callbacks don't fire.
    self.delegate = nil;
    
    // Cancel and release the browser.
    if ( self.nwBrowser )
    {
        nw_browser_cancel( self.nwBrowser );
        self.nwBrowser = nil;
    }

    // Cancel all in-flight resolve connections.
    NSDictionary *resolving = [self.resolvingConnections copy];
    for ( NSString *key in resolving )
    {
        nw_connection_cancel( resolving[key] );
    }
    [self.resolvingConnections removeAllObjects];

    // Clear pending-resolve queue.
    [self.pendingResolveEndpoints removeAllObjects];
    self.resolveScheduled = NO;

    // Remove all client records (delegate is already nil, so no callbacks fire).
    [self.mutableClientRecords removeAllObjects];
}


#pragma mark - nw_browser state handler

- (void) handleBrowserStateChange:(nw_browser_state_t)state error:(nullable nw_error_t)error
    {
    // Runs on callbackQueue.
    switch ( state )
    {
        case nw_browser_state_ready:
        {
#if F53_OSC_BROWSER_DEBUG
            NSLog( @"[browser] nw_browser state: ready" );
#endif
            dispatch_async( dispatch_get_main_queue(), ^{
                self.running = YES;
            });
            break;
        }
        
        case nw_browser_state_failed:
        {
            if ( error )
            {
                CFStringRef desc = CFCopyDescription( (CFTypeRef)error );
                NSLog( @"[browser] nw_browser failed: %@", (__bridge NSString *)desc );
                CFRelease( desc );
            }
            dispatch_async( dispatch_get_main_queue(), ^{
                self.running = NO;
            });
            break;
        }

        case nw_browser_state_cancelled:
        {
#if F53_OSC_BROWSER_DEBUG
            NSLog( @"[browser] nw_browser state: cancelled" );
#endif
            dispatch_async( dispatch_get_main_queue(), ^{
                self.running = NO;
            });
            break;
        }

        case nw_browser_state_waiting:
        {
#if F53_OSC_BROWSER_DEBUG
            NSLog( @"[browser] nw_browser state: waiting" );
#endif
            break;
        }

        default:
            break;
    }
}


#pragma mark - nw_browser results handler

- (void) handleBrowseResultChangedFrom:(nullable nw_browse_result_t)old_result
                                    to:(nullable nw_browse_result_t)new_result
                         batchComplete:(BOOL)batchComplete
{
    // Runs on callbackQueue.

    if ( old_result == NULL && new_result != NULL )
    {
        // Added
        nw_endpoint_t endpoint = nw_browse_result_copy_endpoint( new_result );
        if ( endpoint )
            [self handleAddedEndpoint:endpoint result:new_result];
}
    else if ( old_result != NULL && new_result == NULL )
{
        // Removed
        nw_endpoint_t endpoint = nw_browse_result_copy_endpoint( old_result );
        if ( endpoint )
            [self handleRemovedEndpoint:endpoint];
    }
    else if ( old_result != NULL && new_result != NULL )
    {
        // Changed — treat as remove + re-add so we get a fresh resolution.
        nw_endpoint_t oldEndpoint = nw_browse_result_copy_endpoint( old_result );
        nw_endpoint_t newEndpoint = nw_browse_result_copy_endpoint( new_result );
        if ( oldEndpoint )
            [self handleRemovedEndpoint:oldEndpoint];
        if ( newEndpoint )
            [self handleAddedEndpoint:newEndpoint result:new_result];
    }
}

// Returns a stable string identity for a Bonjour service endpoint:
// "name.type.domain." — used as dictionary keys.
- (nullable NSString *) serviceIdentityForEndpoint:(nw_endpoint_t)endpoint
{
    if ( nw_endpoint_get_type( endpoint ) != nw_endpoint_type_bonjour_service )
        return nil;

    const char *name   = nw_endpoint_get_bonjour_service_name( endpoint );
    const char *type   = nw_endpoint_get_bonjour_service_type( endpoint );
    const char *domain = nw_endpoint_get_bonjour_service_domain( endpoint );

    if ( !name || !type || !domain )
        return nil;

    return [NSString stringWithFormat:@"%s.%s.%s",
            name, type, domain[0] ? domain : "local."];
}

- (void) handleAddedEndpoint:(nw_endpoint_t)endpoint result:(nw_browse_result_t)result
{
    // Runs on callbackQueue.
    if ( nw_endpoint_get_type( endpoint ) != nw_endpoint_type_bonjour_service )
        return;

    NSString *identity = [self serviceIdentityForEndpoint:endpoint];
    if ( !identity )
        return;

#if F53_OSC_BROWSER_DEBUG
    NSLog( @"[browser] added endpoint: %@", identity );
#endif

    // Extract TXT record from the browse result.
    NSDictionary<NSString *, NSString *> *txtRecord = nil;
    nw_txt_record_t txt = nw_browse_result_copy_txt_record_object( result );
    if ( txt != NULL )
    {
        NSMutableDictionary<NSString *, NSString *> *dict = [NSMutableDictionary dictionary];
        nw_txt_record_apply( txt, ^bool( const char *key, nw_txt_record_find_key_t found, const uint8_t *value, size_t value_len ) {
            NSString *k = key ? [NSString stringWithUTF8String:key] : nil;
            if ( !k )
                return true;
            NSString *v = @"";
            if ( found == nw_txt_record_find_key_non_empty_value && value != NULL && value_len > 0 )
                v = [[NSString alloc] initWithBytes:value length:value_len encoding:NSUTF8StringEncoding] ?: @"";
            dict[k] = v;
            return true; // continue iteration
        });
        txtRecord = [dict copy];
    }
        
    self.pendingResolveEndpoints[identity] = @[ endpoint, txtRecord ?: [NSNull null] ];

    if ( !self.resolveScheduled )
        {
        self.resolveScheduled = YES;
        dispatch_after( dispatch_time( DISPATCH_TIME_NOW, 500 * NSEC_PER_MSEC ),
                        self.callbackQueue, ^{
            [self resolvePendingEndpoints];
        });
        }
    }
    
- (void) handleRemovedEndpoint:(nw_endpoint_t)endpoint
{
    // Runs on callbackQueue.
    if ( nw_endpoint_get_type( endpoint ) != nw_endpoint_type_bonjour_service )
        return;

    NSString *identity = [self serviceIdentityForEndpoint:endpoint];
    if ( !identity )
        return;

#if F53_OSC_BROWSER_DEBUG
    NSLog( @"[browser] removed endpoint: %@", identity );
#endif

    // Remove from pending queue if not yet resolved.
    [self.pendingResolveEndpoints removeObjectForKey:identity];

    // Cancel in-flight resolution if any.
    nw_connection_t connObj = self.resolvingConnections[identity];
    if ( connObj )
    {
        nw_connection_cancel( connObj );
        [self.resolvingConnections removeObjectForKey:identity];
}

    // Find and remove the client record, then notify the delegate on main.
    // We need to find the record by service name/type/domain.
    const char *nameCStr   = nw_endpoint_get_bonjour_service_name( endpoint );
    const char *typeCStr   = nw_endpoint_get_bonjour_service_type( endpoint );
    const char *domainCStr = nw_endpoint_get_bonjour_service_domain( endpoint );

    NSString *name   = nameCStr   ? @(nameCStr)   : nil;
    NSString *type   = typeCStr   ? @(typeCStr)   : nil;
    NSString *domain = domainCStr ? @(domainCStr) : nil;

    if ( !name || !type )
        return;

    dispatch_async( dispatch_get_main_queue(), ^{
        F53OSCClientRecord *record = [self clientRecordForServiceName:name type:type domain:domain];
        if ( !record )
            return;

        [self.mutableClientRecords removeObject:record];
        [self.delegate browser:self didRemoveClientRecord:record];
    });
    }
    

#pragma mark - Resolve coalescing

- (void) resolvePendingEndpoints
{
    // Runs on callbackQueue.
    self.resolveScheduled = NO;

    NSDictionary<NSString *, NSArray *> *toResolve = [self.pendingResolveEndpoints copy];
    [self.pendingResolveEndpoints removeAllObjects];

#if F53_OSC_BROWSER_DEBUG
    NSLog( @"[browser] resolving %lu pending endpoint(s)", (unsigned long)toResolve.count );
#endif
    
    for ( NSString *identity in toResolve )
{
        NSArray *pair = toResolve[identity];
        nw_endpoint_t endpoint = pair[0];
        NSDictionary<NSString *, NSString *> *txtRecord = [pair[1] isKindOfClass:[NSDictionary class]] ? pair[1] : nil;
        [self resolveEndpoint:endpoint identity:identity txtRecord:txtRecord];
    }
}


#pragma mark - Resolve via nw_connection

- (void) resolveEndpoint:(nw_endpoint_t)endpoint
                identity:(NSString *)identity
               txtRecord:(nullable NSDictionary<NSString *, NSString *> *)txtRecord
{
    // Runs on callbackQueue.

    // Build parameters matching useTCP; disable any heavyweight protocol framing
    // since we only want the connection to reach .ready to extract the remote address.
    nw_parameters_t resolveParams;
    if ( self.useTCP )
    {
        resolveParams = nw_parameters_create_secure_tcp(
            NW_PARAMETERS_DISABLE_PROTOCOL,   // no TLS
            NW_PARAMETERS_DEFAULT_CONFIGURATION
        );
    }
    else
    {
        resolveParams = nw_parameters_create_secure_udp(
            NW_PARAMETERS_DISABLE_PROTOCOL,   // no DTLS
            NW_PARAMETERS_DEFAULT_CONFIGURATION
        );
    }

    if ( !self.resolveIPv6Addresses )
    {
        // Constrain to IPv4 via nw_ip_options_set_version so Network.framework
        // only resolves and uses IPv4 addresses for this connection.
        nw_protocol_stack_t stack = nw_parameters_copy_default_protocol_stack( resolveParams );
        nw_protocol_options_t ip_options = nw_protocol_stack_copy_internet_protocol( stack );
        nw_ip_options_set_version( ip_options, nw_ip_version_4 );
    }
    // when resolveIPv6Addresses == YES, leave the default (dual-stack)

    nw_connection_t conn = nw_connection_create( endpoint, resolveParams );

    if ( !conn )
    {
        NSLog( @"[browser] failed to create nw_connection for %@", identity );
        return;
    }

    self.resolvingConnections[identity] = conn;

    // Snapshot the endpoint C strings before entering the block.
    const char *nameCStr   = nw_endpoint_get_bonjour_service_name( endpoint );
    const char *typeCStr   = nw_endpoint_get_bonjour_service_type( endpoint );
    const char *domainCStr = nw_endpoint_get_bonjour_service_domain( endpoint );

    NSString *serviceName   = nameCStr   ? @(nameCStr)   : @"";
    NSString *serviceType   = typeCStr   ? @(typeCStr)   : @"";
    NSString *serviceDomain = domainCStr ? @(domainCStr) : @"local.";

    __weak typeof(self) weakSelf = self;

    // 5-second watchdog: cancel the resolve connection if it hasn't completed.
    __block BOOL completed = NO;
    dispatch_after( dispatch_time( DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC ), self.callbackQueue, ^{
        if ( completed )
            return;
        typeof(self) strongSelf = weakSelf;
        if ( !strongSelf )
            return;
#if F53_OSC_BROWSER_DEBUG
        NSLog( @"[browser] resolve timeout for endpoint %s", nw_endpoint_get_hostname( endpoint ) );
#endif
        nw_connection_cancel( conn );
    });

    nw_connection_set_queue( conn, self.callbackQueue );
    nw_connection_set_state_changed_handler( conn, ^( nw_connection_state_t state, nw_error_t _Nullable error ) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if ( !strongSelf )
            return;

        if ( state == nw_connection_state_ready )
        {
            completed = YES;

            nw_path_t path = nw_connection_copy_current_path( conn );
            if ( path )
            {
                nw_endpoint_t remote = nw_path_copy_effective_remote_endpoint( path );
                if ( remote )
                {
                    const char *hostname = nw_endpoint_get_hostname( remote );
                    uint16_t port        = nw_endpoint_get_port( remote );

                    NSString *host = hostname ? @(hostname) : nil;

#if F53_OSC_BROWSER_DEBUG
                    NSLog( @"[browser] resolved %@ → %@:%u", identity, host ?: @"(nil)", port );
#endif

                    if ( host && port > 0 )
                    {
                        // belt-and-suspenders: discard IPv6 if resolveIPv6Addresses is NO
                        // (nw_ip_version_4 constraint above should already prevent this).
                        BOOL isIPv6 = [host containsString:@":"];
                        if ( isIPv6 && !strongSelf.resolveIPv6Addresses )
                        {
#if F53_OSC_BROWSER_DEBUG
                            NSLog( @"[browser] discarding IPv6 address for %@ (resolveIPv6Addresses=NO)", identity );
#endif
}
                        else
                        {
                            NSArray<NSString *> *hostAddresses = @[host];
                            F53OSCServiceRef *serviceRef = [[F53OSCServiceRef alloc]
                                initWithName:serviceName
                                        type:serviceType
                                      domain:serviceDomain
                                        host:host
                                        port:port
                               hostAddresses:hostAddresses
                                   txtRecord:txtRecord];

                            // Deliver on main thread.
                            dispatch_async( dispatch_get_main_queue(), ^{
                                [strongSelf _addDiscoveredService:serviceRef];
                            });
    }
}

                }
            }

            nw_connection_cancel( conn );
        }
        else if ( state == nw_connection_state_failed )
{
            completed = YES;
#if F53_OSC_BROWSER_DEBUG
            if ( error )
            {
                CFStringRef desc = CFCopyDescription( (CFTypeRef)error );
                NSLog( @"[browser] resolve connection failed for %@: %@", identity, (__bridge NSString *)desc );
                CFRelease( desc );
            }
#endif
            // Remove our retained reference; nw_connection_cancel is not
            // needed — the connection is already failed.
            [strongSelf.resolvingConnections removeObjectForKey:identity];
        }
        else if ( state == nw_connection_state_cancelled )
        {
            completed = YES;
            // Remove our retained reference.
            [strongSelf.resolvingConnections removeObjectForKey:identity];
        }
    });

    nw_connection_start( conn );
}


#pragma mark - F53OSCBrowser (Internal) — testability seams

- (void) _addDiscoveredService:(F53OSCServiceRef *)service
{
    // Must be called on the main thread (or internally dispatches to main).

    // check delegate filter
    BOOL accepted = YES;
    if ( [self.delegate respondsToSelector:@selector(browser:shouldAcceptService:)] )
        accepted = [self.delegate browser:self shouldAcceptService:service];

    if ( !accepted )
    {
#if F53_OSC_BROWSER_DEBUG
        NSLog( @"[browser] delegate rejected service: %@", service.name );
#endif
        return;
    }

    // check for duplicate (can happen if a service is re-resolved)
    F53OSCClientRecord *existing = [self clientRecordForServiceName:service.name
                                                               type:service.type
                                                             domain:service.domain];
    if ( existing )
    {
        // update in place rather than adding a duplicate
        existing.port = service.port;
        existing.hostAddresses = service.hostAddresses;
        existing.service = service;
        return;
    }

    F53OSCClientRecord *record = [F53OSCClientRecord new];
    record.port = service.port;
    record.useTCP = self.useTCP;
    record.hostAddresses = service.hostAddresses;
    record.service = service;

#if F53_OSC_BROWSER_DEBUG
    NSLog( @"[browser] adding client record: %@ → %@:%u",
           service.name, service.host, service.port );
#endif
    
    [self.mutableClientRecords addObject:record];
    [self.delegate browser:self didAddClientRecord:record];
}

- (void) _removeDiscoveredService:(F53OSCServiceRef *)service
{
    F53OSCClientRecord *record = [self clientRecordForServiceName:service.name
                                                             type:service.type
                                                           domain:service.domain];
    if ( !record )
        return;

#if F53_OSC_BROWSER_DEBUG
    NSLog( @"[browser] removing client record: %@", service.name );
#endif
    
    [self.mutableClientRecords removeObject:record];
    [self.delegate browser:self didRemoveClientRecord:record];
}


#pragma mark - Private helpers

- (nullable F53OSCClientRecord *) clientRecordForServiceName:(NSString *)name
                                                        type:(nullable NSString *)type
                                                      domain:(nullable NSString *)domain
{
    for ( F53OSCClientRecord *record in self.mutableClientRecords )
    {
        F53OSCServiceRef *svc = record.service;
        if ( !svc )
            continue;
    
        if ( ![svc.name isEqualToString:name] )
            continue;
        if ( type && ![svc.type isEqualToString:type] )
            continue;
        // domain comparison is lenient — ignore trailing dot differences.
        if ( domain )
    {
            NSString *a = [svc.domain hasSuffix:@"."] ? svc.domain : [svc.domain stringByAppendingString:@"."];
            NSString *b = [domain    hasSuffix:@"."] ? domain    : [domain    stringByAppendingString:@"."];
            if ( ![a isEqualToString:b] )
                continue;
}

        return record;
}
            return nil;
}

@end


NS_ASSUME_NONNULL_END
