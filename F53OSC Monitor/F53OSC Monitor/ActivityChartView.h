//
//  ActivityChartView.h
//  F53OSC Monitor
//
//  Created by Adam Bachman on 8/10/15.
//  Copyright (c) 2015 Figure 53. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ActivityChartView : NSView

- (void)addDataPoint:(NSNumber *)point;

@end
