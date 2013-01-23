//
//  NSData+F53OSCBlob.m
//
//  Created by Sean Dougall on 1/17/11.
//
//  Copyright (c) 2011-2013 Figure 53 LLC, http://figure53.com
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

#import "NSData+F53OSCBlob.h"


@implementation NSData (F53OSCBlobAdditions)

- (NSData *) oscBlobData
{
    //  A note on the 4s: For OSC, everything is null-terminated and in multiples of 4 bytes. 
    //  If the data is already a multiple of 4 bytes, it needs to have four null bytes appended.
    
    UInt32 dataSize = (UInt32)[self length];
    dataSize = 4 * ( ceil( dataSize / 4.0 ) );
    dataSize = OSSwapHostToBigInt32( dataSize );
    NSMutableData *newData = [NSMutableData dataWithBytes:&dataSize length:sizeof(UInt32)];
    
    [newData appendData:self];
    
    char zero = 0;
    for ( int i = ([self length] - 1) % 4; i < 3; i++ )
        [newData appendBytes:&zero length:1];
    
    return [[newData copy] autorelease];
}

+ (NSData *) dataWithOSCBlobBytes:(char *)buf length:(NSUInteger *)outLength
{
    UInt32 dataSize = *((UInt32 *)buf);
    dataSize = OSSwapBigToHostInt32( dataSize );
    *outLength = dataSize;
    buf += 4;
    return [NSData dataWithBytes:buf length:dataSize];
}

@end
