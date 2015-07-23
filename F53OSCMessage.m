//
//  F53OSCMessage.m
//
//  Created by Sean Dougall on 1/17/11.
//
//  Copyright (c) 2011-2015 Figure 53 LLC, http://figure53.com
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

#import "F53OSCMessage.h"
#import "F53OSCServer.h"
#import "F53OSCFoundationAdditions.h"

@implementation F53OSCMessage

static NSCharacterSet *_LEGAL_ADDRESS_CHARACTERS = nil;
static NSCharacterSet *_LEGAL_METHOD_CHARACTERS = nil;

+ (void) initialize
{
    if ( !_LEGAL_ADDRESS_CHARACTERS )
    {
        NSString *legalAddressChars = [NSString stringWithFormat:@"%@/*?[]{,}", [F53OSCServer validCharsForOSCMethod]];
        _LEGAL_ADDRESS_CHARACTERS = [[NSCharacterSet characterSetWithCharactersInString:legalAddressChars] retain];
        
        _LEGAL_METHOD_CHARACTERS = [[NSCharacterSet characterSetWithCharactersInString:[F53OSCServer validCharsForOSCMethod]] retain];
    }
}

+ (BOOL) legalAddressComponent:(NSString *)addressComponent
{
    if ( addressComponent == nil )
        return NO;
    
    if ( [_LEGAL_ADDRESS_CHARACTERS isSupersetOfSet:[NSCharacterSet characterSetWithCharactersInString:addressComponent]] )
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
    
    if ( [_LEGAL_ADDRESS_CHARACTERS isSupersetOfSet:[NSCharacterSet characterSetWithCharactersInString:address]] )
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
    
    if ( [_LEGAL_METHOD_CHARACTERS isSupersetOfSet:[NSCharacterSet characterSetWithCharactersInString:method]] )
        return YES;
    else
        return NO;
}

+ (F53OSCMessage *) messageWithString:(NSString *)string
{
    if ( string == nil )
        return nil;
    
    string = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if ( [string isEqualToString:@""] )
        return nil;
    
    // Pull out address.
    NSString *address = [[string componentsSeparatedByString:@" "] objectAtIndex:0];
    if ( ![self legalAddress:address] )
        return nil;
    
    // Pull out arguments...
    
    // Create a working copy and place a token for each escaped " character.
    NSString *QUOTE_CHAR_TOKEN = @"•";
    NSString *workingArguments = [string substringFromIndex:[address length]];
    workingArguments = [workingArguments stringByReplacingOccurrencesOfString:@"\\\"" withString:QUOTE_CHAR_TOKEN];
    
    // The remaining " characters signify quoted string arguments; they should be paired up.
    NSArray *splitOnQuotes = [workingArguments componentsSeparatedByString:@"\""];
    if ( [splitOnQuotes count] % 2 != 1 )
        return nil; // not matching quotes

    NSString *QUOTE_STRING_TOKEN = @"∞";
    NSMutableArray *allQuotedStrings = [NSMutableArray array];
    for ( int i = 1; i < [splitOnQuotes count]; i += 2 )
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
            [finalArgs addObject:detokenized];
            token_index++;
        }
        else if ( [arg isEqual:QUOTE_CHAR_TOKEN] )
        {
            [finalArgs addObject:@"\""];
        }
        else
        {
            NSNumberFormatter *formatter = [[[NSNumberFormatter alloc] init] autorelease];
            [formatter setLocale:[NSLocale currentLocale]];
            [formatter setAllowsFloats:YES];
            
            NSNumber *number = [formatter numberFromString:arg];
            if ( number == nil )
                [finalArgs addObject:arg];
            else
                [finalArgs addObject:number];
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
    F53OSCMessage *msg = [[F53OSCMessage new] autorelease];
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

- (void) dealloc
{
    self.addressPattern = nil;
    self.typeTagString = nil;
    self.arguments = nil;
    self.userData = nil;
    
    [super dealloc];
}

- (void) encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_addressPattern forKey:@"addressPattern"];
    [coder encodeObject:_typeTagString forKey:@"typeTagString"];
    [coder encodeObject:_arguments forKey:@"arguments"];
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
    copy->_addressPattern = [_addressPattern copyWithZone:zone];
    copy->_typeTagString = [_typeTagString copyWithZone:zone];
    copy->_arguments = [_arguments copyWithZone:zone];
    copy->_userData = [_userData copyWithZone:zone];
    return copy;
}

- (NSString *) description
{
    NSMutableString *description = [NSMutableString stringWithString:self.addressPattern];
    for ( id arg in self.arguments )
    {
        [description appendFormat:@" %@", [arg description]];
    }
    return [NSString stringWithString:description];
}

- (BOOL) isEqual:(id)object
{
    if ( [object isMemberOfClass:[self class]] )
    {
        F53OSCMessage *otherObject = object;
        if (   [[otherObject addressPattern] isEqualToString:_addressPattern]
            && [[otherObject arguments] isEqualToArray:_arguments] )
        {
            return YES;
        }
    }
    return NO;
}

@synthesize addressPattern = _addressPattern;

- (void) setAddressPattern:(NSString *)addressPattern
{
    if ( addressPattern == nil ||
        [addressPattern length] == 0 ||
        [addressPattern characterAtIndex:0] != '/' )
    {
        return;
    }
    
    [_addressPattern autorelease];
    _addressPattern = [addressPattern copy];
}

@synthesize typeTagString = _typeTagString;

@synthesize arguments = _arguments;

- (void) setArguments:(NSArray *)argArray
{
    NSMutableArray *newArgs = [NSMutableArray array];
    NSMutableString *newTypes = [NSMutableString stringWithString:@","];
    for ( id obj in argArray )
    {
        if ( [obj isKindOfClass:[NSString class]] )
        {
            [newTypes appendString:@"s"];
            [newArgs addObject:obj];
        }
        else if ( [obj isKindOfClass:[NSData class]] )
        {
            [newTypes appendString:@"b"];
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
                    [newTypes appendString:@"i"]; break;
                case kCFNumberFloat32Type:
                case kCFNumberFloat64Type:
                case kCFNumberFloatType:
                case kCFNumberDoubleType:
                case kCFNumberCGFloatType:
                    [newTypes appendString:@"f"]; break;
                default:
                    NSLog( @"Number with unrecognized type: %i (value = %@).", (int)numberType, obj );
                    continue;
            }
            [newArgs addObject:obj];
        }
    }
    self.typeTagString = [[newTypes copy] autorelease];
    [_arguments autorelease];
    _arguments = [newArgs copy];
}

@synthesize userData = _userData;

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
    
    return [result autorelease];
}

@end
