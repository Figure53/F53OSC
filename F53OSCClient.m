//
//  F53OSCClient.m
//
//  Created by Sean Dougall on 1/20/11.
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

#import "F53OSCClient.h"
#import "F53OSCPacket.h"
#import "F53NSString.h"

@interface F53OSCClient (Private)

- (void) _sendUDPData:(NSData *)data toAddress:(UInt32)ipAddress port:(UInt16)port;

@end


@implementation F53OSCClient (Private)

- (void) _sendUDPData:(NSData *)data toAddress:(UInt32)ipAddress port:(UInt16)port
{
    // Create the socket
    int udpSocket = socket( AF_INET, SOCK_DGRAM, IPPROTO_UDP );
    if ( udpSocket == -1 )
        return;
    
    // Set up address/port structure
    struct sockaddr_in address;
    memset( &address, 0, sizeof( struct sockaddr_in ) );
    address.sin_family = AF_INET;
    address.sin_port = htons( port );
    address.sin_addr.s_addr = htonl( ipAddress );
    
    // Get buffer from data
    UInt8 *buffer = (UInt8 *)[data bytes];
    NSUInteger bufferLength = [data length];
    
    // Send the data
    size_t bytesSent = sendto( udpSocket, buffer, bufferLength, 0, (struct sockaddr *)&address, sizeof( struct sockaddr_in ) );
    if ( bytesSent < bufferLength )
    {
        NSLog( @"Error: Unable to send full buffer. Error %s.", strerror( errno ) );
        return;
    }
    
    close( udpSocket );
}

@end


@implementation F53OSCClient

- (id) init
{
    self = [super init];
    if ( self ) 
    {
        _serverAddress = 0x7f000001; // Default to localhost
        _serverPort = 53000;         // QLab is 53000, Stagetracker is 57115.
        _userData = nil;
    }
    return self;
}

- (void) dealloc
{
    [_userData release];
    _userData = nil;
    
    [super dealloc];
}

- (void) encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:[NSNumber numberWithUnsignedInt:_serverAddress] forKey:@"serverAddress"];
    [coder encodeObject:[NSNumber numberWithUnsignedShort:_serverPort] forKey:@"serverPort"];
    [coder encodeObject:_userData forKey:@"userData"];
}

- (id) initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if ( self )
    {
        _serverAddress = [[coder decodeObjectForKey:@"serverAddress"] unsignedIntValue];
        _serverPort = [[coder decodeObjectForKey:@"serverPort"] unsignedShortValue];
        _userData = [[coder decodeObjectForKey:@"userData"] retain];
    }
    return self;
}

- (NSString *) URL
{
    return [NSString stringWithFormat:@"%d.%d.%d.%d",
            (_serverAddress >> 24) & 0xff,
            (_serverAddress >> 16) & 0xff,
            (_serverAddress >>  8) & 0xff,
            (_serverAddress >>  0) & 0xff];
}

- (void) setURL:(NSString *)url
{
    if ( url == nil )
    {
        _serverAddress = 0x7f000001;
        return;
    }
    
    NSArray *urlParts = [url componentsSeparatedByString:@"."];
    if ( [urlParts count] != 4 || [[urlParts objectAtIndex:0] integerValue] == 0 )
    {
        NSLog( @"Error: domain-based URLs not currently supported. Use IP address instead. %@", urlParts );
        return;
    }
    
    _serverAddress = ([[urlParts objectAtIndex:0] intValue] << 24) +
                     ([[urlParts objectAtIndex:1] intValue] << 16) +
                     ([[urlParts objectAtIndex:2] intValue] <<  8) +
                     ([[urlParts objectAtIndex:3] intValue] <<  0);
}

@synthesize serverAddress = _serverAddress;

@synthesize port = _serverPort;

@synthesize userData = _userData;

- (NSString *) title
{
    return [NSString stringWithFormat:@"%@ : %u", [NSString addressInDotNotation:_serverAddress], _serverPort ];
}

- (void) sendPacket:(F53OSCPacket *)packet
{
    [self _sendUDPData:[packet packetData] toAddress:_serverAddress port:_serverPort];
}

@end

