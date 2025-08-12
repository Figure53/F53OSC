//
//  ActivityChartView.m
//  F53OSC Monitor
//
//  Created by Adam Bachman on 8/10/15.
//  Copyright (c) 2015-2025 Figure 53. All rights reserved.
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

#import "ActivityChartView.h"
#include <math.h>


NS_ASSUME_NONNULL_BEGIN

#define CHART_WIDTH 360
#define CHART_HEIGHT 200
#define CHART_HEIGHT_FLOAT 200.0
#define DATA_POINTS 120

@interface ActivityChartView ()

@property (strong) NSMutableArray<NSNumber *> *dataPoints;

@end


@implementation ActivityChartView

- (void)awakeFromNib
{
    self.dataPoints = [NSMutableArray array];
    for (int i = 0; i < DATA_POINTS; i++)
        [self.dataPoints addObject:@0];
}

- (void)addDataPoint:(NSNumber *)point
{
    [self.dataPoints removeObjectAtIndex:0];
    [self.dataPoints addObject:point];
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect
{
    CGContextRef ctx = [[NSGraphicsContext currentContext] CGContext];
    
    CGFloat max = 0.0;
    CGFloat n = 0.0;

    for (int i = 0; i < DATA_POINTS; i++)
    {
        n = [[self.dataPoints objectAtIndex:i] doubleValue];
        if (max < n)
            max = n;
    }
    
    if (max <= 0)
        max = 50.0;

    CGFloat slope = 1.0 * CHART_HEIGHT / max;
    CGFloat barWidth = 1.0 * CHART_WIDTH / DATA_POINTS;

    // redraw background
    CGContextSetRGBFillColor (ctx, 0, 0, 0, 1);
    CGContextFillRect (ctx, CGRectMake (0, 0, CHART_WIDTH, CHART_HEIGHT));
    
    // path
    CGMutablePathRef path = CGPathCreateMutable();
    
    // initial point at 0
    CGPathMoveToPoint(path, NULL, CHART_WIDTH, 0);
    CGPathAddLineToPoint(path, NULL, CHART_WIDTH, 0);
    
    for (int i = 0; i < DATA_POINTS; i++)
    {
        CGFloat normalizedValue = slope * [[self.dataPoints objectAtIndex:i] doubleValue] + 0.5;
        if (i == 0)
            CGPathAddLineToPoint(path, NULL, CHART_WIDTH, normalizedValue);
        
        CGPathAddLineToPoint(path, NULL, CHART_WIDTH - (i * barWidth) + (barWidth / 2.0), normalizedValue);
    }
    
    // end at 0
    CGPathAddLineToPoint(path, NULL, 0, 0);
    CGPathMoveToPoint(path, NULL, 0, 0);
    
    // draw chart
    CGContextSetRGBFillColor (ctx, 0, 1, 0, 0.5);
    CGContextSetRGBStrokeColor (ctx, 0, 1, 0, 1);
    CGContextSetLineWidth (ctx, 2.0);
    CGPathCloseSubpath(path);
    CGContextAddPath(ctx, path);
    CGContextDrawPath(ctx, kCGPathFillStroke);
}

@end

NS_ASSUME_NONNULL_END
