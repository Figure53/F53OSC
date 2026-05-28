//
//  F53OSCServiceRef.h
//  F53OSC
//
//  Created by Christopher Cahoon on 5/23/26.
//  Copyright (c) 2026 Figure 53 LLC, https://figure53.com
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

NS_ASSUME_NONNULL_BEGIN

//
//  Immutable record describing a discovered Bonjour service. Replaces the
//  NSNetService *-typed surface on F53OSCBrowser as NSNetService and
//  NSNetServiceBrowser are deprecated since macOS 12 / iOS 15.
//

@interface F53OSCServiceRef : NSObject <NSCopying>

@property (nonatomic, copy, readonly)               NSString *name;
@property (nonatomic, copy, readonly)               NSString *type;
@property (nonatomic, copy, readonly)               NSString *domain;
@property (nonatomic, copy, readonly, nullable)     NSString *host;
@property (nonatomic, readonly)                     UInt16 port;
@property (nonatomic, copy, readonly)               NSArray<NSString *> *hostAddresses;
@property (nonatomic, copy, readonly, nullable)     NSDictionary<NSString *, NSString *> *txtRecord;

- (instancetype) initWithName:(NSString *)name
                         type:(NSString *)type
                       domain:(NSString *)domain
                         host:(nullable NSString *)host
                         port:(UInt16)port
                hostAddresses:(NSArray<NSString *> *)hostAddresses
                    txtRecord:(nullable NSDictionary<NSString *, NSString *> *)txtRecord NS_DESIGNATED_INITIALIZER;

- (instancetype) init NS_UNAVAILABLE;
+ (instancetype) new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
