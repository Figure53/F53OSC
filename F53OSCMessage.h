//
//  F53OSCMessage.h
//
//  Created by Sean Dougall on 1/17/11.
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

#import "F53OSCPacket.h"

///
///  Example usage:
///
///  F53OSCMessage *msg = [F53OSCMessage messageWithAddressPattern:@"/address/of/thing" 
///                                                      arguments:[NSArray arrayWithObjects:
///                                                                 [NSNumber numberWithInteger:x],
///                                                                 [NSNumber numberWithFloat:y],
///                                                                 @"z",
///                                                                 nil]];
///

@interface F53OSCMessage : F53OSCPacket <NSCoding, NSCopying>
{
    NSString *_addressPattern;
    NSString *_typeTagString;
    NSArray *_arguments;
    id _userData;
}

+ (BOOL) legalAddressComponent:(NSString *)addressComponent;
+ (BOOL) legalAddress:(NSString *)address;
+ (BOOL) legalMethod:(NSString *)method;
+ (F53OSCMessage *) messageWithString:(NSString *)string;
+ (F53OSCMessage *) messageWithAddressPattern:(NSString *)addressPattern
                                    arguments:(NSArray *)arguments;
+ (F53OSCMessage *) messageWithAddressPattern:(NSString *)addressPattern 
                                    arguments:(NSArray *)arguments
                                  replySocket:(F53OSCSocket *)replySocket;

@property (nonatomic, copy) NSString *addressPattern;
@property (nonatomic, retain) NSString *typeTagString;   ///< This is normally constructed from the incoming arguments array.
@property (nonatomic, retain) NSArray *arguments;        ///< May contain NSString, NSData, or NSNumber objects. This could be extended in the future, but those three cover the four mandatory OSC types.
@property (nonatomic, retain) id userData;               

- (NSArray *) addressParts;

@end
