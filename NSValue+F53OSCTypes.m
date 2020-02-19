//
//  NSValue+F53OSCTypes.m
//
//  Created by Brent Lord on 2/19/20.
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

#import "NSValue+F53OSCTypes.h"


NS_ASSUME_NONNULL_BEGIN

@implementation NSValue (F53OSCTypes)

+ (instancetype) oscTrue
{
    const char value = 'T';
    return [self valueWithBytes:&value objCType:@encode(char)];
}

+ (instancetype) oscFalse
{
    const char value = 'F';
    return [self valueWithBytes:&value objCType:@encode(char)];
}

+ (instancetype) oscNull
{
    const char value = 'N';
    return [self valueWithBytes:&value objCType:@encode(char)];
}

+ (instancetype) oscImpulse
{
    const char value = 'I';
    return [self valueWithBytes:&value objCType:@encode(char)];
}

- (char) oscTypeValue
{
    char value;
    [self getValue:&value];
    return value;
}

@end

NS_ASSUME_NONNULL_END
