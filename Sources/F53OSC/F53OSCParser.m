//
//  F53OSCParser.m
//  F53OSC
//
//  Created by Christopher Ashworth on 1/30/13.
//  Copyright (c) 2013-2025 Figure 53 LLC, https://figure53.com
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

#import "F53OSCParser.h"

#if __has_include(<F53OSC/F53OSC-Swift.h>) // F53OSC_BUILT_AS_FRAMEWORK
#import <F53OSC/F53OSC-Swift.h>
#elif SWIFT_PACKAGE // Swift Package Manager
@import F53OSCEncrypt;
#endif
#import "F53OSCMessage.h"
#import "F53OSCSocket.h"
#import "F53OSCFoundationAdditions.h"


NS_ASSUME_NONNULL_BEGIN

#define END             0300    /* indicates end of packet */
#define ESC             0333    /* indicates byte stuffing */
#define ESC_END         0334    /* ESC ESC_END means END data byte */
#define ESC_ESC         0335    /* ESC ESC_ESC means ESC data byte */

@interface F53OSCParser (Private)

+ (void) processMessageData:(NSData *)data forDestination:(id<F53OSCPacketDestination>)destination replyToSocket:(F53OSCSocket *)socket;
+ (void) processBundleData:(NSData *)data forDestination:(id<F53OSCPacketDestination>)destination replyToSocket:(F53OSCSocket *)socket;

@end

@implementation F53OSCParser (Private)

+ (void) processMessageData:(NSData *)data forDestination:(id<F53OSCPacketDestination>)destination replyToSocket:(F53OSCSocket *)socket
{
    F53OSCMessage *inbound = [self parseOscMessageData:data];
    if ( inbound == nil )
        return;
    
    inbound.replySocket = socket;
    [destination takeMessage:(F53OSCMessage * _Nonnull)inbound];
}

+ (void) processBundleData:(NSData *)data forDestination:(id<F53OSCPacketDestination>)destination replyToSocket:(F53OSCSocket *)socket;
{
    NSUInteger length = [data length];
    const char *buffer = [data bytes];
    
    NSUInteger lengthOfRemainingBuffer = length;
    NSUInteger bytesRead = 0;
    NSString *bundlePrefix = [NSString stringWithOSCStringBytes:buffer maxLength:lengthOfRemainingBuffer bytesRead:&bytesRead];
    if ( bundlePrefix == nil || bytesRead == 0 || bytesRead > length )
    {
        NSLog( @"Error: Unable to parse OSC bundle prefix." );
        return;
    }
    
    if ( [bundlePrefix isEqualToString:@"#bundle"] )
    {
        buffer += bytesRead;
        lengthOfRemainingBuffer -= bytesRead;
        
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

+ (nullable F53OSCMessage *) parseOscMessageData:(NSData *)data
{
    NSUInteger length = [data length];
    const char *buffer = [data bytes];
    
    NSUInteger lengthOfRemainingBuffer = length;
    NSUInteger bytesRead = 0;
    NSString *addressPattern = [NSString stringWithOSCStringBytes:buffer maxLength:lengthOfRemainingBuffer bytesRead:&bytesRead];
    if ( addressPattern == nil || bytesRead == 0 || bytesRead > length )
    {
        NSLog( @"Error: Unable to parse OSC method address." );
        return nil;
    }
    
    buffer += bytesRead;
    lengthOfRemainingBuffer -= bytesRead;
    
    NSMutableArray<id> *args = [NSMutableArray array];
    BOOL hasArguments = (lengthOfRemainingBuffer > 0);
    if ( hasArguments && buffer[0] == ',' )
    {
        NSString *typeTag = [NSString stringWithOSCStringBytes:buffer maxLength:lengthOfRemainingBuffer bytesRead:&bytesRead];
        if ( typeTag == nil )
        {
            NSLog( @"Error: Unable to parse type tag for OSC method %@", addressPattern );
            return nil;
        }
        buffer += bytesRead;
        lengthOfRemainingBuffer -= bytesRead;

        BOOL debugIncomingOSC = [[NSUserDefaults standardUserDefaults] boolForKey:@"debugIncomingOSC"];
        if ( debugIncomingOSC )
        {
            NSLog( @"Incoming OSC message:" );
            NSLog( @"  %@", addressPattern );
        }
        
        NSInteger numArgs = [typeTag length] - 1;
        if ( numArgs > 0 )
        {
            if ( debugIncomingOSC )
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
                        bytesRead = 0; // reset
                        stringArg = [NSString stringWithOSCStringBytes:buffer maxLength:lengthOfRemainingBuffer bytesRead:&bytesRead];
                        if ( stringArg != nil )
                        {
                            [args addObject:stringArg];
                            buffer += bytesRead;
                            lengthOfRemainingBuffer -= bytesRead;
                            
                            if ( debugIncomingOSC )
                                NSLog( @"    string: \"%@\"", stringArg );
                        }
                        else
                        {
                            NSLog( @"Error: Unable to parse string argument for OSC method %@", addressPattern );
                            return nil;
                        }
                        break;
                    case 'b':
                        bytesRead = 0; // reset
                        dataArg = [NSData dataWithOSCBlobBytes:buffer maxLength:lengthOfRemainingBuffer bytesRead:&bytesRead];
                        if ( dataArg != nil )
                        {
                            [args addObject:dataArg];
                            buffer += bytesRead;
                            lengthOfRemainingBuffer -= bytesRead;
                            
                            if ( debugIncomingOSC )
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
                        if ( numberArg != nil )
                        {
                            [args addObject:numberArg];
                            buffer += 4;
                            lengthOfRemainingBuffer -= 4;
                            
                            if ( debugIncomingOSC )
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
                        if ( numberArg != nil )
                        {
                            [args addObject:numberArg];
                            buffer += 4;
                            lengthOfRemainingBuffer -= 4;
                            
                            if ( debugIncomingOSC )
                                NSLog( @"    float: %@", numberArg );
                        }
                        else
                        {
                            NSLog( @"Error: Unable to parse float argument for OSC method %@", addressPattern );
                            return nil;
                        }
                        break;
                    case 'T':
                        [args addObject:[F53OSCValue oscTrue]]; // no data - do not advance the buffer
                        
                        if ( debugIncomingOSC )
                            NSLog( @"    TRUE" );
                        break;
                    case 'F':
                        [args addObject:[F53OSCValue oscFalse]]; // no data - do not advance the buffer
                        
                        if ( debugIncomingOSC )
                            NSLog( @"    FALSE" );
                        break;
                    case 'N':
                        [args addObject:[F53OSCValue oscNull]]; // no data - do not advance the buffer
                        
                        if ( debugIncomingOSC )
                            NSLog( @"    NULL" );
                        break;
                    case 'I':
                        [args addObject:[F53OSCValue oscImpulse]]; // no data - do not advance the buffer
                        
                        if ( debugIncomingOSC )
                            NSLog( @"    IMPLUSE" );
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

+ (void) processOscData:(NSData *)data forDestination:(id<F53OSCPacketDestination>)destination replyToSocket:(F53OSCSocket *)socket controlHandler:(nullable id<F53OSCControlHandler>)controlHandler wasEncrypted:(BOOL)wasEncrypted
{
    if ( data == nil || destination == nil )
        return;
    
    NSUInteger length = [data length];
    if ( length == 0 )
        return;
    
    const char *buffer = [data bytes];
    
    if ( buffer[0] == '*' ) // Encrypted data
    {
        if ( !socket.isEncrypting )
        {
            NSLog(@"Error: received encrypted OSC on a non-encrypted connection");
            return;
        }
        if ( length > 1 )
        {
            NSData *encryptedData = [data subdataWithRange:NSMakeRange(1, length-1)];
            NSData *decryptedData = [socket.encrypter decryptDataWithEncryptedData:encryptedData];
            if ( decryptedData )
                [F53OSCParser processOscData:decryptedData forDestination:destination replyToSocket:socket controlHandler:controlHandler wasEncrypted:YES];
            else
                NSLog(@"Error: failed to decrypt OSC data");
        }
        else
        {
            NSLog(@"Error: encrypted OSC data is too short");
        }
    }
    else
    {
        if ( socket.isEncrypting && !wasEncrypted )
        {
            NSLog(@"Error: received unencrypted OSC on an encrypted connection");
            return;
        }
        if ( buffer[0] == '/' ) // OSC message
        {
            [self processMessageData:data forDestination:destination replyToSocket:socket];
        }
        else if ( buffer[0] == '#' ) // OSC bundle
        {
            [self processBundleData:data forDestination:destination replyToSocket:socket];
        }
        else if ( buffer[0] == '!' ) // F53OSC control message
        {
            F53OSCMessage *inbound = [self parseOscMessageData:data];
            if ( inbound == nil )
                return;
            inbound.replySocket = socket;
            if ( controlHandler )
                [controlHandler handleF53OSCControlMessage:inbound];
            else
                NSLog(@"Error: Received F53OSC control message without a control handler: %@", inbound.addressPattern);
        }
        else
        {
            NSLog( @"Error: Unrecognized OSC message of length %lu.", (unsigned long)length );
        }
    }
}

+ (void) translateSlipData:(NSData *)slipData
                    toData:(NSMutableData *)data
                 withState:(NSMutableDictionary<NSString *, id> *)state
               destination:(id<F53OSCPacketDestination>)destination
            controlHandler:(nullable id<F53OSCControlHandler>)controlHandler
{
    // Incoming OSC messages are framed using the SLIP protocol: http://www.rfc-editor.org/rfc/rfc1055.txt
    // Hard cap on frame size guards against a misbehaving peer streaming non-END bytes
    // forever. Overflow resets the accumulator and continues scanning, so the next valid
    // END boundary recovers cleanly. 16 MB is a round number well above any realistic
    // OSC payload (cue dispatches are bytes, audio blobs are typically KB-scale) while
    // still small enough to bound runaway accumulator growth from a hostile peer.
    static const NSUInteger kF53OSCSlipMaxFrameBytes = 16 * 1024 * 1024;
    
    F53OSCSocket *socket = [state objectForKey:@"socket"];
    if ( socket == nil )
    {
        NSLog( @"Error: F53OSCParser can not translate SLIP data without a socket." );
        return;
    }
    
    NSUInteger length = [slipData length];
    const Byte *buffer = [slipData bytes];
    NSUInteger i = 0;
    BOOL danglingESC = [[state objectForKey:@"dangling_ESC"] boolValue];

    // Early guard: if a prior chunk has already pushed `data` past the cap, discard it now.
    if ( data.length > kF53OSCSlipMaxFrameBytes )
    {
        NSLog( @"Error: F53OSCParser SLIP frame exceeded %lu bytes; discarding accumulator.",
               (unsigned long)kF53OSCSlipMaxFrameBytes );
        [data setData:[NSData data]];
    }

    // 1. If we had a dangling ESC from the prior chunk, consume the first byte specially.
    if ( danglingESC && length > 0 )
        {
        Byte b = buffer[0];
        Byte out;
        if ( b == ESC_END )
            out = END;
        else if ( b == ESC_ESC )
            out = ESC;
        else // protocol violation. pass the byte along and hope for the best.
            out = b;
        [data appendBytes:&out length:1];
        danglingESC = NO;
            [state setObject:@NO forKey:@"dangling_ESC"];
        i = 1;
        }

    // 2. Scan the rest, finding runs of ordinary bytes between END/ESC.
    NSUInteger runStart = i;
    while ( i < length )
        {
        Byte b = buffer[i];
        if ( b == END )
        {
            // emit the run, then dispatch the completed message.
            if ( i > runStart )
                [data appendBytes:(buffer + runStart) length:(i - runStart)];
            //NSLog( @"socket %p dispatching OSC data of length %lu", socket, [data length] );
            [F53OSCParser processOscData:[NSData dataWithData:data] forDestination:destination replyToSocket:socket controlHandler:controlHandler wasEncrypted:NO];
            [data setData:[NSData data]];
            i++;
            runStart = i;
        }
        else if ( b == ESC )
        {
            // emit the run, then handle the escape sequence.
            if ( i > runStart )
                [data appendBytes:(buffer + runStart) length:(i - runStart)];
            if ( i + 1 < length )
            {
                Byte next = buffer[i + 1];
                Byte out;
                if ( next == ESC_END )
                    out = END;
                else if ( next == ESC_ESC )
                    out = ESC;
                else // protocol violation. pass the byte along and hope for the best.
                    out = next;
                [data appendBytes:&out length:1];
                i += 2;
                runStart = i;
            }
            else
            {
                // ESC at chunk boundary — set dangling state and exit.
                [state setObject:@YES forKey:@"dangling_ESC"];
                i++;
                runStart = i;
                break;
            }
        }
        else
        {
            i++;
        }
    }

    // 3. Emit any trailing run of ordinary bytes (capped).
    if ( runStart < length )
    {
        NSUInteger runLen = length - runStart;
        NSUInteger room = ( data.length < kF53OSCSlipMaxFrameBytes
                            ? kF53OSCSlipMaxFrameBytes - data.length : 0 );
        if ( runLen > room )
        {
            NSLog( @"Error: F53OSCParser SLIP frame would exceed %lu bytes; discarding accumulator.",
                   (unsigned long)kF53OSCSlipMaxFrameBytes );
            [data setData:[NSData data]];
        }
        else
        {
            [data appendBytes:(buffer + runStart) length:runLen];
        }
    }
}

+ (NSData *) slipFrameData:(NSData *)data
{
    // double-END SLIP framing: RFC 1055. Scan-for-runs: emit ordinary byte runs in
    // one appendBytes:length:, branch only on END/ESC.
    NSUInteger length  = data.length;
    const Byte *buffer = data.bytes;

    NSMutableData *slipData = [NSMutableData dataWithCapacity:length + 2 + (length / 16)];

    Byte end[1]     = { END };
    Byte esc_end[2] = { ESC, ESC_END };
    Byte esc_esc[2] = { ESC, ESC_ESC };

    [slipData appendBytes:end length:1]; // leading END

    NSUInteger runStart = 0;
    for ( NSUInteger i = 0; i < length; i++ )
    {
        Byte b = buffer[i];
        if ( b == END || b == ESC )
        {
            if ( i > runStart )
                [slipData appendBytes:(buffer + runStart) length:(i - runStart)];
            [slipData appendBytes:(b == END ? esc_end : esc_esc) length:2];
            runStart = i + 1;
        }
    }
    if ( runStart < length )
        [slipData appendBytes:(buffer + runStart) length:(length - runStart)];

    [slipData appendBytes:end length:1]; // trailing END
    return slipData;
}

@end

NS_ASSUME_NONNULL_END
