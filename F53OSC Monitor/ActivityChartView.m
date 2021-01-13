//
//  ActivityChartView.m
//  F53OSC Monitor
//
//  Created by Adam Bachman on 8/10/15.
//  Copyright (c) 2015 Figure 53. All rights reserved.
//

#import "ActivityChartView.h"
#include <math.h>

#define CHART_WIDTH 360
#define CHART_HEIGHT 200
#define CHART_HEIGHT_FLOAT 200.0
#define DATA_POINTS 120

@interface ActivityChartView ()

@property (strong) NSMutableArray *dataPoints;

@end


@implementation ActivityChartView

- (void)awakeFromNib
{
    self.dataPoints = [NSMutableArray array];
    for (int i=0; i < DATA_POINTS; i++)
    {
        [self.dataPoints addObject:@0];
    }
}

- (void)addDataPoint:(NSNumber *)point
{
    [self.dataPoints removeObjectAtIndex:0];
    [self.dataPoints addObject:point];
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect
{
    CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
    
    NSNumber *max = @0;
    NSNumber *n;
    
    for (int i=0; i < DATA_POINTS; i++)
    {
        n = [self.dataPoints objectAtIndex:i];
        if ([max doubleValue] < [n doubleValue]) {
            max = n;
        }
    }
    
    if ( [max isLessThanOrEqualTo:@0] ) {
        max = @50;
    }
    
    double slope = 1.0 * CHART_HEIGHT / [max doubleValue];
    double barWidth = 1.0 * CHART_WIDTH / DATA_POINTS;
    
    // redraw background
    CGContextSetRGBFillColor (ctx, 0, 0, 0, 1);
    CGContextFillRect (ctx, CGRectMake (0, 0, CHART_WIDTH, CHART_HEIGHT ));
    
    // path
    CGMutablePathRef path = CGPathCreateMutable();
    
    // initial point at 0
    CGPathMoveToPoint(path, NULL, CHART_WIDTH, 0);
    CGPathAddLineToPoint(path, NULL, CHART_WIDTH, 0);
    
    for (int i=0; i < DATA_POINTS; i++)
    {
        double normalizedValue = slope * [[self.dataPoints objectAtIndex:i] doubleValue] + 0.5;
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
