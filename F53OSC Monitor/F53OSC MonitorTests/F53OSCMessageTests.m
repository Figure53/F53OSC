//
//  F53OSCMessageTests.m
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

@interface F53OSCMessageTests : XCTestCase <F53OSCPacketDestination, F53OSCClientDelegate>

@property (nonatomic, strong)           XCTestExpectation *clientConnectExpectation;
@property (nonatomic, strong)           NSMutableArray<XCTestExpectation *> *messageExpectations;
@property (nonatomic, strong)           NSMutableDictionary<NSString *, F53OSCMessage *> *matchedExpectations;
@property (nonatomic, strong)           F53OSCServer *oscServer;
@property (nonatomic, strong)           F53OSCClient *oscClient;

- (nullable id) oscMessageArgumentFromString:(NSString *)qsc typeTag:(NSString *)typeTag;

@end


@implementation F53OSCMessageTests

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
        arg = [NSValue oscTrue];
    
    else if ( [typeTag isEqualToString:@"F"] ) // 'F'
        arg = [NSValue oscFalse];
    
    else if ( [typeTag isEqualToString:@"N"] ) // 'N'
        arg = [NSValue oscNull];
    
    else if ( [typeTag isEqualToString:@"I"] ) // 'I'
        arg = [NSValue oscImpulse];
    
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

- (void) testThat_01_F53OSCMessageCanSendAddressOnly
{
    // given
    NSString *address = @"/thump";
    NSString *typeTagString = @",";
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
    XCTAssertEqualObjects( message.typeTagString, typeTagString );
    XCTAssertEqualObjects( messageReceived.typeTagString, typeTagString );
    XCTAssertEqual( message.arguments.count, 0 );
    XCTAssertEqual( messageReceived.arguments.count, 0 );
}

- (void) testThat_02_F53OSCMessageCanSendArgumentString
{
    // given
    NSString *address = @"/thump";
    NSArray *arguments = @[ @"thump" ];
    NSString *typeTagString = @",s";
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
    XCTAssertEqualObjects( message.typeTagString, typeTagString );
    XCTAssertEqualObjects( messageReceived.typeTagString, typeTagString );
    XCTAssertEqual( message.arguments.count, arguments.count );
    XCTAssertEqual( messageReceived.arguments.count, arguments.count );
    for ( NSUInteger i = 0; i < arguments.count; i++ )
    {
        id arg = arguments[i];
        XCTAssertEqualObjects( messageReceived.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg );
    }
}

- (void) testThat_03_F53OSCMessageCanSendArgumentBlob
{
    // given
    NSString *address = @"/thump";
    NSArray *arguments = @[ [@"thump" dataUsingEncoding:NSUTF8StringEncoding] ];
    NSString *typeTagString = @",b";
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
    XCTAssertEqualObjects( message.typeTagString, typeTagString );
    XCTAssertEqualObjects( messageReceived.typeTagString, typeTagString );
    XCTAssertEqual( message.arguments.count, arguments.count );
    XCTAssertEqual( messageReceived.arguments.count, arguments.count );
    for ( NSUInteger i = 0; i < arguments.count; i++ )
    {
        id arg = arguments[i];
        XCTAssertEqualObjects( messageReceived.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg );
    }
}

- (void) testThat_04_F53OSCMessageCanSendArgumentInteger
{
    // given
    NSString *address = @"/thump";
    NSArray *arguments = @[ @(INT32_MAX) ];
    NSString *typeTagString = @",i";
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
    XCTAssertEqualObjects( message.typeTagString, typeTagString );
    XCTAssertEqualObjects( messageReceived.typeTagString, typeTagString );
    XCTAssertEqual( message.arguments.count, arguments.count );
    XCTAssertEqual( messageReceived.arguments.count, arguments.count );
    for ( NSUInteger i = 0; i < arguments.count; i++ )
    {
        id arg = arguments[i];
        XCTAssertEqualObjects( messageReceived.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg );
    }
}

- (void) testThat_05_F53OSCMessageCanSendArgumentFloat
{
    // given
    NSString *address = @"/thump";
    NSArray *arguments = @[ @(FLT_MAX) ];
    NSString *typeTagString = @",f";
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
    XCTAssertEqualObjects( message.typeTagString, typeTagString );
    XCTAssertEqualObjects( messageReceived.typeTagString, typeTagString );
    XCTAssertEqual( message.arguments.count, arguments.count );
    XCTAssertEqual( messageReceived.arguments.count, arguments.count );
    for ( NSUInteger i = 0; i < arguments.count; i++ )
    {
        id arg = arguments[i];
        XCTAssertEqualObjects( messageReceived.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg );
    }
}

- (void) testThat_06_F53OSCMessageCanSendArgumentTrue
{
    // given
    NSString *address = @"/thump";
    NSArray *arguments = @[ [NSValue oscTrue] ];
    NSString *typeTagString = @",T";
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
    XCTAssertEqualObjects( message.typeTagString, typeTagString );
    XCTAssertEqualObjects( messageReceived.typeTagString, typeTagString );
    XCTAssertEqual( message.arguments.count, arguments.count );
    XCTAssertEqual( messageReceived.arguments.count, arguments.count );
    for ( NSUInteger i = 0; i < arguments.count; i++ )
    {
        id arg = arguments[i];
        XCTAssertEqualObjects( messageReceived.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg );
    }
}

- (void) testThat_07_F53OSCMessageCanSendArgumentFalse
{
    // given
    NSString *address = @"/thump";
    NSArray *arguments = @[ [NSValue oscFalse] ];
    NSString *typeTagString = @",F";
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
    XCTAssertEqualObjects( message.typeTagString, typeTagString );
    XCTAssertEqualObjects( messageReceived.typeTagString, typeTagString );
    XCTAssertEqual( message.arguments.count, arguments.count );
    XCTAssertEqual( messageReceived.arguments.count, arguments.count );
    for ( NSUInteger i = 0; i < arguments.count; i++ )
    {
        id arg = arguments[i];
        XCTAssertEqualObjects( messageReceived.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg );
    }
}

- (void) testThat_08_F53OSCMessageCanSendArgumentNull
{
    // given
    NSString *address = @"/thump";
    NSArray *arguments = @[ [NSValue oscNull] ];
    NSString *typeTagString = @",N";
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
    XCTAssertEqualObjects( message.typeTagString, typeTagString );
    XCTAssertEqualObjects( messageReceived.typeTagString, typeTagString );
    XCTAssertEqual( message.arguments.count, arguments.count );
    XCTAssertEqual( messageReceived.arguments.count, arguments.count );
    for ( NSUInteger i = 0; i < arguments.count; i++ )
    {
        id arg = arguments[i];
        XCTAssertEqualObjects( messageReceived.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg );
    }
}

- (void) testThat_09_F53OSCMessageCanSendArgumentImpluse
{
    // given
    NSString *address = @"/thump";
    NSArray *arguments = @[ [NSValue oscImpulse] ];
    NSString *typeTagString = @",I";
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
    XCTAssertEqualObjects( message.typeTagString, typeTagString );
    XCTAssertEqualObjects( messageReceived.typeTagString, typeTagString );
    XCTAssertEqual( message.arguments.count, arguments.count );
    XCTAssertEqual( messageReceived.arguments.count, arguments.count );
    for ( NSUInteger i = 0; i < arguments.count; i++ )
    {
        id arg = arguments[i];
        XCTAssertEqualObjects( messageReceived.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg );
    }
}

- (void) testThat_10_F53OSCMessageCanSendQSCAddressOnly
{
    // given
    NSString *address = @"/thump";
    NSString *typeTagString = @",";
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
    XCTAssertEqualObjects( message.typeTagString, typeTagString );
    XCTAssertEqualObjects( messageReceived.typeTagString, typeTagString );
    XCTAssertEqual( message.arguments.count, 0 );
    XCTAssertEqual( messageReceived.arguments.count, 0 );
}

- (void) testThat_11_F53OSCMessageCanSendQSCArgumentString
{
    // given
    NSString *address = @"/thump";
    NSArray<NSString *> *arguments = @[ @"\"thump\"" ];
    NSString *typeTagString = @",s";
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];
    
    // when
    NSString *qsc = [NSString stringWithFormat:@"%@ %@", address, [arguments componentsJoinedByString:@" "]];
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
    XCTAssertEqualObjects( message.typeTagString, typeTagString );
    XCTAssertEqualObjects( messageReceived.typeTagString, typeTagString );
    
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

- (void) testThat_12_F53OSCMessageCanSendQSCArgumentBlob
{
    // given
    NSString *address = @"/thump";
    NSArray<NSString *> *arguments = @[ [NSString stringWithFormat:@"#blob%@", [[@"thump" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0] ] ];
    NSString *typeTagString = @",b";
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];
    
    // when
    NSString *qsc = [NSString stringWithFormat:@"%@ %@", address, [arguments componentsJoinedByString:@" "]];
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
    XCTAssertEqualObjects( message.typeTagString, typeTagString );
    XCTAssertEqualObjects( messageReceived.typeTagString, typeTagString );
    
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

- (void) testThat_13_F53OSCMessageCanSendQSCArgumentInteger
{
    // given
    NSString *address = @"/thump";
    NSArray<NSString *> *arguments = @[ [NSString stringWithFormat:@"%d", INT32_MAX ] ];
    NSString *typeTagString = @",i";
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];
    
    // when
    NSString *qsc = [NSString stringWithFormat:@"%@ %@", address, [arguments componentsJoinedByString:@" "]];
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
    XCTAssertEqualObjects( message.typeTagString, typeTagString );
    XCTAssertEqualObjects( messageReceived.typeTagString, typeTagString );
    
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

- (void) testThat_14_F53OSCMessageCanSendQSCArgumentFloat
{
    // given
    NSString *address = @"/thump";
    NSArray<NSString *> *arguments = @[ [NSString stringWithFormat:@"%F", FLT_MAX ] ];
    NSString *typeTagString = @",f";
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];
    
    // when
    NSString *qsc = [NSString stringWithFormat:@"%@ %@", address, [arguments componentsJoinedByString:@" "]];
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
    XCTAssertEqualObjects( message.typeTagString, typeTagString );
    XCTAssertEqualObjects( messageReceived.typeTagString, typeTagString );
    
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

- (void) testThat_15_F53OSCMessageCanSendQSCArgumentTrue
{
    // given
    NSString *address = @"/thump";
    NSArray<NSString *> *arguments = @[ @"\\T" ];
    NSString *typeTagString = @",T";
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];
    
    // when
    NSString *qsc = [NSString stringWithFormat:@"%@ %@", address, [arguments componentsJoinedByString:@" "]];
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
    XCTAssertEqualObjects( message.typeTagString, typeTagString );
    XCTAssertEqualObjects( messageReceived.typeTagString, typeTagString );
    
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

- (void) testThat_16_F53OSCMessageCanSendQSCArgumentFalse
{
    // given
    NSString *address = @"/thump";
    NSArray<NSString *> *arguments = @[ @"\\F" ];
    NSString *typeTagString = @",F";
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];
    
    // when
    NSString *qsc = [NSString stringWithFormat:@"%@ %@", address, [arguments componentsJoinedByString:@" "]];
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
    XCTAssertEqualObjects( message.typeTagString, typeTagString );
    XCTAssertEqualObjects( messageReceived.typeTagString, typeTagString );
    
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

- (void) testThat_17_F53OSCMessageCanSendQSCArgumentNull
{
    // given
    NSString *address = @"/thump";
    NSArray<NSString *> *arguments = @[ @"\\N" ];
    NSString *typeTagString = @",N";
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];
    
    // when
    NSString *qsc = [NSString stringWithFormat:@"%@ %@", address, [arguments componentsJoinedByString:@" "]];
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
    XCTAssertEqualObjects( message.typeTagString, typeTagString );
    XCTAssertEqualObjects( messageReceived.typeTagString, typeTagString );
    
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

- (void) testThat_18_F53OSCMessageCanSendQSCArgumentImpluse
{
    // given
    NSString *address = @"/thump";
    NSArray<NSString *> *arguments = @[ @"\\I" ];
    NSString *typeTagString = @",I";
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];
    
    // when
    NSString *qsc = [NSString stringWithFormat:@"%@ %@", address, [arguments componentsJoinedByString:@" "]];
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
    XCTAssertEqualObjects( message.typeTagString, typeTagString );
    XCTAssertEqualObjects( messageReceived.typeTagString, typeTagString );
    
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

- (void) testThat_19_F53OSCMessageCanSendMultipleArguments
{
    // given
    NSString *address = @"/thump";
    NSArray *arguments = @[@"thump",
                           [@"thump" dataUsingEncoding:NSUTF8StringEncoding],
                           @(INT32_MAX),
                           @(FLT_MAX),
                           [NSValue oscTrue],
                           [NSValue oscFalse],
                           [NSValue oscNull],
                           [NSValue oscImpulse],
                           ];
    NSString *typeTagString = @",sbifTFNI";
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
    XCTAssertEqualObjects( message.typeTagString, typeTagString );
    XCTAssertEqualObjects( messageReceived.typeTagString, typeTagString );
    XCTAssertEqual( message.arguments.count, arguments.count );
    XCTAssertEqual( messageReceived.arguments.count, arguments.count );
    for ( NSUInteger i = 0; i < arguments.count; i++ )
    {
        id arg = arguments[i];
        XCTAssertEqualObjects( messageReceived.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg );
    }
}

- (void) testThat_20_F53OSCMessageCanSendMultipleQSCArguments
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
    NSString *typeTagString = @",sbifTFNI";
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];
    
    // when
    NSString *qsc = [NSString stringWithFormat:@"%@ %@", address, [arguments componentsJoinedByString:@" "]];
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
    XCTAssertEqualObjects( message.typeTagString, typeTagString );
    XCTAssertEqualObjects( messageReceived.typeTagString, typeTagString );
    
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

- (void) testThat_21_F53OSCMessageCanSendMultipleStringArguments
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
    NSString *typeTagString = @",ssssssssssssssss";
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
    XCTAssertEqualObjects( message.typeTagString, typeTagString );
    XCTAssertEqualObjects( messageReceived.typeTagString, typeTagString );
    XCTAssertEqual( message.arguments.count, arguments.count );
    XCTAssertEqual( messageReceived.arguments.count, arguments.count );
    for ( NSUInteger i = 0; i < arguments.count; i++ )
    {
        id arg = arguments[i];
        XCTAssertEqualObjects( messageReceived.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg );
    }
}

- (void) testThat_22_F53OSCMessageCanSendMultipleQSCStringArguments
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
    NSString *typeTagString = @",ssssssssssssssss";
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];
    
    // when
    NSString *qsc = [NSString stringWithFormat:@"%@ %@", address, [arguments componentsJoinedByString:@" "]];
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
    XCTAssertEqualObjects( message.typeTagString, typeTagString );
    XCTAssertEqualObjects( messageReceived.typeTagString, typeTagString );
    
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

- (void) testThat_23_F53OSCMessageCanSendMultipleBlobArguments
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
    NSString *typeTagString = @",bbbbbbbbbbbbbbbb";
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
    XCTAssertEqualObjects( message.typeTagString, typeTagString );
    XCTAssertEqualObjects( messageReceived.typeTagString, typeTagString );
    XCTAssertEqual( message.arguments.count, arguments.count );
    XCTAssertEqual( messageReceived.arguments.count, arguments.count );
    for ( NSUInteger i = 0; i < arguments.count; i++ )
    {
        id arg = arguments[i];
        XCTAssertEqualObjects( messageReceived.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg );
    }
}

- (void) testThat_24_F53OSCMessageCanSendMultipleQSCBlobArguments
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
    NSString *typeTagString = @",bbbbbbbbbbbbbbbb";
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:address];
    [self.messageExpectations addObject:expectation];
    
    // when
    NSString *qsc = [NSString stringWithFormat:@"%@ %@", address, [arguments componentsJoinedByString:@" "]];
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
    XCTAssertEqualObjects( message.typeTagString, typeTagString );
    XCTAssertEqualObjects( messageReceived.typeTagString, typeTagString );
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
}

- (void) testThat_25_F53OSCMessageCanSendOSCBundle
{
    // given
    F53OSCTimeTag *timeTag = [F53OSCTimeTag immediateTimeTag];
    
    NSString *address1 = @"/thump";
    NSArray *arguments1 = @[ @"thump" ];
    NSString *typeTagString1 = @",s";
    F53OSCMessage *message1 = [F53OSCMessage messageWithAddressPattern:address1 arguments:arguments1];
    XCTestExpectation *expectation1 = [[XCTestExpectation alloc] initWithDescription:address1];
    [self.messageExpectations addObject:expectation1];
    
    NSArray<NSData *> *elements = @[ message1.packetData ];
    
    // when
    F53OSCBundle *bundle = [F53OSCBundle bundleWithTimeTag:timeTag elements:elements];
    [self.oscClient sendPacket:bundle];
    
    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[ expectation1 ] timeout:5.0];
    XCTAssert( result == XCTWaiterResultCompleted, @"OSC message failed to arrive - %@", self.name );
    
    XCTAssertNotNil( bundle );
    XCTAssertEqualObjects( bundle.timeTag, timeTag );
    XCTAssertEqual( bundle.elements.count, elements.count );
    XCTAssertEqualObjects( bundle.elements, elements );
    
    F53OSCMessage *message1Received = self.matchedExpectations[expectation1.description];
    XCTAssertNotNil( message1 );
    XCTAssertNotNil( message1Received );
    XCTAssertNil( message1.userData );
    XCTAssertNil( message1Received.userData );
    XCTAssertEqualObjects( message1.addressPattern, address1 );
    XCTAssertEqualObjects( message1Received.addressPattern, address1 );
    XCTAssertEqualObjects( message1.typeTagString, typeTagString1 );
    XCTAssertEqualObjects( message1Received.typeTagString, typeTagString1 );
    XCTAssertEqual( message1.arguments.count, arguments1.count );
    XCTAssertEqual( message1Received.arguments.count, arguments1.count );
    for ( NSUInteger i = 0; i < arguments1.count; i++ )
    {
        id arg = arguments1[i];
        XCTAssertEqualObjects( message1Received.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg );
    }
}

- (void) testThat_26_F53OSCMessageCanSendOSCBundleMultipleArguments
{
    // given
    F53OSCTimeTag *timeTag = [F53OSCTimeTag immediateTimeTag];
    
    NSString *address1 = @"/thump";
    NSArray *arguments1 = @[ @"thump" ];
    NSString *typeTagString1 = @",s";
    F53OSCMessage *message1 = [F53OSCMessage messageWithAddressPattern:address1 arguments:arguments1];
    XCTestExpectation *expectation1 = [[XCTestExpectation alloc] initWithDescription:address1];
    [self.messageExpectations addObject:expectation1];
    
    NSString *address2 = @"/thumpthump";
    NSArray *arguments2 = @[ @123 ];
    NSString *typeTagString2 = @",i";
    F53OSCMessage *message2 = [F53OSCMessage messageWithAddressPattern:address2 arguments:arguments2];
    XCTestExpectation *expectation2 = [[XCTestExpectation alloc] initWithDescription:address2];
    [self.messageExpectations addObject:expectation2];

    NSArray<NSData *> *elements = @[ message1.packetData, message2.packetData ];
    
    // when
    F53OSCBundle *bundle = [F53OSCBundle bundleWithTimeTag:timeTag elements:elements];
    [self.oscClient sendPacket:bundle];
    
    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[ expectation1, expectation2 ] timeout:5.0];
    XCTAssert( result == XCTWaiterResultCompleted, @"OSC messages failed to arrive - %@", self.name );
    
    XCTAssertNotNil( bundle );
    XCTAssertEqualObjects( bundle.timeTag, timeTag );
    XCTAssertEqual( bundle.elements.count, elements.count );
    XCTAssertEqualObjects( bundle.elements, elements );
    
    F53OSCMessage *message1Received = self.matchedExpectations[expectation1.description];
    XCTAssertNotNil( message1 );
    XCTAssertNotNil( message1Received );
    XCTAssertNil( message1.userData );
    XCTAssertNil( message1Received.userData );
    XCTAssertEqualObjects( message1.addressPattern, address1 );
    XCTAssertEqualObjects( message1Received.addressPattern, address1 );
    XCTAssertEqualObjects( message1.typeTagString, typeTagString1 );
    XCTAssertEqualObjects( message1Received.typeTagString, typeTagString1 );
    XCTAssertEqual( message1.arguments.count, arguments1.count );
    XCTAssertEqual( message1Received.arguments.count, arguments1.count );
    for ( NSUInteger i = 0; i < arguments1.count; i++ )
    {
        id arg = arguments1[i];
        XCTAssertEqualObjects( message1Received.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg );
    }
    
    F53OSCMessage *message2Received = self.matchedExpectations[expectation2.description];
    XCTAssertNotNil( message2 );
    XCTAssertNotNil( message2Received );
    XCTAssertNil( message2.userData );
    XCTAssertNil( message2Received.userData );
    XCTAssertEqualObjects( message2.addressPattern, address2 );
    XCTAssertEqualObjects( message2Received.addressPattern, address2 );
    XCTAssertEqualObjects( message2.typeTagString, typeTagString2 );
    XCTAssertEqualObjects( message2Received.typeTagString, typeTagString2 );
    XCTAssertEqual( message2.arguments.count, arguments2.count );
    XCTAssertEqual( message2Received.arguments.count, arguments2.count );
    for ( NSUInteger i = 0; i < arguments2.count; i++ )
    {
        id arg = arguments2[i];
        XCTAssertEqualObjects( message2Received.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg );
    }
}

- (void) testThat_27_F53OSCMessageCanSendOSCRecursiveBundles
{
    // given
    F53OSCTimeTag *timeTag = [F53OSCTimeTag immediateTimeTag];
    
    NSString *address1 = @"/thump";
    NSArray *arguments1 = @[ @"thump" ];
    NSString *typeTagString1 = @",s";
    F53OSCMessage *message1 = [F53OSCMessage messageWithAddressPattern:address1 arguments:arguments1];
    XCTestExpectation *expectation1 = [[XCTestExpectation alloc] initWithDescription:address1];
    [self.messageExpectations addObject:expectation1];
    
    NSString *address2 = @"/thumpthump";
    NSArray *arguments2 = @[ @123 ];
    NSString *typeTagString2 = @",i";
    F53OSCMessage *message2 = [F53OSCMessage messageWithAddressPattern:address2 arguments:arguments2];
    XCTestExpectation *expectation2 = [[XCTestExpectation alloc] initWithDescription:address2];
    [self.messageExpectations addObject:expectation2];
    
    NSString *address3 = @"/child/thump";
    NSArray *arguments3 = @[ [NSValue oscTrue] ];
    NSString *typeTagString3 = @",T";
    F53OSCMessage *message3 = [F53OSCMessage messageWithAddressPattern:address3 arguments:arguments3];
    XCTestExpectation *expectation3 = [[XCTestExpectation alloc] initWithDescription:address3];
    [self.messageExpectations addObject:expectation3];
    
    NSString *address4 = @"/child/complex/thump";
    NSArray *arguments4 = @[ [NSValue oscFalse], [NSValue oscImpulse], [@"thumpthumpthumpy" dataUsingEncoding:NSUTF8StringEncoding], @"thumpthumpthumpy" ];
    NSString *typeTagString4 = @",FIbs";
    F53OSCMessage *message4 = [F53OSCMessage messageWithAddressPattern:address4 arguments:arguments4];
    XCTestExpectation *expectation4 = [[XCTestExpectation alloc] initWithDescription:address4];
    [self.messageExpectations addObject:expectation4];
    
    NSArray<NSData *> *childElements = @[ message3.packetData, message4.packetData ];
    F53OSCBundle *childBundle = [F53OSCBundle bundleWithTimeTag:timeTag elements:childElements];
    
    NSArray<NSData *> *elements = @[ message1.packetData, childBundle.packetData, message2.packetData ];
    
    // when
    F53OSCBundle *bundle = [F53OSCBundle bundleWithTimeTag:timeTag elements:elements];
    [self.oscClient sendPacket:bundle];
    
    // then
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[ expectation1, expectation2, expectation3, expectation4 ] timeout:5.0];
    XCTAssert( result == XCTWaiterResultCompleted, @"OSC messages failed to arrive - %@", self.name );
    
    XCTAssertNotNil( childBundle );
    XCTAssertEqualObjects( childBundle.timeTag, timeTag );
    XCTAssertEqual( childBundle.elements.count, childElements.count );
    XCTAssertEqualObjects( childBundle.elements, childElements );
    
    XCTAssertNotNil( bundle );
    XCTAssertEqualObjects( bundle.timeTag, timeTag );
    XCTAssertEqual( bundle.elements.count, elements.count );
    XCTAssertEqualObjects( bundle.elements, elements );
    
    F53OSCMessage *message1Received = self.matchedExpectations[expectation1.description];
    XCTAssertNotNil( message1 );
    XCTAssertNotNil( message1Received );
    XCTAssertNil( message1.userData );
    XCTAssertNil( message1Received.userData );
    XCTAssertEqualObjects( message1.addressPattern, address1 );
    XCTAssertEqualObjects( message1Received.addressPattern, address1 );
    XCTAssertEqualObjects( message1.typeTagString, typeTagString1 );
    XCTAssertEqualObjects( message1Received.typeTagString, typeTagString1 );
    XCTAssertEqual( message1.arguments.count, arguments1.count );
    XCTAssertEqual( message1Received.arguments.count, arguments1.count );
    for ( NSUInteger i = 0; i < arguments1.count; i++ )
    {
        id arg = arguments1[i];
        XCTAssertEqualObjects( message1Received.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg );
    }
    
    F53OSCMessage *message2Received = self.matchedExpectations[expectation2.description];
    XCTAssertNotNil( message2 );
    XCTAssertNotNil( message2Received );
    XCTAssertNil( message2.userData );
    XCTAssertNil( message2Received.userData );
    XCTAssertEqualObjects( message2.addressPattern, address2 );
    XCTAssertEqualObjects( message2Received.addressPattern, address2 );
    XCTAssertEqualObjects( message2.typeTagString, typeTagString2 );
    XCTAssertEqualObjects( message2Received.typeTagString, typeTagString2 );
    XCTAssertEqual( message2.arguments.count, arguments2.count );
    XCTAssertEqual( message2Received.arguments.count, arguments2.count );
    for ( NSUInteger i = 0; i < arguments2.count; i++ )
    {
        id arg = arguments2[i];
        XCTAssertEqualObjects( message2Received.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg );
    }
    
    F53OSCMessage *message3Received = self.matchedExpectations[expectation3.description];
    XCTAssertNotNil( message3 );
    XCTAssertNotNil( message3Received );
    XCTAssertNil( message3.userData );
    XCTAssertNil( message3Received.userData );
    XCTAssertEqualObjects( message3.addressPattern, address3 );
    XCTAssertEqualObjects( message3Received.addressPattern, address3 );
    XCTAssertEqualObjects( message3.typeTagString, typeTagString3 );
    XCTAssertEqualObjects( message3Received.typeTagString, typeTagString3 );
    XCTAssertEqual( message3.arguments.count, arguments3.count );
    XCTAssertEqual( message3Received.arguments.count, arguments3.count );
    for ( NSUInteger i = 0; i < arguments3.count; i++ )
    {
        id arg = arguments3[i];
        XCTAssertEqualObjects( message3Received.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg );
    }
    
    F53OSCMessage *message4Received = self.matchedExpectations[expectation4.description];
    XCTAssertNotNil( message4 );
    XCTAssertNotNil( message4Received );
    XCTAssertNil( message4.userData );
    XCTAssertNil( message4Received.userData );
    XCTAssertEqualObjects( message4.addressPattern, address4 );
    XCTAssertEqualObjects( message4Received.addressPattern, address4 );
    XCTAssertEqualObjects( message4.typeTagString, typeTagString4 );
    XCTAssertEqualObjects( message4Received.typeTagString, typeTagString4 );
    XCTAssertEqual( message4.arguments.count, arguments4.count );
    XCTAssertEqual( message4Received.arguments.count, arguments4.count );
    for ( NSUInteger i = 0; i < arguments4.count; i++ )
    {
        id arg = arguments4[i];
        XCTAssertEqualObjects( message4Received.arguments[i], arg, @"arg index %ld not equal - %@", (unsigned long)i, arg );
    }
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
