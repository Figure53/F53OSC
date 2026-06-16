//
//  F53OSCBrowser+Internal.h
//  F53OSC Tests
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

//  Internal category exposing seam methods for testing. Tests call
//  _addDiscoveredService: / _removeDiscoveredService: directly with synthetic
//  F53OSCServiceRef inputs. Production callers are inside F53OSCBrowser.m.

#if F53OSC_BUILT_AS_FRAMEWORK
#import <F53OSC/F53OSCBrowser.h>
#import <F53OSC/F53OSCServiceRef.h>
#else
#import "F53OSCBrowser.h"
#import "F53OSCServiceRef.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@interface F53OSCBrowser (Internal)

// Filters the service through the delegate and, if accepted, adds an F53OSCClientRecord
// to clientRecords and calls `browser:didAddClientRecord:`.
// Must be on the main thread (or dispatches there internally). Tests may call directly.
- (void) _addDiscoveredService:(F53OSCServiceRef *)service;

// Removes the F53OSCClientRecord for the given service and calls `browser:didRemoveClientRecord:`.
// Must be on the main thread (or dispatches there internally). Tests may call directly.
- (void) _removeDiscoveredService:(F53OSCServiceRef *)service;

@end

NS_ASSUME_NONNULL_END
