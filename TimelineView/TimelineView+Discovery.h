//
//  Copyright (c) 2013 Luke Scott
//  https://github.com/lukescott/TimelineView
//  Distributed under MIT license
//

#import "TimelineView.h"

@interface TimelineView (Discovery)

- (CGRect)frameForItemAtIndex:(NSInteger)index;
- (NSRange)findRangeInRect:(CGRect)rect;

@end
