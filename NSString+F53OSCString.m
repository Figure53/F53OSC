//
//  NSString+F53OSCString.m
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

#import "NSString+F53OSCString.h"


@implementation NSString (F53OSCStringAdditions)

- (NSData *) oscStringData
{
    //  A note on the 4s: For OSC, strings are all null-terminated and in multiples of 4 bytes.
    //  If the data is already a multiple of 4 bytes, it needs to have four null bytes appended.
    
    NSUInteger length = [self lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    NSUInteger stringLength = length;
    const char *bytes = [self cStringUsingEncoding:NSUTF8StringEncoding];
    length = 4 * ( ceil( (length + 1) / 4.0 ) );

    char *string = malloc( length * sizeof( char ) );
    NSUInteger i;
    for ( i = 0; i < stringLength; i++ )
        string[i] = bytes[i];
    for ( ; i < length; i++ )
        string[i] = 0;
         
    NSData *data = [NSData dataWithBytes:string length:length];
    free( string );
    return data;
}

///
///  An OSC string is a sequence of non-null ASCII characters followed by a null,
///  followed by 0-3 additional null characters to make the total number of bits a multiple of 32.
///
+ (NSString *) stringWithOSCStringBytes:(const char *)buf maxLength:(NSUInteger)maxLength length:(NSUInteger *)outLength
{
    if ( buf == NULL || maxLength == 0 )
        return nil;
    
    for ( NSUInteger index = 0; index < maxLength; index++ )
    {
        if ( buf[index] == 0 )
            goto valid; // found a NULL character within the buffer
    }
    return nil; // Buffer wasn't null terminated, so it's not a valid OSC string.
    
valid:;
    
    NSString *result = nil;
    
    result = [NSString stringWithUTF8String:buf];
    *outLength = 4 * ceil( ([result length] + 1) / 4.0 );
    return result;
}

@end
