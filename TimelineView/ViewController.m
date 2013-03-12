//
//  ViewController.m
//  TimelineView
//
//  Created by Luke Scott on 3/4/13.
//  Copyright (c) 2013 Luke Scott. All rights reserved.
//

#import "ViewController.h"
#import "TimelineView.h"
#import "SampleTimelineViewCell.h"

@interface ViewController ()
{
    NSMutableArray *data;
}
@end

@implementation ViewController
@synthesize timelineView = _timelineView;

- (NSInteger)randFrom:(NSInteger)from to:(NSInteger)to
{
    return (arc4random() % to) + from;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSInteger num = 100000;
    NSInteger lastPos = 0;
    NSInteger minSep = 96;
    NSInteger maxSep = 384;
    NSInteger lastColorInt = 0;
    
    data = [[NSMutableArray alloc] initWithCapacity:num];
    
    for(NSInteger i = 0; i < num; ++i) {
        UIColor *color;
        NSInteger colorInt = 0;
        lastPos = lastPos + [self randFrom:minSep to:maxSep];
        
        // Make sure same color doesn't appear twice in a row
        do {
            colorInt = [self randFrom:1 to:9];
        } while (colorInt == lastColorInt);
        
        lastColorInt = colorInt;
        
        switch (colorInt) {
            case 1: color = [UIColor redColor]; break;
            case 2: color = [UIColor blackColor]; break;
            case 3: color = [UIColor yellowColor]; break;
            case 4: color = [UIColor orangeColor]; break;
            case 5: color = [UIColor greenColor]; break;
            case 6: color = [UIColor purpleColor]; break;
            case 7: color = [UIColor brownColor]; break;
            case 8: color = [UIColor blueColor]; break;
            case 9: color = [UIColor magentaColor]; break;
        }
        
        [data addObject:@{
            @"rect":NSStringFromCGRect(CGRectMake(0.f, (CGFloat)lastPos, 128.f, 128.f)),
            @"color":color,
            @"num":@(i)}];
    }
    
    // Can go in the horizontal direction as well
    //_timelineView.direction = TimelineScrollDirectionHorizontal;
    
    [_timelineView registerClass:[SampleTimelineViewCell class] forCellReuseIdentifier:@"SampleTimelineViewCell"];
}

- (CGSize)contentSizeForTimelineView:(TimelineView *)timelineView
{
    NSDictionary *lastObject = [data lastObject];
    NSString *strRect = lastObject[@"rect"];
    CGRect frame = CGRectFromString(strRect);
    
    return CGSizeMake(timelineView.bounds.size.width, CGRectGetMaxY(frame));
}

- (NSInteger)numberOfCellsInTimelineView:(TimelineView *)timelineView
{
    return data.count;
}

- (CGRect)timelineView:(TimelineView *)timelineView cellFrameForIndex:(NSInteger)index
{
    return CGRectFromString([[data objectAtIndex:index] objectForKey:@"rect"]);
}

- (TimelineViewCell *)timelineView:(TimelineView *)timelineView cellForIndex:(NSInteger)index
{
    SampleTimelineViewCell *cell = (SampleTimelineViewCell*)[timelineView dequeueReuseableViewWithIdentifier:@"SampleTimelineViewCell" forIndex:index];
    NSDictionary *info = [data objectAtIndex:index];
    
    cell.color = info[@"color"];
    cell.label.text = [NSString stringWithFormat:@"%@", info[@"num"]];
    
    return cell;
}

- (BOOL)timelineView:(TimelineView *)timelineView canMoveCellAtIndex:(NSInteger)index
{
    return YES;
}

- (void)timelineView:(TimelineView *)timelineView moveCellAtIndex:(NSInteger)sourceIndex toIndex:(NSInteger)destinationIndex withFrame:(CGRect)frame
{
    NSDictionary *info = [[data objectAtIndex:sourceIndex] mutableCopy];
    
    [data removeObjectAtIndex:sourceIndex];
    [data insertObject:@{@"rect": NSStringFromCGRect(frame), @"color": info[@"color"], @"num": info[@"num"]} atIndex:destinationIndex];
}

@end
