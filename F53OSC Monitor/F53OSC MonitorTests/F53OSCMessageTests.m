//
//  F53OSC_F53OSCMessageTests.m
//  F53OSC
//
//  Created by Brent Lord on 2/14/20.
//  Copyright (c) 2020 Figure 53, LLC. All rights reserved.
//

#if !__has_feature(objc_arc)
#error This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import "F53OSC.h"


NS_ASSUME_NONNULL_BEGIN

#ifdef MAC_OS_X_VERSION_10_12

@interface F53OSC_F53OSCMessageTests : XCTestCase <F53OSCPacketDestination, F53OSCClientDelegate>

@property (nonatomic, strong)           XCTestExpectation *clientConnectExpectation;
@property (nonatomic, strong)           NSMutableArray<XCTestExpectation *> *messageExpectations;
@property (nonatomic, strong)           NSMutableDictionary<NSString *, F53OSCMessage *> *matchedExpectations;
@property (nonatomic, strong)           F53OSCServer *oscServer;
@property (nonatomic, strong)           F53OSCClient *oscClient;

- (nullable id) oscMessageArgumentFromString:(NSString *)qsc typeTag:(NSString *)typeTag;

@end


@implementation F53OSC_F53OSCMessageTests

#pragma mark - XCTest setup/teardown

- (void) setUp
{
    [super setUp];
    
    // set up
    self.clientConnectExpectation = [[XCTestExpectation alloc] initWithDescription:@"F53OSCClient connect"];
    self.messageExpectations = [NSMutableArray arrayWithCapacity:0];
    self.matchedExpectations = [NSMutableDictionary dictionaryWithCapacity:0];
    
    UInt16 port = 53000;
    
    dispatch_queue_t oscQueue = dispatch_queue_create( "com.figure53.oscServer", DISPATCH_QUEUE_SERIAL );
    F53OSCServer *oscServer = [[F53OSCServer alloc] initWithDelegateQueue:oscQueue];
    oscServer.delegate = self;
    oscServer.port = port;
    oscServer.udpReplyPort = port + 1;
    self.oscServer = oscServer;
    
    BOOL isListening = [oscServer startListening];
    XCTAssertTrue( isListening, @"F53OSCServer was unable to start listening on port %hu.", oscServer.port );
    
    F53OSCClient *oscClient = [[F53OSCClient alloc] init];
    oscClient.useTcp = YES;
    oscClient.host = @"localhost";
    oscClient.port = port;
    oscClient.delegate = self;
    self.oscClient = oscClient;
    
    [self connectOSCClientAndVerify];
    
    __weak typeof(self) weakSelf = self;
    [self addTeardownBlock:^{
        weakSelf.oscClient.delegate = nil;
        [weakSelf.oscClient disconnect];
        
        weakSelf.oscServer.delegate = nil;
        [weakSelf.oscServer stopListening];
    }];
}


#pragma mark - Test helper methods

- (nullable id) oscMessageArgumentFromString:(NSString *)qsc typeTag:(NSString *)typeTag
{
    id arg = nil;
    
    // strip escaped quotes marking string argument
    if ( [typeTag isEqualToString:@"s"] ) // 's'
        arg = [qsc stringByReplacingOccurrencesOfString:@"\"" withString:@""];
    
    else if ( [typeTag isEqualToString:@"b"] ) // 'b'
    {
        if ( [qsc hasPrefix:@"#blob"] )
            qsc = [qsc substringFromIndex:5];
        if ( qsc )
            arg = [[NSData alloc] initWithBase64EncodedString:(NSString * _Nonnull)qsc options:0];
    }
    
    else if ( [typeTag isEqualToString:@"i"] || [typeTag isEqualToString:@"f"] )
    {
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        [formatter setLocale:[NSLocale currentLocale]];
        [formatter setAllowsFloats:YES];
        
        arg = [formatter numberFromString:qsc]; // 'i' or 'f'
    }
    
    else if ( [typeTag isEqualToString:@"T"] ) // 'T'
        arg = @YES;
    
    else if ( [typeTag isEqualToString:@"F"] ) // 'F'
        arg = @NO;
    
    else if ( [typeTag isEqualToString:@"N"] ) // 'N'
        arg = [NSNull null];
    
    else if ( [typeTag isEqualToString:@"I"] ) // 'I'
        arg = [F53OSCImpluse impluse];
    
    return arg;
}


#pragma mark - F53OSCMessage Tests

- (void) testThat__setupWorks
{
    // given
    // - state created by `+setUp` and `-setUp`
    
    // when
    // - triggered by running this test
    
    // then
    XCTAssertTrue( self.oscClient.isConnected );
}

- (void) testThat_01_testF53OSCMessageCanSendAddressOnly
{
    // given
    NSString *address = @"/thump";
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];
    
    // when
    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:address arguments:@[]];
    [self.oscClient sendPacket:message];
    
    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[ expectation ] timeout:5.0];
    XCTAssert( result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address );
    
    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil( message );
    XCTAssertNotNil( messageReceived );
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
    XCTAssertEqualObjects( message.addressPattern, address );
    XCTAssertEqualObjects( messageReceived.addressPattern, address );
    XCTAssertEqualObjects( message.typeTagString, @"," );
    XCTAssertEqualObjects( messageReceived.typeTagString, @"," );
    XCTAssertEqual( message.arguments.count, 0 );
    XCTAssertEqual( messageReceived.arguments.count, 0 );
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
}

- (void) testThat_02_testF53OSCMessageCanSendArgumentString
{
    // given
    NSString *address = @"/thump";
    NSArray *arguments = @[ @"thump" ];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];
    
    // when
    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:address arguments:arguments];
    [self.oscClient sendPacket:message];
    
    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[ expectation ] timeout:5.0];
    XCTAssert( result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address );
    
    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil( message );
    XCTAssertNotNil( messageReceived );
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
    XCTAssertEqualObjects( message.addressPattern, address );
    XCTAssertEqualObjects( messageReceived.addressPattern, address );
    XCTAssertEqualObjects( message.typeTagString, @",s" );
    XCTAssertEqualObjects( messageReceived.typeTagString, @",s" );
    XCTAssertEqual( message.arguments.count, arguments.count );
    XCTAssertEqual( messageReceived.arguments.count, arguments.count );
    for ( NSUInteger i = 0; i < arguments.count; i++ )
    {
        id arg = arguments[i];
        XCTAssertEqualObjects( messageReceived.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg );
    }
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
}

- (void) testThat_03_testF53OSCMessageCanSendArgumentBlob
{
    // given
    NSString *address = @"/thump";
    NSArray *arguments = @[ [@"thump" dataUsingEncoding:NSUTF8StringEncoding] ];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];
    
    // when
    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:address arguments:arguments];
    [self.oscClient sendPacket:message];
    
    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[ expectation ] timeout:5.0];
    XCTAssert( result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address );
    
    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil( message );
    XCTAssertNotNil( messageReceived );
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
    XCTAssertEqualObjects( message.addressPattern, address );
    XCTAssertEqualObjects( messageReceived.addressPattern, address );
    XCTAssertEqualObjects( message.typeTagString, @",b" );
    XCTAssertEqualObjects( messageReceived.typeTagString, @",b" );
    XCTAssertEqual( message.arguments.count, arguments.count );
    XCTAssertEqual( messageReceived.arguments.count, arguments.count );
    for ( NSUInteger i = 0; i < arguments.count; i++ )
    {
        id arg = arguments[i];
        XCTAssertEqualObjects( messageReceived.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg );
    }
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
}

- (void) testThat_04_testF53OSCMessageCanSendArgumentInteger
{
    // given
    NSString *address = @"/thump";
    NSArray *arguments = @[ @(INT32_MAX) ];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];
    
    // when
    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:address arguments:arguments];
    [self.oscClient sendPacket:message];
    
    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[ expectation ] timeout:5.0];
    XCTAssert( result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address );
    
    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil( message );
    XCTAssertNotNil( messageReceived );
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
    XCTAssertEqualObjects( message.addressPattern, address );
    XCTAssertEqualObjects( messageReceived.addressPattern, address );
    XCTAssertEqualObjects( message.typeTagString, @",i" );
    XCTAssertEqualObjects( messageReceived.typeTagString, @",i" );
    XCTAssertEqual( message.arguments.count, arguments.count );
    XCTAssertEqual( messageReceived.arguments.count, arguments.count );
    for ( NSUInteger i = 0; i < arguments.count; i++ )
    {
        id arg = arguments[i];
        XCTAssertEqualObjects( messageReceived.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg );
    }
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
}

- (void) testThat_05_testF53OSCMessageCanSendArgumentFloat
{
    // given
    NSString *address = @"/thump";
    NSArray *arguments = @[ @(FLT_MAX) ];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];
    
    // when
    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:address arguments:arguments];
    [self.oscClient sendPacket:message];
    
    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[ expectation ] timeout:5.0];
    XCTAssert( result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address );
    
    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil( message );
    XCTAssertNotNil( messageReceived );
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
    XCTAssertEqualObjects( message.addressPattern, address );
    XCTAssertEqualObjects( messageReceived.addressPattern, address );
    XCTAssertEqualObjects( message.typeTagString, @",f" );
    XCTAssertEqualObjects( messageReceived.typeTagString, @",f" );
    XCTAssertEqual( message.arguments.count, arguments.count );
    XCTAssertEqual( messageReceived.arguments.count, arguments.count );
    for ( NSUInteger i = 0; i < arguments.count; i++ )
    {
        id arg = arguments[i];
        XCTAssertEqualObjects( messageReceived.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg );
    }
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
}

- (void) testThat_06_testF53OSCMessageCanSendArgumentTrue
{
    // given
    NSString *address = @"/thump";
    NSArray *arguments = @[ @YES ];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];
    
    // when
    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:address arguments:arguments];
    [self.oscClient sendPacket:message];
    
    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[ expectation ] timeout:5.0];
    XCTAssert( result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address );
    
    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil( message );
    XCTAssertNotNil( messageReceived );
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
    XCTAssertEqualObjects( message.addressPattern, address );
    XCTAssertEqualObjects( messageReceived.addressPattern, address );
    XCTAssertEqualObjects( message.typeTagString, @",T" );
    XCTAssertEqualObjects( messageReceived.typeTagString, @",T" );
    XCTAssertEqual( message.arguments.count, arguments.count );
    XCTAssertEqual( messageReceived.arguments.count, arguments.count );
    for ( NSUInteger i = 0; i < arguments.count; i++ )
    {
        id arg = arguments[i];
        XCTAssertEqualObjects( messageReceived.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg );
    }
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
}

- (void) testThat_07_testF53OSCMessageCanSendArgumentFalse
{
    // given
    NSString *address = @"/thump";
    NSArray *arguments = @[ @NO ];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];
    
    // when
    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:address arguments:arguments];
    [self.oscClient sendPacket:message];
    
    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[ expectation ] timeout:5.0];
    XCTAssert( result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address );
    
    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil( message );
    XCTAssertNotNil( messageReceived );
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
    XCTAssertEqualObjects( message.addressPattern, address );
    XCTAssertEqualObjects( messageReceived.addressPattern, address );
    XCTAssertEqualObjects( message.typeTagString, @",F" );
    XCTAssertEqualObjects( messageReceived.typeTagString, @",F" );
    XCTAssertEqual( message.arguments.count, arguments.count );
    XCTAssertEqual( messageReceived.arguments.count, arguments.count );
    for ( NSUInteger i = 0; i < arguments.count; i++ )
    {
        id arg = arguments[i];
        XCTAssertEqualObjects( messageReceived.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg );
    }
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
}

- (void) testThat_08_testF53OSCMessageCanSendArgumentNull
{
    // given
    NSString *address = @"/thump";
    NSArray *arguments = @[ [NSNull null] ];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];
    
    // when
    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:address arguments:arguments];
    [self.oscClient sendPacket:message];
    
    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[ expectation ] timeout:5.0];
    XCTAssert( result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address );
    
    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil( message );
    XCTAssertNotNil( messageReceived );
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
    XCTAssertEqualObjects( message.addressPattern, address );
    XCTAssertEqualObjects( messageReceived.addressPattern, address );
    XCTAssertEqualObjects( message.typeTagString, @",N" );
    XCTAssertEqualObjects( messageReceived.typeTagString, @",N" );
    XCTAssertEqual( message.arguments.count, arguments.count );
    XCTAssertEqual( messageReceived.arguments.count, arguments.count );
    for ( NSUInteger i = 0; i < arguments.count; i++ )
    {
        id arg = arguments[i];
        XCTAssertEqualObjects( messageReceived.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg );
    }
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
}

- (void) testThat_09_testF53OSCMessageCanSendArgumentImpluse
{
    // given
    NSString *address = @"/thump";
    NSArray *arguments = @[ [F53OSCImpluse impluse] ];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];
    
    // when
    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:address arguments:arguments];
    [self.oscClient sendPacket:message];
    
    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[ expectation ] timeout:5.0];
    XCTAssert( result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address );
    
    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil( message );
    XCTAssertNotNil( messageReceived );
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
    XCTAssertEqualObjects( message.addressPattern, address );
    XCTAssertEqualObjects( messageReceived.addressPattern, address );
    XCTAssertEqualObjects( message.typeTagString, @",I" );
    XCTAssertEqualObjects( messageReceived.typeTagString, @",I" );
    XCTAssertEqual( message.arguments.count, arguments.count );
    XCTAssertEqual( messageReceived.arguments.count, arguments.count );
    for ( NSUInteger i = 0; i < arguments.count; i++ )
    {
        id arg = arguments[i];
        XCTAssertEqualObjects( messageReceived.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg );
    }
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
}

- (void) testThat_10_testF53OSCMessageCanSendQSCAddressOnly
{
    // given
    NSString *address = @"/thump";
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];
    
    // when
    F53OSCMessage *message = [F53OSCMessage messageWithString:address];
    [self.oscClient sendPacket:message];
    
    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[ expectation ] timeout:5.0];
    XCTAssert( result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address );
    
    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil( message );
    XCTAssertNotNil( messageReceived );
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
    XCTAssertEqualObjects( message.addressPattern, address );
    XCTAssertEqualObjects( messageReceived.addressPattern, address );
    XCTAssertEqualObjects( message.typeTagString, @"," );
    XCTAssertEqualObjects( messageReceived.typeTagString, @"," );
    XCTAssertEqual( messageReceived.arguments.count, 0 );
    XCTAssertEqual( messageReceived.arguments.count, 0 );
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
}

- (void) testThat_11_testF53OSCMessageCanSendQSCArgumentString
{
    // given
    NSString *address = @"/thump";
    NSArray<NSString *> *arguments = @[ @"\"thump\"" ];
    NSString *qsc = [NSString stringWithFormat:@"%@ %@", address, [arguments componentsJoinedByString:@" "]];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];
    
    // when
    F53OSCMessage *message = [F53OSCMessage messageWithString:qsc];
    [self.oscClient sendPacket:message];
    
    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[ expectation ] timeout:5.0];
    XCTAssert( result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address );
    
    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil( message );
    XCTAssertNotNil( messageReceived );
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
    XCTAssertEqualObjects( message.addressPattern, address );
    XCTAssertEqualObjects( messageReceived.addressPattern, address );
    XCTAssertEqualObjects( message.typeTagString, @",s" );
    XCTAssertEqualObjects( messageReceived.typeTagString, @",s" );
    
    NSUInteger argIndex = 0;
    for ( NSUInteger t = 0; t < messageReceived.typeTagString.length; t++ )
    {
        NSString *typeTag = [messageReceived.typeTagString substringWithRange:NSMakeRange( t, 1 )];
        if ( [typeTag isEqualToString:@","] )
            continue;
        
        NSString *argStr = arguments[argIndex];
        id arg = [self oscMessageArgumentFromString:argStr typeTag:typeTag];
        XCTAssertEqualObjects( messageReceived.arguments[argIndex], arg, @"arg index %ld not equal - %@", (unsigned long)argIndex, arg );
        
        argIndex++;
    }
    
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
}

- (void) testThat_12_testF53OSCMessageCanSendQSCArgumentBlob
{
    // given
    NSString *address = @"/thump";
    NSArray<NSString *> *arguments = @[ [NSString stringWithFormat:@"#blob%@", [[@"thump" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0] ] ];
    NSString *qsc = [NSString stringWithFormat:@"%@ %@", address, [arguments componentsJoinedByString:@" "]];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];
    
    // when
    F53OSCMessage *message = [F53OSCMessage messageWithString:qsc];
    [self.oscClient sendPacket:message];
    
    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[ expectation ] timeout:5.0];
    XCTAssert( result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address );
    
    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil( message );
    XCTAssertNotNil( messageReceived );
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
    XCTAssertEqualObjects( message.addressPattern, address );
    XCTAssertEqualObjects( messageReceived.addressPattern, address );
    XCTAssertEqualObjects( message.typeTagString, @",b" );
    XCTAssertEqualObjects( messageReceived.typeTagString, @",b" );
    
    NSUInteger argIndex = 0;
    for ( NSUInteger t = 0; t < messageReceived.typeTagString.length; t++ )
    {
        NSString *typeTag = [messageReceived.typeTagString substringWithRange:NSMakeRange( t, 1 )];
        if ( [typeTag isEqualToString:@","] )
            continue;
        
        NSString *argStr = arguments[argIndex];
        id arg = [self oscMessageArgumentFromString:argStr typeTag:typeTag];
        XCTAssertEqualObjects( messageReceived.arguments[argIndex], arg, @"arg index %ld not equal - %@", (unsigned long)argIndex, arg );
        
        argIndex++;
    }
    
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
}

- (void) testThat_13_testF53OSCMessageCanSendQSCArgumentInteger
{
    // given
    NSString *address = @"/thump";
    NSArray<NSString *> *arguments = @[ [NSString stringWithFormat:@"%d", INT32_MAX ] ];
    NSString *qsc = [NSString stringWithFormat:@"%@ %@", address, [arguments componentsJoinedByString:@" "]];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];
    
    // when
    F53OSCMessage *message = [F53OSCMessage messageWithString:qsc];
    [self.oscClient sendPacket:message];
    
    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[ expectation ] timeout:5.0];
    XCTAssert( result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address );
    
    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil( message );
    XCTAssertNotNil( messageReceived );
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
    XCTAssertEqualObjects( message.addressPattern, address );
    XCTAssertEqualObjects( messageReceived.addressPattern, address );
    XCTAssertEqualObjects( message.typeTagString, @",i" );
    XCTAssertEqualObjects( messageReceived.typeTagString, @",i" );
    
    NSUInteger argIndex = 0;
    for ( NSUInteger t = 0; t < messageReceived.typeTagString.length; t++ )
    {
        NSString *typeTag = [messageReceived.typeTagString substringWithRange:NSMakeRange( t, 1 )];
        if ( [typeTag isEqualToString:@","] )
            continue;
        
        NSString *argStr = arguments[argIndex];
        id arg = [self oscMessageArgumentFromString:argStr typeTag:typeTag];
        XCTAssertEqualObjects( messageReceived.arguments[argIndex], arg, @"arg index %ld not equal - %@", (unsigned long)argIndex, arg );
        
        argIndex++;
    }
    
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
}

- (void) testThat_14_testF53OSCMessageCanSendQSCArgumentFloat
{
    // given
    NSString *address = @"/thump";
    NSArray<NSString *> *arguments = @[ [NSString stringWithFormat:@"%F", FLT_MAX ] ];
    NSString *qsc = [NSString stringWithFormat:@"%@ %@", address, [arguments componentsJoinedByString:@" "]];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];
    
    // when
    F53OSCMessage *message = [F53OSCMessage messageWithString:qsc];
    [self.oscClient sendPacket:message];
    
    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[ expectation ] timeout:5.0];
    XCTAssert( result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address );
    
    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil( message );
    XCTAssertNotNil( messageReceived );
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
    XCTAssertEqualObjects( message.addressPattern, address );
    XCTAssertEqualObjects( messageReceived.addressPattern, address );
    XCTAssertEqualObjects( message.typeTagString, @",f" );
    XCTAssertEqualObjects( messageReceived.typeTagString, @",f" );
    
    NSUInteger argIndex = 0;
    for ( NSUInteger t = 0; t < messageReceived.typeTagString.length; t++ )
    {
        NSString *typeTag = [messageReceived.typeTagString substringWithRange:NSMakeRange( t, 1 )];
        if ( [typeTag isEqualToString:@","] )
            continue;
        
        NSString *argStr = arguments[argIndex];
        id arg = [self oscMessageArgumentFromString:argStr typeTag:typeTag];
        XCTAssertEqualObjects( messageReceived.arguments[argIndex], arg, @"arg index %ld not equal - %@", (unsigned long)argIndex, arg );
        
        argIndex++;
    }
    
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
}

- (void) testThat_14_testF53OSCMessageCanSendQSCArgumentTrue
{
    // given
    NSString *address = @"/thump";
    NSArray<NSString *> *arguments = @[ @"\\T" ];
    NSString *qsc = [NSString stringWithFormat:@"%@ %@", address, [arguments componentsJoinedByString:@" "]];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];
    
    // when
    F53OSCMessage *message = [F53OSCMessage messageWithString:qsc];
    [self.oscClient sendPacket:message];
    
    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[ expectation ] timeout:5.0];
    XCTAssert( result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address );
    
    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil( message );
    XCTAssertNotNil( messageReceived );
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
    XCTAssertEqualObjects( message.addressPattern, address );
    XCTAssertEqualObjects( messageReceived.addressPattern, address );
    XCTAssertEqualObjects( message.typeTagString, @",T" );
    XCTAssertEqualObjects( messageReceived.typeTagString, @",T" );
    
    NSUInteger argIndex = 0;
    for ( NSUInteger t = 0; t < messageReceived.typeTagString.length; t++ )
    {
        NSString *typeTag = [messageReceived.typeTagString substringWithRange:NSMakeRange( t, 1 )];
        if ( [typeTag isEqualToString:@","] )
            continue;
        
        NSString *argStr = arguments[argIndex];
        id arg = [self oscMessageArgumentFromString:argStr typeTag:typeTag];
        XCTAssertEqualObjects( messageReceived.arguments[argIndex], arg, @"arg index %ld not equal - %@", (unsigned long)argIndex, arg );
        
        argIndex++;
    }
    
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
}

- (void) testThat_14_testF53OSCMessageCanSendQSCArgumentFalse
{
    // given
    NSString *address = @"/thump";
    NSArray<NSString *> *arguments = @[ @"\\F" ];
    NSString *qsc = [NSString stringWithFormat:@"%@ %@", address, [arguments componentsJoinedByString:@" "]];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];
    
    // when
    F53OSCMessage *message = [F53OSCMessage messageWithString:qsc];
    [self.oscClient sendPacket:message];
    
    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[ expectation ] timeout:5.0];
    XCTAssert( result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address );
    
    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil( message );
    XCTAssertNotNil( messageReceived );
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
    XCTAssertEqualObjects( message.addressPattern, address );
    XCTAssertEqualObjects( messageReceived.addressPattern, address );
    XCTAssertEqualObjects( message.typeTagString, @",F" );
    XCTAssertEqualObjects( messageReceived.typeTagString, @",F" );
    
    NSUInteger argIndex = 0;
    for ( NSUInteger t = 0; t < messageReceived.typeTagString.length; t++ )
    {
        NSString *typeTag = [messageReceived.typeTagString substringWithRange:NSMakeRange( t, 1 )];
        if ( [typeTag isEqualToString:@","] )
            continue;
        
        NSString *argStr = arguments[argIndex];
        id arg = [self oscMessageArgumentFromString:argStr typeTag:typeTag];
        XCTAssertEqualObjects( messageReceived.arguments[argIndex], arg, @"arg index %ld not equal - %@", (unsigned long)argIndex, arg );
        
        argIndex++;
    }
    
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
}

- (void) testThat_14_testF53OSCMessageCanSendQSCArgumentNull
{
    // given
    NSString *address = @"/thump";
    NSArray<NSString *> *arguments = @[ @"\\N" ];
    NSString *qsc = [NSString stringWithFormat:@"%@ %@", address, [arguments componentsJoinedByString:@" "]];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];
    
    // when
    F53OSCMessage *message = [F53OSCMessage messageWithString:qsc];
    [self.oscClient sendPacket:message];
    
    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[ expectation ] timeout:5.0];
    XCTAssert( result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address );
    
    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil( message );
    XCTAssertNotNil( messageReceived );
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
    XCTAssertEqualObjects( message.addressPattern, address );
    XCTAssertEqualObjects( messageReceived.addressPattern, address );
    XCTAssertEqualObjects( message.typeTagString, @",N" );
    XCTAssertEqualObjects( messageReceived.typeTagString, @",N" );
    
    NSUInteger argIndex = 0;
    for ( NSUInteger t = 0; t < messageReceived.typeTagString.length; t++ )
    {
        NSString *typeTag = [messageReceived.typeTagString substringWithRange:NSMakeRange( t, 1 )];
        if ( [typeTag isEqualToString:@","] )
            continue;
        
        NSString *argStr = arguments[argIndex];
        id arg = [self oscMessageArgumentFromString:argStr typeTag:typeTag];
        XCTAssertEqualObjects( messageReceived.arguments[argIndex], arg, @"arg index %ld not equal - %@", (unsigned long)argIndex, arg );
        
        argIndex++;
    }
    
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
}

- (void) testThat_14_testF53OSCMessageCanSendQSCArgumentImpluse
{
    // given
    NSString *address = @"/thump";
    NSArray<NSString *> *arguments = @[ @"\\I" ];
    NSString *qsc = [NSString stringWithFormat:@"%@ %@", address, [arguments componentsJoinedByString:@" "]];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];
    
    // when
    F53OSCMessage *message = [F53OSCMessage messageWithString:qsc];
    [self.oscClient sendPacket:message];
    
    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[ expectation ] timeout:5.0];
    XCTAssert( result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address );
    
    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil( message );
    XCTAssertNotNil( messageReceived );
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
    XCTAssertEqualObjects( message.addressPattern, address );
    XCTAssertEqualObjects( messageReceived.addressPattern, address );
    XCTAssertEqualObjects( message.typeTagString, @",I" );
    XCTAssertEqualObjects( messageReceived.typeTagString, @",I" );
    
    NSUInteger argIndex = 0;
    for ( NSUInteger t = 0; t < messageReceived.typeTagString.length; t++ )
    {
        NSString *typeTag = [messageReceived.typeTagString substringWithRange:NSMakeRange( t, 1 )];
        if ( [typeTag isEqualToString:@","] )
            continue;
        
        NSString *argStr = arguments[argIndex];
        id arg = [self oscMessageArgumentFromString:argStr typeTag:typeTag];
        XCTAssertEqualObjects( messageReceived.arguments[argIndex], arg, @"arg index %ld not equal - %@", (unsigned long)argIndex, arg );
        
        argIndex++;
    }
    
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
}

- (void) testThat_14_testF53OSCMessageCanSendMultipleArguments
{
    // given
    NSString *address = @"/thump";
    NSArray *arguments = @[@"thump",
                           [@"thump" dataUsingEncoding:NSUTF8StringEncoding],
                           @(INT32_MAX),
                           @(FLT_MAX),
                           @YES,
                           @NO,
                           [NSNull null],
                           [F53OSCImpluse impluse],
                           ];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];
    
    // when
    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:address arguments:arguments];
    [self.oscClient sendPacket:message];
    
    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[ expectation ] timeout:5.0];
    XCTAssert( result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address );
    
    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil( message );
    XCTAssertNotNil( messageReceived );
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
    XCTAssertEqualObjects( message.addressPattern, address );
    XCTAssertEqualObjects( messageReceived.addressPattern, address );
    XCTAssertEqualObjects( message.typeTagString, @",sbifTFNI" );
    XCTAssertEqualObjects( messageReceived.typeTagString, @",sbifTFNI" );
    XCTAssertEqual( message.arguments.count, arguments.count );
    XCTAssertEqual( messageReceived.arguments.count, arguments.count );
    for ( NSUInteger i = 0; i < arguments.count; i++ )
    {
        id arg = arguments[i];
        XCTAssertEqualObjects( messageReceived.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg );
    }
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
}

- (void) testThat_15_testF53OSCMessageCanSendMultipleQSCArguments
{
    // given
    NSString *address = @"/thump";
    NSArray<NSString *> *arguments = @[ @"thump",
                                        [NSString stringWithFormat:@"#blob%@", [[@"thump" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0] ],
                                        [NSString stringWithFormat:@"%d", INT32_MAX ],
                                        [NSString stringWithFormat:@"%F", FLT_MAX ],
                                        @"\\T",
                                        @"\\F",
                                        @"\\N",
                                        @"\\I",
                                        ];
    NSString *qsc = [NSString stringWithFormat:@"%@ %@", address, [arguments componentsJoinedByString:@" "]];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];
    
    // when
    F53OSCMessage *message = [F53OSCMessage messageWithString:qsc];
    [self.oscClient sendPacket:message];
    
    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[ expectation ] timeout:5.0];
    XCTAssert( result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address );
    
    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil( message );
    XCTAssertNotNil( messageReceived );
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
    XCTAssertEqualObjects( message.addressPattern, address );
    XCTAssertEqualObjects( messageReceived.addressPattern, address );
    XCTAssertEqualObjects( message.typeTagString, @",sbifTFNI" );
    XCTAssertEqualObjects( messageReceived.typeTagString, @",sbifTFNI" );
    
    NSUInteger argIndex = 0;
    for ( NSUInteger t = 0; t < messageReceived.typeTagString.length; t++ )
    {
        NSString *typeTag = [messageReceived.typeTagString substringWithRange:NSMakeRange( t, 1 )];
        if ( [typeTag isEqualToString:@","] )
            continue;
        
        NSString *argStr = arguments[argIndex];
        id arg = [self oscMessageArgumentFromString:argStr typeTag:typeTag];
        XCTAssertEqualObjects( messageReceived.arguments[argIndex], arg, @"arg index %ld not equal - %@", (unsigned long)argIndex, arg );
        
        argIndex++;
    }
    
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
}

- (void) testThat_13_testF53OSCMessageCanSendMultipleStringArguments
{
    // given
    NSString *address = @"/thump";
    NSArray *arguments = @[ @"thumpthumpthumpy",
                            @"thumpthumpthump",
                            @"thumpthumpthum",
                            @"thumpthumpthu",
                            @"thumpthumpth",
                            @"thumpthumpt",
                            @"thumpthump",
                            @"thumpthum",
                            @"thumpthu",
                            @"thumpth",
                            @"thumpt",
                            @"thump",
                            @"thum",
                            @"thu",
                            @"th",
                            @"t",
                            ];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];
    
    // when
    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:address arguments:arguments];
    [self.oscClient sendPacket:message];
    
    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[ expectation ] timeout:5.0];
    XCTAssert( result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address );
    
    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil( message );
    XCTAssertNotNil( messageReceived );
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
    XCTAssertEqualObjects( message.addressPattern, address );
    XCTAssertEqualObjects( messageReceived.addressPattern, address );
    XCTAssertEqualObjects( message.typeTagString, @",ssssssssssssssss" );
    XCTAssertEqualObjects( messageReceived.typeTagString, @",ssssssssssssssss" );
    XCTAssertEqual( message.arguments.count, arguments.count );
    XCTAssertEqual( messageReceived.arguments.count, arguments.count );
    for ( NSUInteger i = 0; i < arguments.count; i++ )
    {
        id arg = arguments[i];
        XCTAssertEqualObjects( messageReceived.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg );
    }
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
}

- (void) testThat_14_testF53OSCMessageCanSendMultipleQSCStringArguments
{
    // given
    NSString *address = @"/thump";
    NSArray *arguments = @[ @"thumpthumpthumpy",
                            @"thumpthumpthump",
                            @"thumpthumpthum",
                            @"thumpthumpthu",
                            @"thumpthumpth",
                            @"thumpthumpt",
                            @"thumpthump",
                            @"thumpthum",
                            @"thumpthu",
                            @"thumpth",
                            @"thumpt",
                            @"thump",
                            @"thum",
                            @"thu",
                            @"th",
                            @"t",
                            ];
    NSString *qsc = [NSString stringWithFormat:@"%@ %@", address, [arguments componentsJoinedByString:@" "]];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];
    
    // when
    F53OSCMessage *message = [F53OSCMessage messageWithString:qsc];
    [self.oscClient sendPacket:message];
    
    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[ expectation ] timeout:5.0];
    XCTAssert( result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address );
    
    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil( message );
    XCTAssertNotNil( messageReceived );
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
    XCTAssertEqualObjects( message.addressPattern, address );
    XCTAssertEqualObjects( messageReceived.addressPattern, address );
    XCTAssertEqualObjects( message.typeTagString, @",ssssssssssssssss" );
    XCTAssertEqualObjects( messageReceived.typeTagString, @",ssssssssssssssss" );
    
    NSUInteger argIndex = 0;
    for ( NSUInteger t = 0; t < messageReceived.typeTagString.length; t++ )
    {
        NSString *typeTag = [messageReceived.typeTagString substringWithRange:NSMakeRange( t, 1 )];
        if ( [typeTag isEqualToString:@","] )
            continue;
        
        NSString *argStr = arguments[argIndex];
        id arg = [self oscMessageArgumentFromString:argStr typeTag:typeTag];
        XCTAssertEqualObjects( messageReceived.arguments[argIndex], arg, @"arg index %ld not equal - %@", (unsigned long)argIndex, arg );
        
        argIndex++;
    }
    
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
}

- (void) testThat_15_testF53OSCMessageCanSendMultipleBlobArguments
{
    // given
    NSString *address = @"/thump";
    NSArray *arguments = @[ [@"thumpthumpthumpy" dataUsingEncoding:NSUTF8StringEncoding],
                            [@"thumpthumpthump" dataUsingEncoding:NSUTF8StringEncoding],
                            [@"thumpthumpthum" dataUsingEncoding:NSUTF8StringEncoding],
                            [@"thumpthumpthu" dataUsingEncoding:NSUTF8StringEncoding],
                            [@"thumpthumpth" dataUsingEncoding:NSUTF8StringEncoding],
                            [@"thumpthumpt" dataUsingEncoding:NSUTF8StringEncoding],
                            [@"thumpthump" dataUsingEncoding:NSUTF8StringEncoding],
                            [@"thumpthum" dataUsingEncoding:NSUTF8StringEncoding],
                            [@"thumpthu" dataUsingEncoding:NSUTF8StringEncoding],
                            [@"thumpth" dataUsingEncoding:NSUTF8StringEncoding],
                            [@"thumpt" dataUsingEncoding:NSUTF8StringEncoding],
                            [@"thump" dataUsingEncoding:NSUTF8StringEncoding],
                            [@"thum" dataUsingEncoding:NSUTF8StringEncoding],
                            [@"thu" dataUsingEncoding:NSUTF8StringEncoding],
                            [@"th" dataUsingEncoding:NSUTF8StringEncoding],
                            [@"t" dataUsingEncoding:NSUTF8StringEncoding],
                            ];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];
    
    // when
    F53OSCMessage *message = [F53OSCMessage messageWithAddressPattern:address arguments:arguments];
    [self.oscClient sendPacket:message];
    
    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[ expectation ] timeout:5.0];
    XCTAssert( result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address );
    
    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil( message );
    XCTAssertNotNil( messageReceived );
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
    XCTAssertEqualObjects( message.addressPattern, address );
    XCTAssertEqualObjects( messageReceived.addressPattern, address );
    XCTAssertEqualObjects( message.typeTagString, @",bbbbbbbbbbbbbbbb" );
    XCTAssertEqualObjects( messageReceived.typeTagString, @",bbbbbbbbbbbbbbbb" );
    XCTAssertEqual( message.arguments.count, arguments.count );
    XCTAssertEqual( messageReceived.arguments.count, arguments.count );
    for ( NSUInteger i = 0; i < arguments.count; i++ )
    {
        id arg = arguments[i];
        XCTAssertEqualObjects( messageReceived.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg );
    }
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
}

- (void) testThat_16_testF53OSCMessageCanSendMultipleQSCBlobArguments
{
    // given
    NSString *address = @"/thump";
    NSArray<NSString *> *arguments =
    @[ [NSString stringWithFormat:@"#blob%@", [[@"thumpthumpthumpy" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0] ],
       [NSString stringWithFormat:@"#blob%@", [[@"thumpthumpthump" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0] ],
       [NSString stringWithFormat:@"#blob%@", [[@"thumpthumpthum" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0] ],
       [NSString stringWithFormat:@"#blob%@", [[@"thumpthumpthu" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0] ],
       [NSString stringWithFormat:@"#blob%@", [[@"thumpthumpth" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0] ],
       [NSString stringWithFormat:@"#blob%@", [[@"thumpthumpt" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0] ],
       [NSString stringWithFormat:@"#blob%@", [[@"thumpthump" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0] ],
       [NSString stringWithFormat:@"#blob%@", [[@"thumpthum" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0] ],
       [NSString stringWithFormat:@"#blob%@", [[@"thumpthu" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0] ],
       [NSString stringWithFormat:@"#blob%@", [[@"thumpth" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0] ],
       [NSString stringWithFormat:@"#blob%@", [[@"thumpt" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0] ],
       [NSString stringWithFormat:@"#blob%@", [[@"thump" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0] ],
       [NSString stringWithFormat:@"#blob%@", [[@"thum" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0] ],
       [NSString stringWithFormat:@"#blob%@", [[@"thu" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0] ],
       [NSString stringWithFormat:@"#blob%@", [[@"th" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0] ],
       [NSString stringWithFormat:@"#blob%@", [[@"t" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0] ],
       ];
    NSString *qsc = [NSString stringWithFormat:@"%@ %@", address, [arguments componentsJoinedByString:@" "]];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];
    
    // when
    F53OSCMessage *message = [F53OSCMessage messageWithString:qsc];
    [self.oscClient sendPacket:message];
    
    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[ expectation ] timeout:5.0];
    XCTAssert( result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", address );
    
    F53OSCMessage *messageReceived = self.matchedExpectations[expectation.description];
    XCTAssertNotNil( message );
    XCTAssertNotNil( messageReceived );
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
    XCTAssertEqualObjects( message.addressPattern, address );
    XCTAssertEqualObjects( messageReceived.addressPattern, address );
    XCTAssertEqualObjects( message.typeTagString, @",bbbbbbbbbbbbbbbb" );
    XCTAssertEqualObjects( messageReceived.typeTagString, @",bbbbbbbbbbbbbbbb" );
    XCTAssertEqual( message.arguments.count, arguments.count );
    XCTAssertEqual( messageReceived.arguments.count, arguments.count );
    for ( NSUInteger i = 0; i < arguments.count; i++ )
    {
        NSUInteger argIndex = 0;
        for ( NSUInteger t = 0; t < messageReceived.typeTagString.length; t++ )
        {
            NSString *typeTag = [messageReceived.typeTagString substringWithRange:NSMakeRange( t, 1 )];
            if ( [typeTag isEqualToString:@","] )
                continue;
            
            NSString *argStr = arguments[argIndex];
            id arg = [self oscMessageArgumentFromString:argStr typeTag:typeTag];
            XCTAssertEqualObjects( messageReceived.arguments[argIndex], arg, @"arg index %ld not equal - %@", (unsigned long)argIndex, arg );
            
            argIndex++;
        }
    }
    XCTAssertNil( message.userData );
    XCTAssertNil( messageReceived.userData );
}

#pragma mark - F53OSCPacketDestination

- (void) takeMessage:(nullable F53OSCMessage *)message
{
    // NOTE: F53OSCMessages received without matching XCTestExpectations are discarded
    
    NSString *description = message.addressPattern;
    
    XCTestExpectation *foundExpectation = nil;
    for ( XCTestExpectation *aMessageExpectation in self.messageExpectations )
    {
        if ( [aMessageExpectation.expectationDescription isEqualToString:description] == NO )
            continue;
        
        foundExpectation = aMessageExpectation;
        break;
    }
    
    if ( foundExpectation )
    {
        self.matchedExpectations[foundExpectation.expectationDescription] = message;
        [self.messageExpectations removeObject:foundExpectation];
        [foundExpectation fulfill];
    }
}

#pragma mark - F53OSCClientDelegate

- (void) clientDidConnect:(F53OSCClient *)client
{
    if ( client.isConnected )
        [self.clientConnectExpectation fulfill];
}

#pragma mark - helpers

- (void) connectOSCClientAndVerify
{
    // connect the TCP socket
    [self.oscClient connect];
    XCTWaiterResult clientConnectResult = [XCTWaiter waitForExpectations:@[ self.clientConnectExpectation ] timeout:5.0];
    XCTAssert( clientConnectResult == XCTWaiterResultCompleted, @"F53OSCClient for test failed to connect" );
}

@end

#endif // ifndef MAC_OS_X_VERSION_10_12

NS_ASSUME_NONNULL_END
