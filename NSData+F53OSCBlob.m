//
//  NSData+F53OSCBlob.m
//
//  Created by Sean Dougall on 1/17/11.
//
//  Copyright (c) 2011-2015 Figure 53 LLC, http://figure53.com
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
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#import "NSData+F53OSCBlob.h"


@implementation NSData (F53OSCBlobAdditions)

- (NSData *) oscBlobData
{
    UInt32 dataSize = (UInt32)[self length];
    dataSize = OSSwapHostToBigInt32( dataSize );
    NSMutableData *newData = [NSMutableData dataWithBytes:&dataSize length:sizeof(UInt32)];
    
    [newData appendData:self];
 
    // In OSC everything is in multiples of 4 bytes. We must add null bytes to pad out to 4.
    char zero = 0;
    for ( int i = ([self length] - 1) % 4; i < 3; i++ )
        [newData appendBytes:&zero length:1];
    
    return [newData copy];
}

+ (NSData *) dataWithOSCBlobBytes:(const char *)buf maxLength:(NSUInteger)maxLength length:(NSUInteger *)outLength
{
    if ( buf == NULL || maxLength == 0 )
        return nil;
    
    UInt32 dataSize = 0;
    
    dataSize = *((UInt32 *)buf);
    dataSize = OSSwapBigToHostInt32( dataSize );
    
    if ( dataSize + 4 > maxLength )
        return nil;
    
    *outLength = dataSize;
    buf += 4;
    return [NSData dataWithBytes:buf length:dataSize];
}

@end
