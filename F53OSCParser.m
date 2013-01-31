//
//  F53OSCParser.m
//
//  Created by Christopher Ashworth on 1/30/13.
//
//  Copyright (c) 2013 Figure 53 LLC, http://figure53.com
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

#import "F53OSCParser.h"
#import "F53OSCMessage.h"
#import "F53OSCSocket.h"
#import "F53OSCFoundationAdditions.h"


@interface F53OSCParser (Private)

+ (void) processMessageData:(NSData *)data forDestination:(id <F53OSCPacketDestination>)destination replyToSocket:(F53OSCSocket *)socket;
+ (void) processBundleData:(NSData *)data forDestination:(id <F53OSCPacketDestination>)destination replyToSocket:(F53OSCSocket *)socket;

@end

@implementation F53OSCParser (private)

+ (void) processMessageData:(NSData *)data forDestination:(id <F53OSCPacketDestination>)destination replyToSocket:(F53OSCSocket *)socket;
{
    NSUInteger length = [data length];
    const char *buffer = [data bytes];
    
    NSUInteger lengthOfRemainingBuffer = length;
    NSUInteger dataLength = 0;
    NSString *addressPattern = [NSString stringWithOSCStringBytes:buffer maxLength:lengthOfRemainingBuffer length:&dataLength];
    if ( addressPattern == nil || dataLength == 0 || dataLength > length )
    {
        NSLog( @"Error: Unable to parse OSC method address." );
        return;
    }
    
    buffer += dataLength;
    lengthOfRemainingBuffer -= dataLength;
    
    NSMutableArray *args = [NSMutableArray array];
    BOOL hasArguments = (lengthOfRemainingBuffer > 0);
    if ( hasArguments && buffer[0] == ',' )
    {
        NSString *typeTag = [NSString stringWithOSCStringBytes:buffer maxLength:lengthOfRemainingBuffer length:&dataLength];
        if ( typeTag == nil )
        {
            NSLog( @"Error: Unable to parse type tag for OSC method %@", addressPattern );
            return;
        }
        buffer += dataLength;
        lengthOfRemainingBuffer -= dataLength;
        
        NSInteger numArgs = [typeTag length] - 1;
        if ( numArgs > 0 )
        {
            for ( int i = 1; i < numArgs + 1; i++ )
            {
                NSString *stringArg = nil;
                NSData *dataArg = nil;
                NSNumber *numberArg = nil;
                
                char type = [typeTag characterAtIndex:i]; // (index starts at 1 because first char is ",")
                switch ( type )
                {
                    case 's':
                        stringArg = [NSString stringWithOSCStringBytes:buffer maxLength:lengthOfRemainingBuffer length:&dataLength];
                        if ( stringArg )
                        {
                            [args addObject:stringArg];
                            buffer += dataLength;
                            lengthOfRemainingBuffer -= dataLength;
                        }
                        else
                        {
                            NSLog( @"Error: Unable to parse string argument for OSC method %@", addressPattern );
                            return;
                        }
                        break;
                    case 'b':
                        dataArg = [NSData dataWithOSCBlobBytes:buffer maxLength:lengthOfRemainingBuffer length:&dataLength];
                        if ( dataArg )
                        {
                            [args addObject:dataArg];
                            buffer += dataLength + 4;
                            lengthOfRemainingBuffer -= (dataLength + 4);
                        }
                        else
                        {
                            NSLog( @"Error: Unable to parse blob argument for OSC method %@", addressPattern );
                            return;
                        }
                        break;
                    case 'i':
                        numberArg = [NSNumber numberWithOSCIntBytes:buffer maxLength:lengthOfRemainingBuffer];
                        if ( numberArg )
                        {
                            [args addObject:numberArg];
                            buffer += 4;
                            lengthOfRemainingBuffer -= 4;
                        }
                        else
                        {
                            NSLog( @"Error: Unable to parse int argument for OSC method %@", addressPattern );
                            return;
                        }
                        break;
                    case 'f':
                        numberArg = [NSNumber numberWithOSCFloatBytes:buffer maxLength:lengthOfRemainingBuffer];
                        if ( numberArg )
                        {
                            [args addObject:numberArg];
                            buffer += 4;
                            lengthOfRemainingBuffer -= 4;
                        }
                        else
                        {
                            NSLog( @"Error: Unable to parse float argument for OSC method %@", addressPattern );
                            return;
                        }
                        break;
                    default:
                        NSLog( @"Error: Unrecognized type '%c' found in type tag for OSC method %@", type, addressPattern );
                        return;
                }
            }
        }
    }
    
    [destination takeMessage:[F53OSCMessage messageWithAddressPattern:addressPattern arguments:args replySocket:socket]];
}

+ (void) processBundleData:(NSData *)data forDestination:(id <F53OSCPacketDestination>)destination replyToSocket:(F53OSCSocket *)socket;
{
    NSUInteger length = [data length];
    const char *buffer = [data bytes];
    
    NSUInteger lengthOfRemainingBuffer = length;
    NSUInteger dataLength = 0;
    NSString *bundlePrefix = [NSString stringWithOSCStringBytes:buffer maxLength:lengthOfRemainingBuffer length:&dataLength];
    if ( bundlePrefix == nil || dataLength == 0 || dataLength > length )
    {
        NSLog( @"Error: Unable to parse OSC bundle prefix." );
        return;
    }
    
    if ( [bundlePrefix isEqualToString:@"#bundle"] )
    {
        buffer += dataLength;
        lengthOfRemainingBuffer -= dataLength;
        
        if ( lengthOfRemainingBuffer > 8 )
        {
            //F53OSCTimeTag *timetag = [F53OSCTimeTag timeTagWithOSCTimeBytes:buffer];
            buffer += 8; // We're not currently using the time tag so we just skip it.
            lengthOfRemainingBuffer -= 8;
            
            while ( lengthOfRemainingBuffer > sizeof( UInt32 ) )
            {
                UInt32 elementLength = *((UInt32 *)buffer);
                elementLength = OSSwapBigToHostInt32( elementLength );
                buffer += sizeof( UInt32 );
                lengthOfRemainingBuffer -= sizeof( UInt32 );
                
                if ( elementLength > lengthOfRemainingBuffer )
                {
                    NSLog( @"Error: A message in the OSC bundle claimed to be larger than the bundle itself." );
                    return;
                }
                
                if ( buffer[0] == '/' ) // OSC message
                {
                    [self processMessageData:[NSData dataWithBytesNoCopy:(void *)buffer length:elementLength freeWhenDone:NO]
                              forDestination:destination
                               replyToSocket:socket];
                }
                else if ( buffer[0] == '#' ) // OSC bundle
                {
                    [self processBundleData:[NSData dataWithBytesNoCopy:(void *)buffer length:elementLength freeWhenDone:NO]
                             forDestination:destination
                              replyToSocket:socket];
                }
                else
                {
                    NSLog( @"Error: Bundle contained unrecognized OSC message of length %u.", elementLength );
                    return;
                }
                
                buffer += elementLength;
                lengthOfRemainingBuffer -= elementLength;
            }
        }
        else
        {
            NSLog( @"Warning: Received an empty OSC bundle message." );
        }
    }
    else
    {
        NSLog( @"Error: Received an invalid OSC bundle message." );
    }
}

@end

@implementation F53OSCParser

+ (void) processOscData:(NSData *)data forDestination:(id <F53OSCPacketDestination, NSObject>)destination replyToSocket:(F53OSCSocket *)socket
{
    if ( data == nil )
        return;
    
    NSUInteger length = [data length];
    if ( length == 0 )
        return;
    
    const char *buffer = [data bytes];
    
    if ( buffer[0] == '/' ) // OSC message
    {
        [self processMessageData:data forDestination:destination replyToSocket:socket];
    }
    else if ( buffer[0] == '#' ) // OSC bundle
    {
        [self processBundleData:data forDestination:destination replyToSocket:socket];
    }
    else
    {
        NSLog( @"Error: Unrecognized OSC message of length %lu.", length );
    }
}

@end
