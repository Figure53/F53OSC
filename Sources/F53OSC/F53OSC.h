//
//  F53OSC.h
//  F53OSC
//
//  Created by Siobhán Dougall on 1/17/11.
//  Copyright (c) 2011-2025 Figure 53 LLC, https://figure53.com
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

// F53OSC-Swift.h only exists when building F53OSC as a framework.
// If not building as a framework, the Swift compatibility header is not required.
#define F53OSC_BUILT_AS_FRAMEWORK __has_include(<F53OSC/F53OSC-Swift.h>)

// Set this to agree with your GCC_WARN_CHECK_SWITCH_STATEMENTS build setting.
// If GCC_WARN_CHECK_SWITCH_STATEMENTS is "No", set to 0. Otherwise leave set to 1
// which omits several `default:` cases and allows the compiler to verify all cases.
#define F53OSC_EXHAUSTIVE_SWITCH_ENABLED    1


#if F53OSC_BUILT_AS_FRAMEWORK
#import <F53OSC/F53OSCBrowser.h>
#import <F53OSC/F53OSCEncryptHandshake.h>
#import <F53OSC/F53OSCParser.h>
#import <F53OSC/F53OSCSocket.h>
#import <F53OSC/F53OSCPacket.h>
#import <F53OSC/F53OSCMessage.h>
#import <F53OSC/F53OSCBundle.h>
#import <F53OSC/F53OSCClient.h>
#import <F53OSC/F53OSCServer.h>
#import <F53OSC/F53OSCTimeTag.h>
#else
#import "F53OSCBrowser.h"
#import "F53OSCEncryptHandshake.h"
#import "F53OSCParser.h"
#import "F53OSCSocket.h"
#import "F53OSCPacket.h"
#import "F53OSCMessage.h"
#import "F53OSCBundle.h"
#import "F53OSCClient.h"
#import "F53OSCServer.h"
#import "F53OSCTimeTag.h"
#endif
