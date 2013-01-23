//
//  F53NSString.m
//
//  Created by Chris Ashworth on 4/10/05.
//
//  Copyright (c) 2005-2013 Figure 53 LLC, http://figure53.com
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

#import "F53NSString.h"
#import "F53NSArray.h"

@implementation NSString (F53NSString)

+ (NSString *) stringUUID
{
    CFUUIDRef uuid = CFUUIDCreate( kCFAllocatorDefault );
    NSString *uuidString = (NSString *)CFUUIDCreateString( kCFAllocatorDefault, uuid );
    CFRelease( uuid );
    return [uuidString autorelease];
}

+ (NSString *) stringWithAddressOfObject:(id)object
{
    return [NSString stringWithFormat:@"%p", object];
}

- (id) objectAtAddress
{
    NSScanner *s = [NSScanner scannerWithString:self];
    unsigned long long address;
    if ( [s scanHexLongLong:&address] )
        return (id)address;
    return nil;
}

+ (NSString *) stringByFormattingSeconds:(double)totalSeconds
{
    return [self stringByFormattingSeconds:totalSeconds decimalPlaces:2];
}

+ (NSString *) stringByFormattingSeconds:(double)totalSeconds decimalPlaces:(int)digits
{
    return [self stringByFormattingSeconds:totalSeconds decimalPlaces:digits showHours:NO];
}

+ (NSString *) stringByFormattingSeconds:(double)totalSeconds decimalPlaces:(int)digits showHours:(BOOL)showHours
{
    return [self stringByFormattingSeconds:totalSeconds decimalPlaces:digits showHours:showHours forcePositive:YES];
}

+ (NSString *) stringByFormattingSeconds:(double)totalSeconds decimalPlaces:(int)digits showHours:(BOOL)showHours forcePositive:(BOOL)forcePositive
{
    // hh:mm:ss.r...r
    
    if ( totalSeconds > 31536000 )  // The number of seconds in a year. Gotta pick some limit.
        totalSeconds = 31536000;
    
    BOOL wasNegative = (totalSeconds < 0) ? YES : NO;
    if ( wasNegative )
    {
        if ( forcePositive )
        {
            totalSeconds = 0;
            wasNegative = NO;
        }
        else
        {
            totalSeconds = -totalSeconds;
        }
    }
    
    int hours = floor( totalSeconds / 3600 );
    int minutes = floor( (totalSeconds / 60) - hours * 60 );
    int seconds = ((long)floor( totalSeconds ) % 60);
    int factor = pow( 10, digits );
    int remainder = (int)round( (totalSeconds - (double)floor( totalSeconds )) * factor );
    
    // Handle rounding up the chain...
    if ( remainder == factor )
    {
        remainder = 0;
        seconds++;
    }
    if ( seconds == 60 )
    {
        seconds = 0;
        minutes++;
    }
    if ( minutes == 60 )
    {
        minutes = 0;
        hours++;
    }
    
    NSString *hoursString;
    if ( hours == 0 )
    {
        if ( showHours )
            hoursString = @"00:";
        else
            hoursString = @"";
    }
    else if ( hours < 10 )
        hoursString = [NSString stringWithFormat:@"0%i:", hours];
    else
        hoursString = [NSString stringWithFormat:@"%i:", hours];
    
    NSString *minutesString;
    if ( minutes < 10 )
        minutesString = [NSString stringWithFormat:@"0%i:", minutes];
    else
        minutesString = [NSString stringWithFormat:@"%i:", minutes];
    
    NSString *secondsString;
    if ( seconds < 10 )
    {
        if ( digits )
            secondsString = [NSString stringWithFormat:@"0%i.", seconds];
        else
            secondsString = [NSString stringWithFormat:@"0%i", seconds];
    }
    else
    {
        if ( digits )
            secondsString = [NSString stringWithFormat:@"%i.", seconds];
        else
            secondsString = [NSString stringWithFormat:@"%i", seconds];
    }
    
    NSString *remainderString = @"";
    if ( digits )
    {
        int count = 1;
        int tempRemainder = remainder;
        while ( (tempRemainder < (factor / 10)) && (count < digits) )
        {
            remainderString = [remainderString stringByAppendingString:@"0"];
            tempRemainder *= 10;
            count++;
        }
        remainderString = [remainderString stringByAppendingFormat:@"%i", remainder];
    }
    
    if ( wasNegative )
    {
        return [[[[@"-" stringByAppendingString:hoursString]
                        stringByAppendingString:minutesString] 
                        stringByAppendingString:secondsString]
                        stringByAppendingString:remainderString];
    }
    else
    {
        return [[[hoursString stringByAppendingString:minutesString]
                              stringByAppendingString:secondsString]
                              stringByAppendingString:remainderString];
    }
}

///
///  This should really be an NSNumber extension, but whatever.
///
+ (double) secondsFromFormattedString:(NSString *)theString
{
    if ( theString == nil || [theString length] == 0 )
        return 0.0;
    
    BOOL wasNegative = NO;
    if ( [theString hasPrefix:@"-"] )
        wasNegative = YES;
    
    double seconds = 0.0;
    double minutes = 0.0;
    double hours = 0.0;
    
    NSString *searchString = [NSString stringWithString:theString];
    NSCharacterSet *delimiter = [NSCharacterSet characterSetWithCharactersInString:@":"];    
    NSRange range, searchRange;    
    
    searchRange.location = 0;
    searchRange.length = [theString length];
    
    // Get seconds.    
    range = [searchString rangeOfCharacterFromSet:delimiter options:NSBackwardsSearch range:searchRange];
    if ( range.location == NSNotFound )
    {
        seconds = fabs( [searchString doubleValue] );
        //NSLog( @"Only seconds left : %f (%@)", seconds, searchString );
    }
    else
    {
        seconds = fabs( [[searchString substringFromIndex:range.location + 1] doubleValue] );
        //NSLog( @"Found seconds at [%u , %u] : %f (%@)", range.location, range.length, seconds, [searchString substringFromIndex:range.location] );        
        
        // Get minutes.
        searchRange.length -= (searchRange.length - range.location);
        searchString = [searchString substringToIndex:range.location];
        range = [searchString rangeOfCharacterFromSet:delimiter options:NSBackwardsSearch range:searchRange];
        if ( range.location == NSNotFound )
        {
            minutes = fabs( [searchString doubleValue] );
            //NSLog( @"Only minutes left : %f (%@)", minutes, searchString );
        }
        else
        {
            minutes = fabs( [[searchString substringFromIndex:range.location + 1] doubleValue] );
            //NSLog( @"Found minutes at [%u , %u] : %f (%@)", range.location, range.length, minutes, [searchString substringFromIndex:range.location] );
            
            // Get hours.
            searchRange.length -= (searchRange.length - range.location);
            searchString = [searchString substringToIndex:range.location];
            range = [searchString rangeOfCharacterFromSet:delimiter options:NSBackwardsSearch range:searchRange];
            if ( range.location == NSNotFound )
            {
                hours = fabs( [searchString doubleValue] );
                //NSLog( @"Only hours left : %f (%@)", hours, searchString );
            }
            else
            {
                hours = fabs( [[searchString substringFromIndex:range.location + 1] doubleValue] );
                //NSLog( @"Found hours at [%u , %u] : %f (%@)", range.location, range.length, hours, [searchString substringFromIndex:range.location] );
            }
        }
    }
    
    //NSLog( @"Final result = %f hours, %f minutes, %f seconds", hours, minutes, seconds );
    
    double result = ((hours * 3600) + (minutes * 60) + seconds);
    if ( wasNegative )
        result = -result;
    return result;
}

+ (NSDictionary *) stringsFromMSCByteDataRepresentingNumberListPath:(const char *)bytes length:(int)length
{
    if ( bytes == nil || length == 0 )
        return nil;
    
    int i;
    NSString *qNumber = @"";
    NSString *qList = @"";
    NSString *qPath = @"";
    
    for ( i = 0; i < length; i++ )
    {
        switch ( bytes[i] )
        {
            case 0x00:
                i++;
                goto qList;
                break;
            case 0x30: qNumber = [qNumber stringByAppendingString:@"0"]; break;
            case 0x31: qNumber = [qNumber stringByAppendingString:@"1"]; break;
            case 0x32: qNumber = [qNumber stringByAppendingString:@"2"]; break;
            case 0x33: qNumber = [qNumber stringByAppendingString:@"3"]; break;
            case 0x34: qNumber = [qNumber stringByAppendingString:@"4"]; break;
            case 0x35: qNumber = [qNumber stringByAppendingString:@"5"]; break;
            case 0x36: qNumber = [qNumber stringByAppendingString:@"6"]; break;
            case 0x37: qNumber = [qNumber stringByAppendingString:@"7"]; break;
            case 0x38: qNumber = [qNumber stringByAppendingString:@"8"]; break;
            case 0x39: qNumber = [qNumber stringByAppendingString:@"9"]; break;
            case 0x2E: qNumber = [qNumber stringByAppendingString:@"."]; break;
            default: NSLog( @"Warning: stringFromMSCByteData: unrecognized byte value %i", bytes[i] ); break;
        }
    }
    
qList:
    
    for ( ; i < length; i++ )
    {
        switch ( bytes[i] )
        {
            case 0x00:
                i++;
                goto qPath;
                break;
            case 0x30: qList = [qList stringByAppendingString:@"0"]; break;
            case 0x31: qList = [qList stringByAppendingString:@"1"]; break;
            case 0x32: qList = [qList stringByAppendingString:@"2"]; break;
            case 0x33: qList = [qList stringByAppendingString:@"3"]; break;
            case 0x34: qList = [qList stringByAppendingString:@"4"]; break;
            case 0x35: qList = [qList stringByAppendingString:@"5"]; break;
            case 0x36: qList = [qList stringByAppendingString:@"6"]; break;
            case 0x37: qList = [qList stringByAppendingString:@"7"]; break;
            case 0x38: qList = [qList stringByAppendingString:@"8"]; break;
            case 0x39: qList = [qList stringByAppendingString:@"9"]; break;
            case 0x2E: qList = [qList stringByAppendingString:@"."]; break;
            default: NSLog( @"Warning: stringFromMSCByteData: unrecognized byte value %i", bytes[i] ); break;
        }
    }
    
qPath:
    
    for ( ; i < length; i++ )
    {
        switch ( bytes[i] )
        {
            case 0x00:
                i++;
                goto end;
                break;
            case 0x30: qPath = [qPath stringByAppendingString:@"0"]; break;
            case 0x31: qPath = [qPath stringByAppendingString:@"1"]; break;
            case 0x32: qPath = [qPath stringByAppendingString:@"2"]; break;
            case 0x33: qPath = [qPath stringByAppendingString:@"3"]; break;
            case 0x34: qPath = [qPath stringByAppendingString:@"4"]; break;
            case 0x35: qPath = [qPath stringByAppendingString:@"5"]; break;
            case 0x36: qPath = [qPath stringByAppendingString:@"6"]; break;
            case 0x37: qPath = [qPath stringByAppendingString:@"7"]; break;
            case 0x38: qPath = [qPath stringByAppendingString:@"8"]; break;
            case 0x39: qPath = [qPath stringByAppendingString:@"9"]; break;
            case 0x2E: qPath = [qPath stringByAppendingString:@"."]; break;
            default: NSLog( @"Warning: stringFromMSCByteData: unrecognized byte value %i", bytes[i] ); break;
        }
    }
    
end:
    
    return [NSDictionary dictionaryWithObjectsAndKeys:qNumber, @"Q_number", qList, @"Q_list", qPath, @"Q_path", nil];
}

+ (NSDictionary *) stringsFromMSCByteDataRepresentingList:(const char *)bytes length:(int)length
{
    if ( bytes == nil || length == 0 )
        return nil;
    
    NSString *qList = @"";
    
    for ( int i = 0; i < length; i++ )
    {
        switch ( bytes[i] )
        {
            case 0x00:
                i++;
                goto end;
                break;
            case 0x30: qList = [qList stringByAppendingString:@"0"]; break;
            case 0x31: qList = [qList stringByAppendingString:@"1"]; break;
            case 0x32: qList = [qList stringByAppendingString:@"2"]; break;
            case 0x33: qList = [qList stringByAppendingString:@"3"]; break;
            case 0x34: qList = [qList stringByAppendingString:@"4"]; break;
            case 0x35: qList = [qList stringByAppendingString:@"5"]; break;
            case 0x36: qList = [qList stringByAppendingString:@"6"]; break;
            case 0x37: qList = [qList stringByAppendingString:@"7"]; break;
            case 0x38: qList = [qList stringByAppendingString:@"8"]; break;
            case 0x39: qList = [qList stringByAppendingString:@"9"]; break;
            case 0x2E: qList = [qList stringByAppendingString:@"."]; break;
            default: NSLog( @"Warning: stringFromMSCByteData: unrecognized byte value %i", bytes[i] ); break;
        }
    }
    
end:
    
    return [NSDictionary dictionaryWithObjectsAndKeys:@"", @"Q_number", qList, @"Q_list", @"", @"Q_path", nil];
}

+ (NSString *) addressInDotNotation:(UInt32)address
{
    return [NSString stringWithFormat:@"%d.%d.%d.%d",
            (address >> 24) & 0xff,
            (address >> 16) & 0xff,
            (address >>  8) & 0xff,
            (address >>  0) & 0xff];
}

+ (UInt32) addressFromDotNotation:(NSString *)address
{
    NSArray *addressParts = [address componentsSeparatedByString:@"."];
    if ( [addressParts count] != 4 || [[addressParts objectAtIndex:0] integerValue] == 0 )
    {
        NSLog( @"Error: Not an IPv4 address in dot notation: %@", address );
        return 0x0;
    }
    
    UInt32 result = ([[addressParts objectAtIndex:0] integerValue] << 24) +
    ([[addressParts objectAtIndex:1] integerValue] << 16) + 
    ([[addressParts objectAtIndex:2] integerValue] <<  8) + 
    ([[addressParts objectAtIndex:3] integerValue] <<  0);
    
    return result;
}

#pragma mark -

- (NSArray *) canonicalPathComponents
{    
    return [[self stringByStandardizingPath] pathComponents];
}

- (NSArray *) canonicalPathComponentsRelativeTo:(NSString *)basePath
{
    NSArray *myPathComponents = [self canonicalPathComponents];
    NSArray *basePathComponents = [basePath canonicalPathComponents];
    
    // Check that both paths are absolute.
    // (We can't calculate a relative path if our path is already relative,
    // because we can't define how a relative path relates to an absolute path.
    // Same for if the base is relative.)    
    if    (   ([myPathComponents count] == 0) 
           || ([basePathComponents count] == 0) )
    {
        return nil;
    }
    if    (   (![[myPathComponents objectAtIndex:0] isEqualToString:@"/"]) 
           || (![[basePathComponents objectAtIndex:0] isEqualToString:@"/"]) )
    {
        return nil;
    }
    
    NSEnumerator *myPathEnumerator = [myPathComponents objectEnumerator];  
    NSEnumerator *basePathEnumerator = [basePathComponents objectEnumerator];
    NSString *myPathComp, *basePathComp;
    NSMutableArray *canonicalComponents = [NSMutableArray arrayWithCapacity:0];
    unsigned index = 0;
    
    while ( YES )
    {
        myPathComp = [myPathEnumerator nextObject];
        basePathComp = [basePathEnumerator nextObject];
        
        if ( myPathComp == nil )
        {
            // We've reached the end of the path, and all
            // components matched the base path.  
            break;
        } else if ( basePathComp == nil )
        {
            // We've run out of a base path.
            [canonicalComponents addObjectsFromArray:myPathComponents fromIndex:index];
            break;
        }
        else
        {
            if ( [myPathComp caseInsensitiveCompare:basePathComp] == NSOrderedSame )
            {
                // This component matches the base path 
                // at this point.  Skip it.
            }
            else
            {
                // We've found the first non matching component.
                // Add in the number of '..' components equal to 
                // the number of folders remaining in the base, 
                // and then put the rest of our components in.    
                [canonicalComponents addObject:@".."];
                while ( (basePathComp = [basePathEnumerator nextObject]) != nil )
                {
                    [canonicalComponents addObject:@".."];
                }
                [canonicalComponents addObjectsFromArray:myPathComponents fromIndex:index];
                break;
            }
        }
        
        index++;
    }
    
    return [NSArray arrayWithArray:canonicalComponents];
}

- (NSString *) stringByMakingPathRelativeTo:(NSString *)basePath
{    
    NSArray *relativeComponents = [self canonicalPathComponentsRelativeTo:basePath];
    return [relativeComponents componentsJoinedByString:@"/"];
}

- (NSString *) stringByMakingPathAbsoluteWithBase:(NSString *)basePath
{
    if ( [basePath isAbsolutePath] )
        return [[basePath stringByAppendingPathComponent:self] stringByStandardizingPath];
    else
        return nil;
}

- (NSString *) stringWithoutTrailingZeros
{
    NSRange range = [self rangeOfString:@"."];
    if ( range.length == 0 )
        return self;
    
    unichar c;
    int index = [self length]-1;
    
    while ( index >= 0 )
    {
        c = [self characterAtIndex:index];
        if ( c != '0' )
        {
            if ( c == '.' )
                index--;
            break;
        }
        index--;
    }
    
    if ( index >= 0 )
        return [self substringToIndex:index + 1];
    else
        return @"";
}

@end
