//
//  F53OSCParser.m
//
//  Created by Christopher Ashworth on 1/30/13.
//
//  Copyright (c) 2013-2016 Figure 53 LLC, http://figure53.com
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

#import "F53OSCParser.h"
#import "F53OSCMessage.h"
#import "F53OSCSocket.h"
#import "F53OSCFoundationAdditions.h"

#define END             0300    /* indicates end of packet */
#define ESC             0333    /* indicates byte stuffing */
#define ESC_END         0334    /* ESC ESC_END means END data byte */
#define ESC_ESC         0335    /* ESC ESC_ESC means ESC data byte */


@interface F53OSCParser (Private)

+ (void) processMessageData:(NSData *)data forDestination:(id <F53OSCPacketDestination>)destination replyToSocket:(F53OSCSocket *)socket;
+ (void) processBundleData:(NSData *)data forDestination:(id <F53OSCPacketDestination>)destination replyToSocket:(F53OSCSocket *)socket;

@end

@implementation F53OSCParser (private)

+ (void) processMessageData:(NSData *)data forDestination:(id <F53OSCPacketDestination>)destination replyToSocket:(F53OSCSocket *)socket
{
    F53OSCMessage *inbound = [self parseOscMessageData:data];
    
    if (inbound == nil)
    {
        return;
    }
    else
    {
        inbound.replySocket = socket;
        [destination takeMessage:inbound];
    }
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
                    NSLog( @"Error: Bundle contained unrecognized OSC message of length %u.", (unsigned int)elementLength );
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

+ (F53OSCMessage *) parseOscMessageData:(NSData *)data
{
    NSUInteger length = [data length];
    const char *buffer = [data bytes];
    
    NSUInteger lengthOfRemainingBuffer = length;
    NSUInteger dataLength = 0;
    NSString *addressPattern = [NSString stringWithOSCStringBytes:buffer maxLength:lengthOfRemainingBuffer length:&dataLength];
    if ( addressPattern == nil || dataLength == 0 || dataLength > length )
    {
        NSLog( @"Error: Unable to parse OSC method address." );
        return nil;
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
            return nil;
        }
        buffer += dataLength;
        lengthOfRemainingBuffer -= dataLength;
        
        if ( [[NSUserDefaults standardUserDefaults] boolForKey:@"debugIncomingOSC"] )
        {
            NSLog( @"Incoming OSC message:" );
            NSLog( @"  %@", addressPattern );
        }
        
        NSInteger numArgs = [typeTag length] - 1;
        if ( numArgs > 0 )
        {
            if ( [[NSUserDefaults standardUserDefaults] boolForKey:@"debugIncomingOSC"] )
                NSLog( @"  arguments:" );
            
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
                            
                            if ( [[NSUserDefaults standardUserDefaults] boolForKey:@"debugIncomingOSC"] )
                                NSLog( @"    string: \"%@\"", stringArg );
                        }
                        else
                        {
                            NSLog( @"Error: Unable to parse string argument for OSC method %@", addressPattern );
                            return nil;
                        }
                        break;
                    case 'b':
                        dataArg = [NSData dataWithOSCBlobBytes:buffer maxLength:lengthOfRemainingBuffer length:&dataLength];
                        if ( dataArg )
                        {
                            [args addObject:dataArg];
                            buffer += dataLength + 4;
                            lengthOfRemainingBuffer -= (dataLength + 4);
                            
                            if ( [[NSUserDefaults standardUserDefaults] boolForKey:@"debugIncomingOSC"] )
                                NSLog( @"    blob: %@", dataArg );
                        }
                        else
                        {
                            NSLog( @"Error: Unable to parse blob argument for OSC method %@", addressPattern );
                            return nil;
                        }
                        break;
                    case 'i':
                        numberArg = [NSNumber numberWithOSCIntBytes:buffer maxLength:lengthOfRemainingBuffer];
                        if ( numberArg )
                        {
                            [args addObject:numberArg];
                            buffer += 4;
                            lengthOfRemainingBuffer -= 4;
                            
                            if ( [[NSUserDefaults standardUserDefaults] boolForKey:@"debugIncomingOSC"] )
                                NSLog( @"    int: %@", numberArg );
                        }
                        else
                        {
                            NSLog( @"Error: Unable to parse int argument for OSC method %@", addressPattern );
                            return nil;
                        }
                        break;
                    case 'f':
                        numberArg = [NSNumber numberWithOSCFloatBytes:buffer maxLength:lengthOfRemainingBuffer];
                        if ( numberArg )
                        {
                            [args addObject:numberArg];
                            buffer += 4;
                            lengthOfRemainingBuffer -= 4;
                            
                            if ( [[NSUserDefaults standardUserDefaults] boolForKey:@"debugIncomingOSC"] )
                                NSLog( @"    float: %@", numberArg );
                        }
                        else
                        {
                            NSLog( @"Error: Unable to parse float argument for OSC method %@", addressPattern );
                            return nil;
                        }
                        break;
                    default:
                        NSLog( @"Error: Unrecognized type '%c' found in type tag for OSC method %@", type, addressPattern );
                        return nil;
                }
            }
        }
    }
    
    return [F53OSCMessage messageWithAddressPattern:addressPattern arguments:args replySocket:nil];
}

+ (void) processOscData:(NSData *)data forDestination:(id <F53OSCPacketDestination, NSObject>)destination replyToSocket:(F53OSCSocket *)socket
{
    if ( data == nil || destination == nil )
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
        NSLog( @"Error: Unrecognized OSC message of length %lu.", (unsigned long)length );
    }
}

+ (void) translateSlipData:(NSData *)slipData
                    toData:(NSMutableData *)data
                 withState:(NSMutableDictionary *)state
               destination:(id <F53OSCPacketDestination>)destination
{
    // Incoming OSC messages are framed using the SLIP protocol: http://www.rfc-editor.org/rfc/rfc1055.txt
    
    F53OSCSocket *socket = [state objectForKey:@"socket"];
    if ( socket == nil )
    {
        NSLog( @"Error: F53OSCParser can not translate SLIP data without a socket." );
        return;
    }
    
    BOOL dangling_ESC = [[state objectForKey:@"dangling_ESC"] boolValue];
    
    Byte end[1] = {END};
    Byte esc[1] = {ESC};
    
    NSUInteger length = [slipData length];
    const Byte *buffer = [slipData bytes];
    for ( NSUInteger index = 0; index < length; index++ )
    {
        if ( dangling_ESC )
        {
            dangling_ESC = NO;
            [state setObject:@NO forKey:@"dangling_ESC"];
            if ( buffer[index] == ESC_END )
                [data appendBytes:end length:1];
            else if ( buffer[index] == ESC_ESC )
                [data appendBytes:esc length:1];
            else // Protocol violation. Pass the byte along and hope for the best.
                [data appendBytes:&(buffer[index]) length:1];
        }
        else if ( buffer[index] == END )
        {
            // The data is now a complete message.
            //NSLog( @"socket %p dispatching OSC data of length %lu", sock, [data length] );
            [F53OSCParser processOscData:[NSData dataWithData:data] forDestination:destination replyToSocket:socket];
            [data setData:[NSData data]];
        }
        else if ( buffer[index] == ESC )
        {
            if ( index + 1 < length )
            {
                index++;
                if ( buffer[index] == ESC_END )
                    [data appendBytes:end length:1];
                else if ( buffer[index] == ESC_ESC )
                    [data appendBytes:esc length:1];
                else // Protocol violation. Pass the byte along and hope for the best.
                    [data appendBytes:&(buffer[index]) length:1];
            }
            else
            {
                // The incoming raw data stopped in the middle of an escape sequence.
                [state setObject:@YES forKey:@"dangling_ESC"];
            }
        }
        else
        {
            [data appendBytes:&(buffer[index]) length:1];
        }
    }
}

@end
