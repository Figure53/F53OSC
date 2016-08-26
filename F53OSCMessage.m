//
//  F53OSCMessage.m
//
//  Created by Sean Dougall on 1/17/11.
//
//  Copyright (c) 2011-2016 Figure 53 LLC, http://figure53.com
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
//  Reference information: http://opensoundcontrol.org/spec-1_0-examples
//

#if !__has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#import "F53OSCMessage.h"
#import "F53OSCServer.h"
#import "F53OSCFoundationAdditions.h"

@implementation F53OSCMessage

static NSCharacterSet *LEGAL_ADDRESS_CHARACTERS = nil;
static NSCharacterSet *LEGAL_METHOD_CHARACTERS = nil;

+ (void) initialize
{
    if ( !LEGAL_ADDRESS_CHARACTERS )
    {
        NSString *legalAddressChars = [NSString stringWithFormat:@"%@/*?[]{,}", [F53OSCServer validCharsForOSCMethod]];
        LEGAL_ADDRESS_CHARACTERS = [NSCharacterSet characterSetWithCharactersInString:legalAddressChars];
        LEGAL_METHOD_CHARACTERS = [NSCharacterSet characterSetWithCharactersInString:[F53OSCServer validCharsForOSCMethod]];
    }
}

+ (BOOL) legalAddressComponent:(NSString *)addressComponent
{
    if ( addressComponent == nil )
        return NO;
    
    if ( [LEGAL_ADDRESS_CHARACTERS isSupersetOfSet:[NSCharacterSet characterSetWithCharactersInString:addressComponent]] )
    {
        if ( [addressComponent length] >= 1 )
            return YES;
    }
    
    return NO;
}

+ (BOOL) legalAddress:(NSString *)address
{
    if ( address == nil )
        return NO;
    
    if ( [LEGAL_ADDRESS_CHARACTERS isSupersetOfSet:[NSCharacterSet characterSetWithCharactersInString:address]] )
    {
        if ( [address length] >= 1 && [address characterAtIndex:0] == '/' )
            return YES;
    }
    
    return NO;
}

+ (BOOL) legalMethod:(NSString *)method
{
    if ( method == nil )
        return NO;
    
    if ( [LEGAL_METHOD_CHARACTERS isSupersetOfSet:[NSCharacterSet characterSetWithCharactersInString:method]] )
        return YES;
    else
        return NO;
}

+ (F53OSCMessage *) messageWithString:(NSString *)qscString
{
    if ( qscString == nil )
        return nil;
    
    qscString = [qscString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if ( [qscString isEqualToString:@""] )
        return nil;
    
    // Pull out address.
    NSString *address = [[qscString componentsSeparatedByString:@" "] objectAtIndex:0];
    if ( ![self legalAddress:address] )
    {
        // Note: We'll return here if caller tried to parse a QSC bundle string as a message string;
        //       The # character used in the #bundle string is not a legal address character.
        return nil;
    }
    
    // Pull out arguments...
    
    // TODO: support \T for true, \F for false, \N for null, and \I for impulse
    
    // Create a working copy and place a token for each escaped " character.
    NSString *QUOTE_CHAR_TOKEN = @"⍁"; // not trying to be perfect here; we just use an unlikely character
    NSString *workingArguments = [qscString substringFromIndex:[address length]];
    workingArguments = [workingArguments stringByReplacingOccurrencesOfString:@"\\\"" withString:QUOTE_CHAR_TOKEN];
    
    // The remaining " characters signify quoted string arguments; they should be paired up.
    NSArray *splitOnQuotes = [workingArguments componentsSeparatedByString:@"\""];
    if ( [splitOnQuotes count] % 2 != 1 )
        return nil; // not matching quotes

    NSString *QUOTE_STRING_TOKEN = @"⍂"; // not trying to be perfect here; we just use an unlikely character
    NSMutableArray *allQuotedStrings = [NSMutableArray array];
    for ( NSUInteger i = 1; i < [splitOnQuotes count]; i += 2 )
    {
        // Pull out each quoted string, which will be at each odd index.
        NSString *quotedString = [splitOnQuotes objectAtIndex:i];
        [allQuotedStrings addObject:quotedString];
        
        // Place a token for the quote we just pulled.
        NSString *extractedQuote = [NSString stringWithFormat:@"\"%@\"", quotedString];
        NSRange rangeOfFirstOccurrence = [workingArguments rangeOfString:extractedQuote];
        workingArguments = [workingArguments stringByReplacingOccurrencesOfString:extractedQuote
                                                                       withString:QUOTE_STRING_TOKEN
                                                                          options:0
                                                                            range:rangeOfFirstOccurrence];
    }
    
    // The working arguments have now been tokenized enough to process.
    // Expand the tokens and store the final array of arguments.
    NSMutableArray *finalArgs = [NSMutableArray array];
    NSArray *tokenArgs = [workingArguments componentsSeparatedByString:@" "];
    int token_index = 0;
    for ( NSString *arg in tokenArgs )
    {
        if ( [arg isEqual:@""] ) // artifact of componentsSeparatedByString
            continue;
        
        if ( [arg isEqual:QUOTE_STRING_TOKEN] )
        {
            NSString *detokenized = [[allQuotedStrings objectAtIndex:token_index]
                                     stringByReplacingOccurrencesOfString:QUOTE_CHAR_TOKEN withString:@"\""];
            [finalArgs addObject:detokenized]; // quoted OSC string
            token_index++;
        }
        else if ( [arg isEqual:QUOTE_CHAR_TOKEN] )
        {
            [finalArgs addObject:@"\""];       // single character OSC string
        }
        else if ( [arg hasPrefix:@"#blob"] )
        {
            NSString *encodedBlob = [arg substringFromIndex:5]; // strip #blob
            if ( [encodedBlob isEqual:@""] )
                continue;
            
            NSData *blob = [[NSData alloc] initWithBase64EncodedString:encodedBlob options:0];
            if ( blob )
            {
                [finalArgs addObject:blob];    // OSC blob
            }
            else
            {
                NSLog( @"Error: F53OSCMessage: Unable to decode base64 encoded string: %@", encodedBlob );
            }
        }
        else
        {
            NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
            [formatter setLocale:[NSLocale currentLocale]];
            [formatter setAllowsFloats:YES];
            
            NSNumber *number = [formatter numberFromString:arg];
            if ( number == nil )
                [finalArgs addObject:arg];     // unquoted OSC string
            else
                [finalArgs addObject:number];  // OSC int or float
        }
    }
    
    NSArray *arguments = [NSArray arrayWithArray:finalArgs];
    
    return [F53OSCMessage messageWithAddressPattern:address arguments:arguments];
}

+ (F53OSCMessage *) messageWithAddressPattern:(NSString *)addressPattern
                                    arguments:(NSArray *)arguments
{
    return [F53OSCMessage messageWithAddressPattern:addressPattern arguments:arguments replySocket:nil];
}

+ (F53OSCMessage *) messageWithAddressPattern:(NSString *)addressPattern 
                                    arguments:(NSArray *)arguments
                                  replySocket:(F53OSCSocket *)replySocket
{
    F53OSCMessage *msg = [F53OSCMessage new];
    msg.addressPattern = addressPattern;
    msg.arguments = arguments;
    msg.replySocket = replySocket;
    return msg;
}

- (id) init
{
    self = [super init];
    if ( self )
    {
        self.addressPattern = @"/";
        self.typeTagString = @",";
        self.arguments = [NSArray array];
        self.userData = nil;
    }
    return self;
}

- (void) encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.addressPattern forKey:@"addressPattern"];
    [coder encodeObject:self.typeTagString forKey:@"typeTagString"];
    [coder encodeObject:self.arguments forKey:@"arguments"];
}

- (id) initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if ( self )
    {
        [self setAddressPattern:[coder decodeObjectForKey:@"addressPattern"]];
        [self setTypeTagString:[coder decodeObjectForKey:@"typeTagString"]];
        [self setArguments:[coder decodeObjectForKey:@"arguments"]];
    }
    return self;
}

- (id) copyWithZone:(NSZone *)zone
{
    F53OSCMessage *copy = [super copyWithZone:zone];
    copy.addressPattern = [self.addressPattern copyWithZone:zone];
    copy.typeTagString = [self.typeTagString copyWithZone:zone];
    copy.arguments = [self.arguments copyWithZone:zone];
    copy.userData = [self.userData copyWithZone:zone];
    return copy;
}

- (NSString *) description
{
    NSMutableString *description = [NSMutableString stringWithString:self.addressPattern];
    for ( id arg in self.arguments )
    {
        if ( [[arg class] isSubclassOfClass:[NSString class]] )
            [description appendFormat:@" \"%@\"", [arg description]]; // make strings clear in debug logs
        else
            [description appendFormat:@" %@", [arg description]];
    }
    return [NSString stringWithString:description];
}

- (BOOL) isEqual:(id)object
{
    if ( [object isMemberOfClass:[self class]] )
    {
        F53OSCMessage *otherObject = object;
        if (   [otherObject.addressPattern isEqualToString:self.addressPattern]
            && [otherObject.arguments isEqualToArray:self.arguments] )
        {
            return YES;
        }
    }
    return NO;
}

- (void) setAddressPattern:(NSString *)newAddressPattern
{
    if ( newAddressPattern == nil ||
        [newAddressPattern length] == 0 ||
        [newAddressPattern characterAtIndex:0] != '/' )
    {
        return;
    }
    
    _addressPattern = [newAddressPattern copy];
}

- (void) setArguments:(NSArray *)argArray
{
    NSMutableArray *newArgs = [NSMutableArray array];
    NSMutableString *newTypes = [NSMutableString stringWithString:@","];
    for ( id obj in argArray )
    {
        if ( [obj isKindOfClass:[NSString class]] )
        {
            [newTypes appendString:@"s"]; // OSC string
            [newArgs addObject:obj];
        }
        else if ( [obj isKindOfClass:[NSData class]] )
        {
            [newTypes appendString:@"b"]; // OSC blob
            [newArgs addObject:obj];
        }
        else if ( [obj isKindOfClass:[NSNumber class]] )
        {
            CFNumberType numberType = CFNumberGetType( (CFNumberRef)obj );
            switch ( numberType )
            {
                case kCFNumberSInt8Type:
                case kCFNumberSInt16Type:
                case kCFNumberSInt32Type:
                case kCFNumberSInt64Type:
                case kCFNumberCharType:
                case kCFNumberShortType:
                case kCFNumberIntType:
                case kCFNumberLongType:
                case kCFNumberLongLongType:
                case kCFNumberNSIntegerType:
                    [newTypes appendString:@"i"]; break; // OSC integer
                case kCFNumberFloat32Type:
                case kCFNumberFloat64Type:
                case kCFNumberFloatType:
                case kCFNumberDoubleType:
                case kCFNumberCGFloatType:
                    [newTypes appendString:@"f"]; break; // OSC float
                default:
                    NSLog( @"Number with unrecognized type: %i (value = %@).", (int)numberType, obj );
                    continue;
            }
            [newArgs addObject:obj];
        }
    }
    self.typeTagString = [newTypes copy];
    _arguments = [newArgs copy];
}

- (NSArray *) addressParts
{
    NSMutableArray *parts = [NSMutableArray arrayWithArray:[self.addressPattern componentsSeparatedByString:@"/"]];
    [parts removeObjectAtIndex:0];
    return [NSArray arrayWithArray:parts];
}

- (NSData *) packetData
{
    NSMutableData *result = [[self.addressPattern oscStringData] mutableCopy];
    
    [result appendData:[self.typeTagString oscStringData]];
    
    for ( id obj in self.arguments )
    {
        if ( [obj isKindOfClass:[NSString class]] )
        {
            [result appendData:[(NSString *)obj oscStringData]];
        }
        else if ( [obj isKindOfClass:[NSData class]] )
        {
            [result appendData:[(NSData *)obj oscBlobData]];
        }
        else if ( [obj isKindOfClass:[NSNumber class]] )
        {
            SInt32 intValue;
            CFNumberType numberType = CFNumberGetType( (CFNumberRef)obj );
            switch ( numberType )
            {
                case kCFNumberSInt8Type:
                case kCFNumberSInt16Type:
                case kCFNumberSInt32Type:
                case kCFNumberSInt64Type:
                case kCFNumberCharType:
                case kCFNumberShortType:
                case kCFNumberIntType:
                case kCFNumberLongType:
                case kCFNumberLongLongType:
                case kCFNumberNSIntegerType:
                    intValue = [(NSNumber *)obj oscIntValue];
                    [result appendBytes:&intValue length:sizeof( SInt32 )];
                    break;
                case kCFNumberFloat32Type:
                case kCFNumberFloat64Type:
                case kCFNumberFloatType:
                case kCFNumberDoubleType:
                case kCFNumberCGFloatType:
                    intValue = [(NSNumber *)obj oscFloatValue];
                    [result appendBytes:&intValue length:sizeof( SInt32 )];
                    break;
                default:
                    NSLog( @"Number with unrecognized type: %i (value = %@).", (int)numberType, obj );
                    continue;
            }
        }
    }
    
    return result;
}

- (NSString *) asQSC
{
    NSMutableString *qscString = [NSMutableString stringWithString:self.addressPattern];
    for ( id arg in self.arguments )
    {
        if ( [arg isKindOfClass:[NSString class]] )
        {
            [qscString appendFormat:@" \"%@\"", arg];
        }
        if ( [arg isKindOfClass:[NSNumber class]] )
        {
            [qscString appendFormat:@" %@", arg]; // TODO: forcibly preserve number type (int/float)?
        }
        if ( [arg isKindOfClass:[NSData class]] )
        {
            [qscString appendFormat:@" #blob%@", [arg base64EncodedStringWithOptions:0]];
        }
    }
    return [NSString stringWithString:qscString];
}

@end
