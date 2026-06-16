//
//  F53OSCServiceRef.m
//  F53OSC
//
//  Created by Christopher Cahoon on 5/23/26.
//  Copyright (c) 2026 Figure 53 LLC, https://figure53.com
//

#if F53OSC_BUILT_AS_FRAMEWORK
#import <F53OSC/F53OSCServiceRef.h>
#else
#import "F53OSCServiceRef.h"
#endif


@implementation F53OSCServiceRef

- (instancetype) initWithName:(NSString *)name
                         type:(NSString *)type
                       domain:(NSString *)domain
                         host:(NSString *)host
                         port:(UInt16)port
                hostAddresses:(NSArray<NSString *> *)hostAddresses
                    txtRecord:(NSDictionary<NSString *, NSString *> *)txtRecord
{
    self = [super init];
    if ( self )
    {
        _name = [name copy];
        _type = [type copy];
        _domain = [domain copy];
        _host = [host copy];
        _port = port;
        _hostAddresses = [hostAddresses copy];
        _txtRecord = [txtRecord copy];
    }
    return self;
}

- (id) copyWithZone:(NSZone *)zone
{
    // immutable value type
    return self;
}

- (NSUInteger) hash
{
    return self.name.hash ^ self.type.hash ^ self.domain.hash ^ (NSUInteger)self.port;
}

- (BOOL) isEqual:(id)object
{
    if ( self == object )
        return YES;
    if ( ![object isKindOfClass:[F53OSCServiceRef class]] )
        return NO;

    F53OSCServiceRef *other = object;
    return self.port == other.port
        && [self.name isEqualToString:other.name]
        && [self.type isEqualToString:other.type]
        && [self.domain isEqualToString:other.domain]
        && ((self.host == nil && other.host == nil) || [self.host isEqualToString:other.host])
        && [self.hostAddresses isEqualToArray:other.hostAddresses]
        && ((self.txtRecord == nil && other.txtRecord == nil) || [self.txtRecord isEqualToDictionary:other.txtRecord]);
}

- (NSString *) description
{
    return [NSString stringWithFormat:@"<%@: %p %@.%@%@ → %@:%hu>",
            NSStringFromClass([self class]), self,
            self.name, self.type, self.domain,
            self.host ?: @"(unresolved)", self.port];
}

@end
