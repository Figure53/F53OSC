//
//  F53OSCImpluse.m
//
//  Created by Brent Lord on 2/12/20.
//
//  Copyright (c) 2020 Figure 53 LLC, https://figure53.com
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

#import "F53OSCImpulse.h"


NS_ASSUME_NONNULL_BEGIN

@implementation F53OSCImpluse

static F53OSCImpluse *_sharedImpluse = nil;

+ (F53OSCImpluse *) impluse
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedImpluse = [[F53OSCImpluse alloc] init];
    });
    return _sharedImpluse;
}

#pragma mark - NSCopying

- (id) copyWithZone:(nullable NSZone *)zone
{
    F53OSCImpluse *copy = [[self class] allocWithZone:zone];
    return copy;
}

#pragma mark - NSSecureCoding

- (nullable instancetype) initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if ( self )
    {
    }
    return self;
}

- (void) encodeWithCoder:(NSCoder *)aCoder
{
}

+ (BOOL) supportsSecureCoding
{
    return YES;
}

@end

NS_ASSUME_NONNULL_END
