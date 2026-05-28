//
//  F53OSCServer.m
//  F53OSC
//
//  Created by Siobhán Dougall on 3/23/11.
//  Copyright (c) 2011-2026 Figure 53 LLC, https://figure53.com
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

#import "F53OSCServer.h"

#import "F53OSCFoundationAdditions.h"
#import "F53OSCEncryptHandshake.h"


NS_ASSUME_NONNULL_BEGIN

@interface F53OSCServer ()

@property (atomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong, readwrite) F53OSCSocket *tcpSocket;
@property (nonatomic, strong, readwrite) F53OSCSocket *udpSocket;
@property (strong) NSMutableDictionary<NSNumber *, F53OSCSocket *> *activeTcpSockets;   // F53OSCSockets keyed by index of when the connection was accepted.
@property (strong) NSMutableDictionary<NSNumber *, NSMutableData *> *activeData;        // NSMutableData keyed by index; buffers the incoming data.
@property (strong) NSMutableDictionary<NSNumber *, NSMutableDictionary *> *activeState; // NSMutableDictionary keyed by index; stores state of incoming data.
@property (assign) long activeIndex;
@property (strong) NSMapTable<F53OSCSocket *, NSNumber *> *socketToKey;                 // weak-keyed map from accepted F53OSCSocket to its activeIndex key.

@property (strong, nullable) dispatch_source_t udpSweepTimer;

@end


@implementation F53OSCServer

+ (NSString *) validCharsForOSCMethod
{
    return @"\"$%&'()+-.0123456789:;<=>@ABCDEFGHIJKLMNOPQRSTUVWXYZ\\^_`abcdefghijklmnopqrstuvwxyz|~!";
}

+ (NSPredicate *) predicateForAttribute:(NSString *)attributeName
                     matchingOSCPattern:(NSString *)pattern
{
    // the `pattern` string is presumed to be an OSC message address component, so we do not filter the pattern itself for valid OSC chars
    // - NOTE however that OSC wildcards in the pattern will only match with valid OSC characters
    
    //NSLog( @"pattern   : %@", pattern );

    // Basic validity checks - failure returns a FALSE predicate
    if ( [[pattern componentsSeparatedByString:@"["] count] != [[pattern componentsSeparatedByString:@"]"] count] )
        return [NSPredicate predicateWithValue:NO];
    if ( [[pattern componentsSeparatedByString:@"{"] count] != [[pattern componentsSeparatedByString:@"}"] count] )
        return [NSPredicate predicateWithValue:NO];

    // Escape characters that are special in regex (ICU v3) but not special in OSC.
    pattern = [NSString stringWithSpecialRegexCharactersEscaped:pattern];
    //NSLog( @"cleaned   : %@", pattern );

    // Unescape a minus sign separating two characters inside square brackets, which is special in OSC (matches a range of characters).
    // NOTE: the +? quantifier is needed to match multiple escaped minus signs in a complex pattern like {[1\-3],[1][1\-3]}
    if ( [pattern rangeOfString:@"["].location != NSNotFound )
        pattern = [pattern stringByReplacingOccurrencesOfString:@"\\[([^\\]]+?)\\\\-(\\S+?)\\]" withString:@"[$1-$2]" options:NSRegularExpressionSearch range:NSMakeRange( 0, pattern.length )];
    
    // Replace commas inside curly braces with equivalent in regex (ICU v3)
    if ( [pattern rangeOfString:@"{"].location != NSNotFound )
    {
        NSUInteger open = NSNotFound;
        NSUInteger close = NSNotFound;
        for ( NSUInteger i = 0; i < pattern.length; i++ )
        {
            NSString *character = [pattern substringWithRange:NSMakeRange( i, 1 )];
            if ( [character isEqualToString:@"{"] )
                open = i;
            else if ( [character isEqualToString:@"}"] )
                close = i;
            
            if ( open != NSNotFound && close != NSNotFound )
            {
                pattern = [pattern stringByReplacingOccurrencesOfString:@","
                                                             withString:@"|"
                                                                options:0
                                                                  range:NSMakeRange( open, close - open + 1 )];
                
                // reset
                open = NSNotFound;
                close = NSNotFound;
            }
        }
    }
    
    // Replace characters that are special in OSC with their equivalents in regex (ICU v3).
    pattern = [pattern stringByReplacingOccurrencesOfString:@"[!" withString:@"[^"];
    pattern = [pattern stringByReplacingOccurrencesOfString:@"{" withString:@"("];
    pattern = [pattern stringByReplacingOccurrencesOfString:@"}" withString:@")"];
    
    // Replace OSC wildcard characters with their equivalents in regex (ICU v3).
    NSString *validOscChars = [NSString stringWithSpecialRegexCharactersEscaped:[F53OSCServer validCharsForOSCMethod]];
    NSString *wildCard = [NSString stringWithFormat:@"[%@]*", validOscChars]; // matches any sequence of zero or more valid OSC characters
    NSString *oneChar = [NSString stringWithFormat:@"[%@]", validOscChars];   // matches any single valid OSC character
    pattern = [pattern stringByReplacingOccurrencesOfString:@"*" withString:wildCard];
    pattern = [pattern stringByReplacingOccurrencesOfString:@"?" withString:oneChar];
    //NSLog( @"translated: %@", pattern );
    
    // MATCHES:
    // The left hand expression equals the right hand expression
    // using a regex-style comparison according to ICU v3. See:
    // http://icu.sourceforge.net/userguide/regexp.html
    // http://userguide.icu-project.org/strings/regexp#TOC-Regular-Expression-Metacharacters

    return [NSPredicate predicateWithFormat:@"%K MATCHES %@", attributeName, pattern];
}

- (instancetype) init
{
    return [self initWithDelegateQueue:nil]; // use main queue
}

- (instancetype) initWithDelegateQueue:(nullable dispatch_queue_t)queue
{
    self = [super init];
    if ( self )
    {
        self.delegate = nil;
        self.port = 0;
        self.udpReplyPort = 0;
        self.IPv6Enabled = NO;
        self.udpFlowIdleTimeout = 30.0;
        self.udpFlowSweepInterval = 5.0;
        self.tcpIdleTimeout = 0.0; // disabled by default

        if ( !queue )
            queue = dispatch_get_main_queue();
        self.queue = queue;
        
        self.tcpSocket = [F53OSCSocket tcpListenerWithCallbackQueue:queue];
        self.tcpSocket.delegate = self;
        self.tcpSocket.IPv6Enabled = self.isIPv6Enabled;

        self.udpSocket = [F53OSCSocket udpListenerWithCallbackQueue:queue];
        self.udpSocket.delegate = self;
        self.udpSocket.IPv6Enabled = self.isIPv6Enabled;
        
        // NOTE: after init, only read/write to these on the delegate queue
        self.activeTcpSockets = [NSMutableDictionary dictionaryWithCapacity:1];
        self.activeData = [NSMutableDictionary dictionaryWithCapacity:1];
        self.activeState = [NSMutableDictionary dictionaryWithCapacity:1];
        self.activeIndex = 0;

        self.socketToKey = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsWeakMemory
                                                 valueOptions:NSPointerFunctionsStrongMemory];
    }
    return self;
}

- (void) dealloc
{
    [self stopListening];
}

- (void) setPort:(UInt16)port
{
    _port = port;

    [self.tcpSocket stopListening];
    [self.udpSocket stopListening];
    self.tcpSocket.port = _port;
    self.udpSocket.port = _port;
}

- (void) setIPv6Enabled:(BOOL)IPv6Enabled
{
    _IPv6Enabled = IPv6Enabled;
    self.tcpSocket.IPv6Enabled = _IPv6Enabled;
    self.udpSocket.IPv6Enabled = _IPv6Enabled;
}

- (BOOL) startListening
{
    return [self startListening:nil];
}

- (BOOL) startListening:(out NSError **)outError
{
    self.tcpSocket.port = self.port;
    self.udpSocket.port = self.port;
    
    BOOL tcpStarted = [self.tcpSocket startListening:outError];
    BOOL udpStarted = [self.udpSocket startListening:outError];

    if ( tcpStarted && udpStarted )
        [self startUdpSweepTimer];

    return ( tcpStarted && udpStarted );
}

- (void) startUdpSweepTimer
{
    // cancel any existing timer first
    if ( self.udpSweepTimer )
    {
        dispatch_source_cancel( self.udpSweepTimer );
        self.udpSweepTimer = nil;
    }

    // Sweep is needed if EITHER UDP-flow expiry OR TCP idle-disconnect is enabled.
    if ( self.udpFlowIdleTimeout <= 0 && self.tcpIdleTimeout <= 0 )
        return;

    NSTimeInterval intervalSec = self.udpFlowSweepInterval > 0 ? self.udpFlowSweepInterval : 5.0;
    uint64_t intervalNs = (uint64_t)(intervalSec * NSEC_PER_SEC);
    dispatch_source_t timer = dispatch_source_create( DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.queue );
    dispatch_source_set_timer( timer,
                               dispatch_time( DISPATCH_TIME_NOW, intervalNs ),
                               intervalNs,
                               (uint64_t)(intervalSec * 0.1 * NSEC_PER_SEC) ); // 10% leeway
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler( timer, ^{
        [weakSelf sweepIdleFlows];
    } );
    dispatch_resume( timer );
    self.udpSweepTimer = timer;
}

- (void) stopListening
{
    if ( self.udpSweepTimer )
    {
        dispatch_source_cancel( self.udpSweepTimer );
        self.udpSweepTimer = nil;
    }

    [self.tcpSocket stopListening];
    [self.udpSocket stopListening];
    
    [self.activeTcpSockets removeAllObjects];
    [self.activeData removeAllObjects];
    [self.activeState removeAllObjects];
    [self.socketToKey removeAllObjects];
}

- (void) sweepIdleFlows
{
    NSDate *now = [NSDate date];
    NSTimeInterval udpThreshold = self.udpFlowIdleTimeout;
    NSTimeInterval tcpThreshold = self.tcpIdleTimeout;

    // collect keys to remove first to avoid mutating activeTcpSockets during enumeration
    NSMutableArray<NSNumber *> *idleKeys = [NSMutableArray array];
    NSMutableArray<F53OSCSocket *> *idleSockets = [NSMutableArray array];

    for ( NSNumber *key in self.activeTcpSockets )
    {
        F53OSCSocket *socket = self.activeTcpSockets[key];
        NSTimeInterval threshold = socket.isUdpSocket ? udpThreshold : tcpThreshold;
        if ( threshold <= 0 )
            continue; // sweep disabled for this transport

        NSDate *lastActivity = socket.lastActivityDate;
        if ( !lastActivity )
            continue; // no activity yet — protect newborn connections from the sweep

        if ( [now timeIntervalSinceDate:lastActivity] >= threshold )
        {
            [idleKeys addObject:key];
            [idleSockets addObject:socket];
        }
    }

    for ( NSUInteger i = 0; i < idleKeys.count; i++ )
    {
        F53OSCSocket *socket = idleSockets[i];
        NSNumber *key = idleKeys[i];

#if F53_OSC_SERVER_DEBUG
        NSLog( @"[F53OSCServer] sweeping idle %@ flow %@:%hu",
               socket.isUdpSocket ? @"UDP" : @"TCP", socket.host, socket.port );
#endif

        [socket disconnect];
        [self.socketToKey removeObjectForKey:socket];
        [self.activeTcpSockets removeObjectForKey:key];
        [self.activeData removeObjectForKey:key];
        [self.activeState removeObjectForKey:key];
    }
}

- (void) handleF53OSCControlMessage:(F53OSCMessage *)message
{
    if ( [F53OSCEncryptHandshake isEncryptHandshakeMessage:message] )
    {
        if ( self.keyPair )
        {
            if ( !message.replySocket.encrypter )
                [message.replySocket setKeyPair:self.keyPair];
            F53OSCEncryptHandshake *handshake = [F53OSCEncryptHandshake handshakeWithEncrypter:message.replySocket.encrypter];
            if ( [handshake processHandshakeMessage:message] )
            {
                if ( handshake.lastProcessedMessage == F53OSCEncryptionHandshakeMessageRequest )
                {
                    F53OSCMessage *approveEncryptingMessage = [handshake approveEncryptionMessage];
                    if ( approveEncryptingMessage )
                        [message.replySocket sendPacket:approveEncryptingMessage];
                }
                else if ( handshake.lastProcessedMessage == F53OSCEncryptionHandshakeMessageBegin )
                {
                    message.replySocket.isEncrypting = YES;
                }
                else
                {
                    NSLog(@"Error: received unexpected F53OSC encryption handshake message: %@", message);
                }
            }
        }
        else
        {
            // TODO: Report error to client that encryption is not supported
        }
    }
    else
    {
        NSLog(@"Error: unknown F53OSC control message received: %@", message);
    }
}

#pragma mark - F53OSCSocketDelegate

- (void) socketDidConnect:(F53OSCSocket *)socket
{
    // Server-side listener sockets do not initiate outbound connections.
    // accepted connections are surfaced via socket:didAcceptConnection: instead.
    // This callback is a no-op on the server.
}

- (void) socket:(F53OSCSocket *)listener didAcceptConnection:(F53OSCSocket *)acceptedSocket
{
#if F53_OSC_SERVER_DEBUG
    NSLog( @"server socket %p didAcceptConnection %p", listener, acceptedSocket );
#endif

    NSNumber *key = [NSNumber numberWithLong:self.activeIndex];

    acceptedSocket.delegate = self;
    [self.activeTcpSockets setObject:acceptedSocket forKey:key];
    [self.activeData setObject:[NSMutableData data] forKey:key];
    [self.activeState setObject:[NSMutableDictionary dictionaryWithDictionary:@{
        @"socket"       : acceptedSocket,
        @"dangling_ESC" : @NO
    }] forKey:key];
    [self.socketToKey setObject:key forKey:acceptedSocket];

    self.activeIndex++;
    
    if ( [self.delegate respondsToSelector:@selector(serverDidConnect:toSocket:)] )
    {
        dispatch_block_t block = ^{
            [self.delegate serverDidConnect:self toSocket:acceptedSocket];
        };
        
        if ( [NSThread isMainThread] )
            block();
        else
            dispatch_async( dispatch_get_main_queue(), block );
    }
}

- (void) socket:(F53OSCSocket *)socket didReceiveData:(NSData *)data
{
#if F53_OSC_SERVER_DEBUG
    NSLog( @"server socket %p didReceiveData of length %lu", socket, [data length] );
#endif
    
    if ( socket.isTcpSocket )
    {
        NSNumber *key = [self.socketToKey objectForKey:socket];
        if ( key == nil )
            return; // stale callback after disconnect

    NSMutableData *activeData = [self.activeData objectForKey:key];
    NSMutableDictionary<NSString *, id> *activeState = [self.activeState objectForKey:key];
    if ( activeData && activeState )
    {
            [F53OSCParser translateSlipData:data
                                     toData:activeData
                                  withState:activeState
                                destination:self.delegate
                             controlHandler:self];
        }
    }
    else // UDP — one accepted flow per source endpoint
    {
        [self.udpSocket.stats addBytes:[data length]];

        // Apply udpReplyPort if configured. The accepted UDP socket itself serves as the reply socket.
        if ( self.udpReplyPort != 0 )
            socket.port = self.udpReplyPort;

        [F53OSCParser processOscData:data
                      forDestination:self.delegate
                       replyToSocket:socket
                      controlHandler:nil
                        wasEncrypted:NO];
    }
}

- (void) socket:(F53OSCSocket *)socket didDisconnectWithError:(nullable NSError *)error
{
#if F53_OSC_SERVER_DEBUG
    NSLog( @"server socket %p didDisconnectWithError: %@", socket, error );
#endif

    NSNumber *key = [self.socketToKey objectForKey:socket];
    if ( key == nil )
        return;

            socket.isEncrypting = NO;
    [self.socketToKey removeObjectForKey:socket];

        if ( [self.delegate respondsToSelector:@selector(serverDidDisconnect:fromSocket:)] )
        {
            dispatch_block_t block = ^{
                [self.delegate serverDidDisconnect:self fromSocket:socket];
            };
            
            if ( [NSThread isMainThread] )
                block();
            else
                dispatch_async( dispatch_get_main_queue(), block );
        }
        
    [self.activeTcpSockets removeObjectForKey:key];
    [self.activeData removeObjectForKey:key];
    [self.activeState removeObjectForKey:key];
}

@end

NS_ASSUME_NONNULL_END
