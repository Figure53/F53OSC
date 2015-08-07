//
//  F53OSCServer.h
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

#import <Foundation/Foundation.h>

#import "F53OSC.h"

#define F53_OSC_SERVER_DEBUG 0

@interface F53OSCServer : NSObject <GCDAsyncSocketDelegate, GCDAsyncUdpSocketDelegate>
{
    id <F53OSCPacketDestination> __weak _delegate;
    UInt16 _port;
    UInt16 _udpReplyPort;
    F53OSCSocket *_tcpSocket;
    F53OSCSocket *_udpSocket;
    NSMutableDictionary *_activeTcpSockets;  // F53OSCSockets keyed by index of when the connection was accepted.
    NSMutableDictionary *_activeData;        // NSMutableData keyed by index; buffers the incoming data.
    NSMutableDictionary *_activeState;       // NSMutableDictionary keyed by index; stores state of incoming data.
    NSInteger _activeIndex;
}

+ (NSString *) validCharsForOSCMethod;
+ (NSPredicate *) predicateForAttribute:(NSString *)attributeName 
                     matchingOSCPattern:(NSString *)pattern;

@property (nonatomic, weak) id <F53OSCPacketDestination> delegate;
@property (nonatomic, assign) UInt16 port;
@property (nonatomic, assign) UInt16 udpReplyPort;

- (BOOL) startListening;
- (void) stopListening;

- (F53OSCSocket *)udpSocket;
- (F53OSCSocket *)tcpSocket;

@end
