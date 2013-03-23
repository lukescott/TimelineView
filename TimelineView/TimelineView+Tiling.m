//
//  Copyright (c) 2013 Luke Scott
//  https://github.com/lukescott/TimelineView
//  Distributed under MIT license
//

#import "TimelineView+Tiling.h"
#import "TimelineView_Private.h"
#import "TimelineView+Discovery.h"

@implementation TimelineView (Tiling)

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if(updating > 0) {
        return;
    }
    if(CGSizeEqualToSize(self.contentSize, CGSizeZero)) {
        [self reloadData];
    }
    else {
        [self tileCells];
    }
}

- (BOOL)isDisplayingCellForIndex:(NSInteger)index
{
    BOOL found = NO;
    for(TimelineViewCell *cell in visibleCells) {
        if(cell.index == index) {
            found = YES;
            break;
        }
    }
    return found;
}

- (void)tileCells
{
    NSRange range;
    NSInteger startIndex = NSNotFound;
    NSInteger endIndex = 0;
    
    range = [self findRangeInRect:self.bounds];
    
    if(range.length > 0) {
        startIndex = range.location;
        endIndex = range.location + range.length - 1;
    }
    
    for(TimelineViewCell *cell in visibleCells) {
        NSInteger cellIndex = cell.index;
        
        if (touchMode == _TouchModeDrag && touchedCell == cell) {
            continue;
        }
        
        if(cellIndex < startIndex || cellIndex > endIndex) {
            [cell removeFromSuperview];
            [cacheFrameLookup removeObjectForKey:@(cellIndex)];
            if([delegate respondsToSelector:@selector(timelineView:didEndDisplayingCell:atIndex:)]) {
                [delegate timelineView:self didEndDisplayingCell:cell atIndex:cellIndex];
            }
            [recycledCells addObject:cell];
        }
    }
    [visibleCells minusSet:recycledCells];
    
    if(startIndex == NSNotFound) {
        return;
    }
    
    for(NSInteger index = startIndex; index <= endIndex; ++index) {
        if (![self isDisplayingCellForIndex:index]) {
            if (touchMode == _TouchModeDrag && touchedCell.index == index) {
                continue;
            }
            
            CGRect cellFrame = [self frameForItemAtIndex:index];
            TimelineViewCell *cell = [dataSource timelineView:self cellForIndex:index];
            
            cell.frame = cellFrame;
            cell.index = index;
            
            if([selectedIndexes containsIndex:index]) {
                cell.selected = YES;
            }
            
            if(cell != nil) {
                if([delegate respondsToSelector:@selector(timelineView:willDisplayCell:atIndex:)]) {
                    [delegate timelineView:self willDisplayCell:cell atIndex:index];
                }
                [visibleCells addObject:cell];
                [self insertSubview:cell atIndex:0];
            }
        }
    }
    
    visibleRange = range;
}

@end
