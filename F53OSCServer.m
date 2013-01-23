//
//  F53OSCServer.m
//
//  Created by Sean Dougall on 3/23/11.
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

#include <netinet/in.h>

#import "F53OSCServer.h"
#import "F53OSCFoundationAdditions.h"

// UDP is limited to 65,507 bytes of data.
// See: http://en.wikipedia.org/wiki/User_Datagram_Protocol

#define maxPacketSize 65507


@interface F53OSCServer (Private)

+ (NSString *) _stringWithSpecialRegexCharactersEscaped:(NSString *)string;
- (void) _listenThread;
- (void) _receivedBuffer:(char *)buf length:(UInt32)length fromAddress:(struct sockaddr_in)remoteAddress;
- (void) _receivedMessageBuffer:(char *)buffer length:(UInt32)length fromAddress:(UInt32)remoteAddress;
- (void) _receivedBundleBuffer:(char *)buffer length:(UInt32)length fromAddress:(UInt32)remoteAddress;

@end


@implementation F53OSCServer (Private)

///
///  Escape characters that are special in regex (ICU v3) but not special in OSC.
///  Regex docs: http://userguide.icu-project.org/strings/regexp#TOC-Regular-Expression-Metacharacters
///  OSC docs: http://opensoundcontrol.org/spec-1_0
///
+ (NSString *) _stringWithSpecialRegexCharactersEscaped:(NSString *)string
{
    string = [string stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"]; // Do this first!
    string = [string stringByReplacingOccurrencesOfString:@"+" withString:@"\\+"];
    string = [string stringByReplacingOccurrencesOfString:@"-" withString:@"\\-"];
    string = [string stringByReplacingOccurrencesOfString:@"(" withString:@"\\("];
    string = [string stringByReplacingOccurrencesOfString:@")" withString:@"\\)"];
    string = [string stringByReplacingOccurrencesOfString:@"^" withString:@"\\^"];
    string = [string stringByReplacingOccurrencesOfString:@"$" withString:@"\\$"];
    string = [string stringByReplacingOccurrencesOfString:@"|" withString:@"\\|"];
    string = [string stringByReplacingOccurrencesOfString:@"." withString:@"\\."];
    return string;
}

- (void) _listenThread
{
	@autoreleasepool
	{
        if ( _listening )
            return;
        
        _listening = YES;
        
        //NSLog( @"OSC server starting..." );
        
        // Create the socket
        int udpSocket = socket( AF_INET, SOCK_DGRAM, IPPROTO_UDP );
        if ( udpSocket == -1 )
        {
            NSLog( @"OSC server was unable to create a UDP socket." );
            _listening = NO;
            return;
        }
        
        // Set up address structure
        struct sockaddr_in address;
        memset( &address, 0, sizeof( struct sockaddr_in ) );
        address.sin_family = AF_INET;
        address.sin_port = htons( _serverPort );
        address.sin_addr.s_addr = htonl( INADDR_ANY );
        
        // Bind the port
        int err = bind( udpSocket, (struct sockaddr *)&address, sizeof( address ) );
        if ( err == -1 )
        {
            NSLog( @"OSC server was unable to bind a socket on port %d.", _serverPort );
            _listening = NO;
            close( udpSocket );
            return;
        }
        
        //NSLog( @"OSC server listening on port %d with maximum length of %d bytes.", _serverPort, maxPacketSize );
        
        // Listen
        while ( _listening )
        {
            @autoreleasepool
            {
                char buffer[maxPacketSize];
                struct sockaddr_in remoteAddress;
                socklen_t sockLen = sizeof( remoteAddress );
                ssize_t bytes_read = recvfrom( udpSocket, buffer, maxPacketSize, 0, (struct sockaddr *)&remoteAddress, &sockLen );
                if ( bytes_read == -1 )
                {
                    NSLog( @"OSC server was unable to receive a UDP packet." );
                    _listening = NO;
                    close( udpSocket );
                    return;
                }
                
                // Act on the incoming message only if we're still supposed to be listening
                if ( _listening )
                {
                    [self _receivedBuffer:buffer length:(UInt32)bytes_read fromAddress:remoteAddress];
                }
            }
        }
        
        //NSLog( @"OSC server closing socket on port %d", _serverPort );
        close( udpSocket );    
	}
}

- (void) _receivedBuffer:(char *)buffer length:(UInt32)length fromAddress:(struct sockaddr_in)remoteAddress
{
    UInt32 address = ntohl( remoteAddress.sin_addr.s_addr );
    
    if ( buffer[0] == '/' ) // OSC message
    {
        [self _receivedMessageBuffer:buffer length:length fromAddress:address];
    }
    else if ( buffer[0] == '#' ) // OSC bundle
    {
        [self _receivedBundleBuffer:buffer length:length fromAddress:address];
    }
    else
    {
        NSLog( @"OSC server received an unrecognized message of length %i.", length );
    }
}

- (void) _receivedMessageBuffer:(char *)buffer length:(UInt32)length fromAddress:(UInt32)remoteAddress
{
    NSUInteger dataLength = 0;
    
    NSString *addressPattern = [NSString stringWithOSCStringBytes:buffer length:&dataLength];
    NSMutableArray *args = [NSMutableArray array];
    
    if ( dataLength <= length )
    {
        buffer += dataLength;
    }
    else
    {
        NSLog( @"OSC server encountered error parsing message buffer." );
        return;
    }
    
    if ( dataLength != length && buffer[0] == ',' )
    {
        NSString *typeTag = [NSString stringWithOSCStringBytes:buffer length:&dataLength];
        buffer += dataLength;
        
        NSInteger numArgs = [typeTag length] - 1;
        if ( numArgs > 0 )
        {
            for ( int i = 1; i < numArgs + 1; i++ )
            {
                char type = [typeTag characterAtIndex:i]; // (index starts at 1 because first char is ",")
                switch ( type )
                {
                    case 's':
                        [args addObject:[NSString stringWithOSCStringBytes:buffer length:&dataLength]];
                        buffer += dataLength;
                        break;
                    case 'b':
                        [args addObject:[NSData dataWithOSCBlobBytes:buffer length:&dataLength]];
                        buffer += dataLength + 4;
                        break;
                    case 'i':
                        [args addObject:[NSNumber numberWithOSCIntBytes:buffer]];
                        buffer += 4;
                        break;
                    case 'f':
                        [args addObject:[NSNumber numberWithOSCFloatBytes:buffer]];
                        buffer += 4;
                        break;
                    default:
                        NSLog( @"Unrecognized type '%c' found in type tag. This may result in undefined behavior.", type );
                        break;
                }
            }
        }
    }
    
    [_destination takeMessage:[F53OSCMessage messageWithAddressPattern:addressPattern arguments:args originAddress:remoteAddress]];
}

- (void) _receivedBundleBuffer:(char *)buffer length:(UInt32)length fromAddress:(UInt32)remoteAddress
{
    NSUInteger dataLength = 0;
    
    NSString *bundlePrefix = [NSString stringWithOSCStringBytes:buffer length:&dataLength];
    if ( [bundlePrefix isEqualToString:@"#bundle"] )
    {
        buffer += dataLength;
        
        //F53OSCTimeTag *timetag = [F53OSCTimeTag timeTagWithOSCTimeBytes:buffer];
        buffer += 8; // We're not currently using the time tag so we just skip it.
        dataLength += 8;
        
        if ( dataLength < length )
        {
            while( dataLength < length )
            {
                UInt32 elementLength = *((UInt32 *)buffer);
                elementLength = OSSwapBigToHostInt32( elementLength );
                buffer += 4;
                
                if ( buffer[0] == '/' ) // OSC message
                {
                    [self _receivedMessageBuffer:buffer length:elementLength fromAddress:remoteAddress];
                }
                else if ( buffer[0] == '#' ) // OSC bundle
                {
                    [self _receivedBundleBuffer:buffer length:elementLength fromAddress:remoteAddress];
                }
                
                buffer += elementLength;
                dataLength += elementLength;
            }
        }
        else
        {
            NSLog( @"OSC server received an empty bundle message." );
        }
    }
}

@end


@implementation F53OSCServer

+ (NSString *) validCharsForOSCMethod
{
    return @"\"$%&'()+-.0123456789:;<=>@ABCDEFGHIJKLMNOPQRSTUVWXYZ\\^_`abcdefghijklmnopqrstuvwxyz|~!";
}

+ (NSPredicate *) predicateForAttribute:(NSString *)attributeName 
                     matchingOSCPattern:(NSString *)pattern
{
    //NSLog( @"pattern   : %@", pattern );
    
    // Basic validity checks.
    if ( [[pattern componentsSeparatedByString:@"["] count] != [[pattern componentsSeparatedByString:@"]"] count] )
        return nil;
    if ( [[pattern componentsSeparatedByString:@"{"] count] != [[pattern componentsSeparatedByString:@"}"] count] )
        return nil;
    
    NSString *validOscChars = [F53OSCServer _stringWithSpecialRegexCharactersEscaped:[F53OSCServer validCharsForOSCMethod]];
    NSString *wildCard = [NSString stringWithFormat:@"[%@]*", validOscChars];
    NSString *oneChar = [NSString stringWithFormat:@"[%@]{1}?", validOscChars];
    
    // Escape characters that are special in regex (ICU v3) but not special in OSC.
    pattern = [F53OSCServer _stringWithSpecialRegexCharactersEscaped:pattern];
    //NSLog( @"cleaned   : %@", pattern );
    
    // Replace characters that are special in OSC with their equivalents in regex (ICU v3).
    pattern = [pattern stringByReplacingOccurrencesOfString:@"*" withString:wildCard];
    pattern = [pattern stringByReplacingOccurrencesOfString:@"?" withString:oneChar];
    pattern = [pattern stringByReplacingOccurrencesOfString:@"[!" withString:@"[^"];
    pattern = [pattern stringByReplacingOccurrencesOfString:@"{" withString:@"("];
    pattern = [pattern stringByReplacingOccurrencesOfString:@"}" withString:@")"];
    pattern = [pattern stringByReplacingOccurrencesOfString:@"," withString:@"|"];
    //NSLog( @"translated: %@", pattern );
    
    // MATCHES:
    // The left hand expression equals the right hand expression 
    // using a regex-style comparison according to ICU v3. See:
    // http://icu.sourceforge.net/userguide/regexp.html
    // http://userguide.icu-project.org/strings/regexp#TOC-Regular-Expression-Metacharacters
    
    return [NSPredicate predicateWithFormat:@"%K MATCHES %@", attributeName, pattern];
}

- (id) init
{
    self = [super init];
    if ( self )
    {
        _destination = nil;
        _serverPort = 53535;
        _listening = NO;
    }
    return self;
}

- (void) dealloc
{
    [self stopListening];
    
    [_destination release];
    _destination = nil;
    
    [super dealloc];
}

@synthesize destination = _destination;

@synthesize port = _serverPort;

- (void) startListening
{
    [NSThread detachNewThreadSelector:@selector( _listenThread ) toTarget:self withObject:nil];
}

- (void) stopListening
{
    // FIXME: this won't ever stop the other thread unless one more message is received...
    _listening = NO;
}

@end
