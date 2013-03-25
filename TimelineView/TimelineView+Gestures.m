//
//  Copyright (c) 2013 Luke Scott
//  https://github.com/lukescott/TimelineView
//  Distributed under MIT license
//

#import "TimelineView+Gestures.h"
#import "TimelineView_Private.h"
#import "TimelineView+Discovery.h"

@implementation TimelineView (Gestures)

- (void)setupGestures
{
    selectedIndexes = [[NSMutableIndexSet alloc] init];
    scrollingEdgeInsets = UIEdgeInsetsMake(50.0f, 50.0f, 50.0f, 50.0f);
    scrollingSpeed = 1200.f;
    scrollingSpeedScaled = YES;
    
    tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGestureRecognizer:)];
    longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPressGestureRecognizer:)];
    
    [self addGestureRecognizer:tapGestureRecognizer];
    [self addGestureRecognizer:longPressGestureRecognizer];
}

#pragma mark Gestures
#pragma mark -

- (void)handleTapGestureRecognizer:(UITapGestureRecognizer *)gestureRecognizer
{
    CGPoint point = [gestureRecognizer locationInView:self];;
    TimelineViewCell *cell = [self cellAtPoint:point];
    
    if(cell && [self startSelectingCell:cell]) {
        [self finishSelectingCell:cell];
    }
}

- (void)handleLongPressGestureRecognizer:(UILongPressGestureRecognizer *)gestureRecognizer
{
    CGPoint point = [gestureRecognizer locationInView:self];
    TimelineViewCell *cell = [self cellAtPoint:point];
    
    switch (gestureRecognizer.state) {
        case UIGestureRecognizerStateBegan:
            if(cell) {
                if([self canDragCell:cell]) {
                    touchMode = _TouchModeDrag;
                    touchedCell = cell;
                    [self startDraggingCell:cell];
                }
                else if([self startSelectingCell:cell]) {
                    touchMode = _TouchModeSelect;
                    touchedCell = cell;
                }
            }
            break;
        case UIGestureRecognizerStateChanged:
            switch (touchMode) {
                case _TouchModeDrag:
                    [self dragCell:touchedCell distance:CGPointSubtract_(point, lastPoint)];
                    break;
                case _TouchModeSelect:
                    if(cell != touchedCell) {
                        [self cancelSelectingCell:touchedCell];
                        touchMode = _TouchModeNone;
                        touchedCell = nil;
                    }
                    break;
                default: break;
            }
            break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
            switch (touchMode) {
                case _TouchModeSelect:
                    [self finishSelectingCell:touchedCell];
                    break;
                case _TouchModeDrag:
                    [self finishDraggingCell:touchedCell];
                    break;
                default: break;
            }
            touchMode = _TouchModeNone;
            touchedCell = nil;
            break;
        default: break;
    }
    
    lastPoint = point;
}

#pragma mark Highlight / Select
#pragma mark -

- (BOOL)startSelectingCell:(TimelineViewCell *)cell
{
    if(!allowsSelection) {
        return NO;
    }
    
    if([delegate respondsToSelector:@selector(timelineView:shouldHighlightItemAtIndex:)] &&
       [delegate timelineView:self shouldHighlightItemAtIndex:cell.index] == NO)
    {
        return NO;
    }
    
    cell.highlighted = YES;
    [self bringSubviewToFront:cell];
    
    if([delegate respondsToSelector:@selector(timelineView:didHighlightItemAtIndex:)]) {
        [delegate timelineView:self didHighlightItemAtIndex:cell.index];
    }
    
    if(allowsMultipleSelection == NO) {
        for(TimelineViewCell *otherCell in visibleCells) {
            if(otherCell != cell && [selectedIndexes containsIndex:otherCell.index]) {
                otherCell.selected = NO;
            }
        }
    }
    
    return YES;
}

- (void)cancelSelectingCell:(TimelineViewCell *)cell
{
    cell.highlighted = NO;
    
    if([delegate respondsToSelector:@selector(timelineView:didUnhighlightItemAtIndex:)]) {
        [delegate timelineView:self didUnhighlightItemAtIndex:cell.index];
    }
}

- (void)finishSelectingCell:(TimelineViewCell *)cell
{
    NSInteger cellIndex = cell.index;
    
    cell.highlighted = NO;
    
    if([delegate respondsToSelector:@selector(timelineView:didUnhighlightItemAtIndex:)]) {
        [delegate timelineView:self didUnhighlightItemAtIndex:cellIndex];
    }
    
    if(! allowsMultipleSelection) {
        [selectedIndexes removeAllIndexes];
    }
    
    if(! allowsMultipleSelection || ! [selectedIndexes containsIndex:cellIndex]) {
        if([delegate respondsToSelector:@selector(timelineView:willSelectItemAtIndex:)]) {
            [delegate timelineView:self willSelectItemAtIndex:cellIndex];
        }
        
        cell.selected = YES;
        [selectedIndexes addIndex:cellIndex];
        
        if([delegate respondsToSelector:@selector(timelineView:didSelectItemAtIndex:)]) {
            [delegate timelineView:self didSelectItemAtIndex:cellIndex];
        }
    }
    else if([delegate respondsToSelector:@selector(timelineView:shouldDeselectItemAtIndex:)] == NO ||
            [delegate timelineView:self shouldDeselectItemAtIndex:cellIndex] == YES)
    {
        if([delegate respondsToSelector:@selector(timelineView:willDeselectItemAtIndex:)]) {
            [delegate timelineView:self willDeselectItemAtIndex:cellIndex];
        }
        
        cell.selected = NO;
        [selectedIndexes removeIndex:cellIndex];
        
        if([delegate respondsToSelector:@selector(timelineView:didDeselectItemAtIndex:)]) {
            [delegate timelineView:self didDeselectItemAtIndex:cellIndex];
        }
    }
}

#pragma mark Drag & Drop
#pragma mark -

- (BOOL)canDragCell:(TimelineViewCell *)cell
{
    return [dataSource respondsToSelector:@selector(timelineView:canMoveItemAtIndex:)] &&
    [dataSource timelineView:self canMoveItemAtIndex:cell.index];
}

- (void)startDraggingCell:(TimelineViewCell *)cell
{
    cell.dragging = YES;
    [self bringSubviewToFront:cell];
}

- (void)dragCell:(TimelineViewCell *)cell distance:(CGPoint)distance
{
    CGRect visibleBounds = self.bounds;
    
    if(scrollDirection == TimelineViewScrollDirectionVertical) {
        distance.x = 0;
    }
    else {
        distance.y = 0;
    }
    
    cell.center = CGPointAdd_(cell.center, distance);
    
    if(scrollDirection == TimelineViewScrollDirectionVertical) {
        if(CGRectGetMaxY(cell.frame) > CGRectGetMaxY(visibleBounds) - scrollingEdgeInsets.top) {
            [self setupScrollTimerInDirection:_ScrollingDirectionForward];
        }
        else if(CGRectGetMinY(cell.frame) < CGRectGetMinY(visibleBounds) + scrollingEdgeInsets.bottom) {
            [self setupScrollTimerInDirection:_ScrollingDirectionBackward];
        }
        else {
            [self invalidateScrollTimer];
        }
    }
    else {
        if(CGRectGetMaxX(cell.frame) > CGRectGetMaxX(visibleBounds) - scrollingEdgeInsets.left) {
            [self setupScrollTimerInDirection:_ScrollingDirectionForward];
        }
        else if(CGRectGetMinX(cell.frame) < CGRectGetMinX(visibleBounds) + scrollingEdgeInsets.right) {
            [self setupScrollTimerInDirection:_ScrollingDirectionBackward];
        }
        else {
            [self invalidateScrollTimer];
        }
    }
}

- (void)finishDraggingCell:(TimelineViewCell *)cell
{
    NSInteger oldIndex = 0;
    NSInteger newIndex = 0;
    NSRange range;
    
    ++updating;
    [self invalidateScrollTimer];
    cell.dragging = NO;
    
    range = [self findRangeInRect:cell.frame];
    
    oldIndex = cell.index;
    newIndex = range.location;
    
    if(newIndex == NSNotFound) {
        newIndex = 0;
    }
    else if(newIndex < oldIndex) {
        ++newIndex;
    }
    
    if([dataSource respondsToSelector:@selector(timelineView:moveItemAtIndex:toIndex:withFrame:)]) {
        if(newIndex != oldIndex) {
            [visibleCells removeObject:cell];
            
            for(TimelineViewCell *otherCell in visibleCells) {
                NSInteger otherIndex = otherCell.index;
                if(otherIndex > oldIndex) {
                    otherCell.index = otherIndex - 1;
                }
            }
            for(TimelineViewCell *otherCell in visibleCells) {
                NSInteger otherIndex = otherCell.index;
                if(otherIndex >= newIndex) {
                    otherCell.index = otherIndex + 1;
                }
            }
            
            cell.index = newIndex;
            [visibleCells addObject:cell];
        }
        
        [dataSource timelineView:self moveItemAtIndex:oldIndex toIndex:newIndex withFrame:cell.frame];
    }
    
    --updating;
    [cacheFrameLookup removeAllObjects];
}

#pragma mark Drag & Scroll
#pragma mark -

- (void)invalidateScrollTimer
{
    if(scrollingTimer.isValid) {
        [scrollingTimer invalidate];
    }
    scrollingTimer = nil;
}

- (void)setupScrollTimerInDirection:(_ScrollingDirection)dir
{
    _ScrollingDirection oldDir;
    
    if(scrollingTimer.isValid) {
        oldDir = [scrollingTimer.userInfo[@"scrollDir"] integerValue];
        
        if(dir == oldDir) {
            return;
        }
    }
    
    [self invalidateScrollTimer];
    
    scrollingTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / 60.f
                                                      target:self
                                                    selector:@selector(handleScroll:)
                                                    userInfo:@{@"scrollDir":@(dir)}
                                                     repeats:YES];
}

- (void)handleScroll:(NSTimer *)timer
{
    _ScrollingDirection dir = (_ScrollingDirection)[timer.userInfo[@"scrollDir"] integerValue];
    CGFloat scrollingDistance = scrollingSpeed / 60.f;
    CGSize size = self.bounds.size;
    CGSize contentSize = self.contentSize;
    CGPoint currentOffset = self.contentOffset;
    CGPoint contentOffset = currentOffset;
    CGPoint distance;
    
    if(scrollDirection == TimelineViewScrollDirectionVertical) {
        if(dir == _ScrollingDirectionBackward) {
            contentOffset.y = MAX(0, currentOffset.y - scrollingDistance);
        }
        else {
            contentOffset.y = MIN(contentSize.height - size.height, currentOffset.y + scrollingDistance);
        }
    }
    else {
        if(dir == _ScrollingDirectionBackward) {
            contentOffset.x = MAX(0, currentOffset.x - scrollingDistance);
        }
        else {
            contentOffset.x = MIN(contentSize.width - size.width, currentOffset.x + scrollingDistance);
        }
    }
    
    distance = CGPointSubtract_(contentOffset, self.contentOffset);
    self.contentOffset = contentOffset;
    lastPoint = CGPointAdd_(lastPoint, distance);
    touchedCell.center = CGPointAdd_(touchedCell.center, distance);
}

@end
