//
//  Copyright (c) 2013 Luke Scott
//  https://github.com/lukescott/TimelineView
//  Distributed under MIT license
//

#define FRAME_CACHE_SIZE 256

#import "TimelineView.h"

typedef enum {
    _TouchModeNone,
    _TouchModeSelect,
    _TouchModeDrag
} _TouchMode;

typedef enum {
    _ScrollingDirectionForward,
    _ScrollingDirectionBackward
} _ScrollingDirection;

#ifndef CGGEOMETRY_LXSUPPORT_H_
CG_INLINE CGPoint
CGPointAdd_(CGPoint p1, CGPoint p2) {
    return CGPointMake(p1.x + p2.x, p1.y + p2.y);
}
CG_INLINE CGPoint
CGPointSubtract_(CGPoint p1, CGPoint p2) {
    return CGPointMake(p1.x - p2.x, p1.y - p2.y);
}
#endif

@interface TimelineView ()
{
    NSMutableSet *visibleCells;
    NSMutableSet *recycledCells;
    NSMutableDictionary *registeredClasses;
    NSInteger cellCount;
    NSRange visibleRange;
    NSMutableDictionary *cacheFrameLookup;
    
    NSMutableSet *selectedIndexes;
    TimelineViewCell *touchedCell;
    _TouchMode touchMode;
    CGPoint lastPoint;
    NSTimer *scrollingTimer;
    BOOL reordering;
}
@end

@interface TimelineViewCell ()
@property (assign, nonatomic) NSInteger index;
@end

@implementation TimelineView
@synthesize dataSource;
@synthesize delegate;
@synthesize direction;
@synthesize tapGestureRecognizer;
@synthesize longPressGestureRecognizer;
@synthesize allowsMultipleSelection;
@synthesize scrollingEdgeInsets;
@synthesize scrollingSpeed;
@synthesize scrollingSpeedScaled;

#pragma mark Initialization
#pragma mark -

- (void)setupDefaults
{
    recycledCells = [[NSMutableSet alloc] init];
    visibleCells = [[NSMutableSet alloc] init];
    registeredClasses = [[NSMutableDictionary alloc] init];
    cacheFrameLookup = [[NSMutableDictionary alloc] initWithCapacity:FRAME_CACHE_SIZE];
    selectedIndexes = [[NSMutableSet alloc] init];
    
    tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGestureRecognizer:)];
    longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPressGestureRecognizer:)];
    
    scrollingEdgeInsets = UIEdgeInsetsMake(50.0f, 50.0f, 50.0f, 50.0f);
    scrollingSpeed = 1200.f;
    scrollingSpeedScaled = YES;
    
    [self addGestureRecognizer:tapGestureRecognizer];
    [self addGestureRecognizer:longPressGestureRecognizer];
}

- (id)init
{
    self = [super init];
    if(self) {
        [self setupDefaults];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if(self) {
        [self setupDefaults];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if(self) {
        [self setupDefaults];
    }
    return self;
}

#pragma mark Public
#pragma mark -

- (void)registerClass:(Class)cellClass forCellReuseIdentifier:(NSString *)identifier
{
    [registeredClasses setObject:cellClass forKey:identifier];
}

- (TimelineViewCell *)dequeueReuseableViewWithIdentifier:(NSString *)identifier forIndex:(NSInteger)index
{
    TimelineViewCell *dequeuedCell;
    
    for(TimelineViewCell *cell in recycledCells) {
        if([cell.reuseIdentifier isEqualToString:identifier]) {
            dequeuedCell = cell;
            [recycledCells removeObject:dequeuedCell];
            [dequeuedCell prepareForReuse];
            break;
        }
    }
    if(!dequeuedCell) {
        dequeuedCell = [[registeredClasses[identifier] alloc] initWithReuseIdentifier:identifier];
    }
    
    return dequeuedCell;
}

- (void)reloadData
{
    for(TimelineViewCell *cell in visibleCells) {
        [recycledCells addObject:cell];
        [cell removeFromSuperview];
    }
    [visibleCells minusSet:recycledCells];
    [cacheFrameLookup removeAllObjects];
    
    if(dataSource) {
        cellCount = [dataSource numberOfCellsInTimelineView:self];
        self.contentSize = [dataSource contentSizeForTimelineView:self];
    }
    
    [self tileCells];
}

#pragma mark Internal Lookup
#pragma mark -

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

- (TimelineViewCell *)cellAtPoint:(CGPoint)point
{
    TimelineViewCell *cell;
    for(UIView *subview in self.subviews.reverseObjectEnumerator) {
        if(CGRectContainsPoint(subview.frame, point) && [visibleCells member:subview]) {
            cell = (TimelineViewCell *)subview;
            break;
        }
    }
    return cell;
}

- (CGRect)frameForCellAtIndex:(NSInteger)index
{
    NSValue *rectVal = [cacheFrameLookup objectForKey:@(index)];
    CGRect rect;
    if(rectVal) {
        rect = [rectVal CGRectValue];
    }
    else {
        rect = [dataSource timelineView:self cellFrameForIndex:index];
        [cacheFrameLookup setObject:[NSValue valueWithCGRect:rect] forKey:@(index)];
    }
    
    return rect;
}

#pragma mark Cell placement
#pragma mark -

- (void)setDirection:(TimelineScrollDirection)newDirection
{
    direction = newDirection;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if(reordering) {
        return;
    }
    if(CGSizeEqualToSize(self.contentSize, CGSizeZero)) {
        [self reloadData];
    }
    else {
        [self tileCells];
    }
}

- (NSRange)findRangeForCellCount:(NSInteger)count inBounds:(CGRect)bounds withContentSize:(CGSize)contentSize
{
    if(direction == TimelineScrollDirectionVertical) {
        return [self verticalRangeForCellCount:count
                                      inBounds:bounds
                               withContentSize:contentSize];
    }
    else {
        return [self horizontalRangeForCellCount:count
                                        inBounds:bounds
                                 withContentSize:contentSize];
    }
}

- (NSRange)verticalRangeForCellCount:(NSInteger)count inBounds:(CGRect)bounds withContentSize:(CGSize)contentSize
{
    CGFloat minY = CGRectGetMinY(bounds);
    CGFloat maxY = CGRectGetMaxY(bounds);
    NSInteger estIndex = (NSInteger)(floor((double)count * ((double)minY / (double)contentSize.height)) / 2) * 2;
    NSInteger minIndex = NSNotFound;
    NSInteger startIndex = NSNotFound;
    NSInteger endIndex = 0;
    
    estIndex = MIN(count - 1, estIndex);
    estIndex = MAX(0, estIndex);
    
    for(NSInteger i = estIndex; i >= 0; i-=2) {
        CGRect cellFrame = [self frameForCellAtIndex:i];
        if(CGRectGetMinY(cellFrame) > maxY) {
            continue;
        }
        
        minIndex = i;
        estIndex = i;
        
        if(CGRectGetMaxY(cellFrame) < minY) {
            break;
        }
    }
    
    for(NSInteger i = estIndex; i < count; ++i) {
        CGRect cellFrame = [self frameForCellAtIndex:i];
        if(CGRectGetMaxY(cellFrame) < minY) {
            minIndex = i;
            continue;
        }
        if(CGRectGetMinY(cellFrame) > maxY) {
            break;
        }
        startIndex = MIN(startIndex, i);
        endIndex = MAX(endIndex, i);
    }
    
    if(startIndex == NSNotFound) {
        return (NSRange){minIndex, 0};
    }
    
    return (NSRange){startIndex, endIndex - startIndex + 1};
}

- (NSRange)horizontalRangeForCellCount:(NSInteger)count inBounds:(CGRect)bounds withContentSize:(CGSize)contentSize
{
    CGFloat minX = CGRectGetMinY(bounds);
    CGFloat maxX = CGRectGetMaxY(bounds);
    NSInteger estIndex = (NSInteger)(floor((double)count * ((double)minX / (double)contentSize.width)) / 2) * 2;
    NSInteger minIndex = NSNotFound;
    NSInteger startIndex = NSNotFound;
    NSInteger endIndex = 0;
    
    estIndex = MIN(count - 1, estIndex);
    estIndex = MAX(0, estIndex);
    
    for(NSInteger i = estIndex; i >= 0; i-=2) {
        CGRect cellFrame = [self frameForCellAtIndex:i];
        if(CGRectGetMinX(cellFrame) > maxX) {
            continue;
        }
        
        minIndex = i;
        estIndex = i;
        
        if(CGRectGetMaxX(cellFrame) < minX) {
            break;
        }
    }
    
    for(NSInteger i = estIndex; i < count; ++i) {
        CGRect cellFrame = [self frameForCellAtIndex:i];
        if(CGRectGetMaxX(cellFrame) < minX) {
            minIndex = i;
            continue;
        }
        if(CGRectGetMinX(cellFrame) > maxX) {
            break;
        }
        startIndex = MIN(startIndex, i);
        endIndex = MAX(endIndex, i);
    }
    
    if(startIndex == NSNotFound) {
        return (NSRange){minIndex, 0};
    }
    
    return (NSRange){startIndex, endIndex - startIndex + 1};
}

- (void)tileCells
{
    NSRange currentRange;
    NSInteger startIndex = NSNotFound;
    NSInteger endIndex = 0;
    
    if(cacheFrameLookup.count >= FRAME_CACHE_SIZE) {
        [cacheFrameLookup removeAllObjects];
    }
    
    currentRange = [self findRangeForCellCount:cellCount
                                      inBounds:self.bounds
                               withContentSize:self.contentSize];
    
    if(currentRange.length > 0) {
        startIndex = currentRange.location;
        endIndex = currentRange.location + currentRange.length - 1;
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
    
    if (startIndex == NSNotFound) {
        return;
    }
    
    for(NSInteger index = startIndex; index <= endIndex; ++index) {
        if (![self isDisplayingCellForIndex:index]) {
            if (touchMode == _TouchModeDrag && touchedCell.index == index) {
                continue;
            }
            
            CGRect cellFrame = [self frameForCellAtIndex:index];
            TimelineViewCell *cell = [dataSource timelineView:self cellForIndex:index];
            
            cell.frame = cellFrame;
            cell.index = index;
            
            if([selectedIndexes member:@(index)]) {
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
}

#pragma mark Gestures
#pragma mark -

- (void)handleTapGestureRecognizer:(UITapGestureRecognizer *)gestureRecognizer
{
    CGPoint point = [gestureRecognizer locationInView:self];;
    TimelineViewCell *cell = [self cellAtPoint:point];
    
    if(cell) {
        [self startSelectingCell:cell];
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
    if([delegate respondsToSelector:@selector(timelineView:shouldHighlightCellAtIndex:)] &&
       [delegate timelineView:self shouldHighlightCellAtIndex:cell.index] == NO)
    {
        return NO;
    }
    
    cell.highlighted = YES;
    [self bringSubviewToFront:cell];
    
    if([delegate respondsToSelector:@selector(timelineView:didHighlightCellAtIndex:)]) {
        [delegate timelineView:self didHighlightCellAtIndex:cell.index];
    }
    
    if(allowsMultipleSelection == NO) {
        for(TimelineViewCell *otherCell in visibleCells) {
            if(otherCell != cell && [selectedIndexes member:@(otherCell.index)]) {
                otherCell.selected = NO;
            }
        }
        [selectedIndexes intersectSet:[NSSet setWithObject:cell]];
    }
    
    return YES;
}

- (void)cancelSelectingCell:(TimelineViewCell *)cell
{
    cell.highlighted = NO;
    
    if([delegate respondsToSelector:@selector(timelineView:didUnhighlightCellAtIndex:)]) {
        [delegate timelineView:self didUnhighlightCellAtIndex:cell.index];
    }
}

- (void)finishSelectingCell:(TimelineViewCell *)cell
{
    NSInteger cellIndex = cell.index;
    
    cell.highlighted = NO;
    
    if([delegate respondsToSelector:@selector(timelineView:didUnhighlightCellAtIndex:)]) {
        [delegate timelineView:self didUnhighlightCellAtIndex:cellIndex];
    }
    
    if(! allowsMultipleSelection || ! [selectedIndexes member:@(cellIndex)]) {
        if([delegate respondsToSelector:@selector(timelineView:willSelectCellAtIndex:)]) {
            [delegate timelineView:self willSelectCellAtIndex:cellIndex];
        }
        
        cell.selected = YES;
        [selectedIndexes addObject:@(cellIndex)];
        
        if([delegate respondsToSelector:@selector(timelineView:didSelectCellAtIndex:)]) {
            [delegate timelineView:self didSelectCellAtIndex:cellIndex];
        }
    }
    else if([delegate respondsToSelector:@selector(timelineView:shouldDeselectCellAtIndex:)] == NO ||
            [delegate timelineView:self shouldDeselectCellAtIndex:cellIndex] == YES)
    {
        if([delegate respondsToSelector:@selector(timelineView:willDeselectCellAtIndex:)]) {
            [delegate timelineView:self willDeselectCellAtIndex:cellIndex];
        }
        
        cell.selected = NO;
        [selectedIndexes removeObject:@(cellIndex)];
        
        if([delegate respondsToSelector:@selector(timelineView:didDeselectCellAtIndex:)]) {
            [delegate timelineView:self didDeselectCellAtIndex:cellIndex];
        }
    }
}

#pragma mark Drag & Drop
#pragma mark -

- (BOOL)canDragCell:(TimelineViewCell *)cell
{
    return [dataSource respondsToSelector:@selector(timelineView:canMoveCellAtIndex:)] &&
           [dataSource timelineView:self canMoveCellAtIndex:cell.index];
}

- (void)startDraggingCell:(TimelineViewCell *)cell
{
    cell.dragging = YES;
    [self bringSubviewToFront:cell];
}

- (void)dragCell:(TimelineViewCell *)cell distance:(CGPoint)distance
{
    if(direction == TimelineScrollDirectionVertical) {
        distance.x = 0;
    }
    else {
        distance.y = 0;
    }
    
    cell.center = CGPointAdd_(cell.center, distance);
    
    if(direction == TimelineScrollDirectionVertical) {
        if(CGRectGetMaxY(cell.frame) > CGRectGetMaxY(self.bounds) - scrollingEdgeInsets.top) {
            [self setupScrollTimerInDirection:_ScrollingDirectionForward];
        }
        else if(CGRectGetMinY(cell.frame) < CGRectGetMinY(self.bounds) + scrollingEdgeInsets.bottom) {
            [self setupScrollTimerInDirection:_ScrollingDirectionBackward];
        }
        else {
            [self invalidateScrollTimer];
        }
    }
    else {
        if(CGRectGetMaxX(cell.frame) > CGRectGetMaxX(self.bounds) - scrollingEdgeInsets.left) {
            [self setupScrollTimerInDirection:_ScrollingDirectionForward];
        }
        else if(CGRectGetMinX(cell.frame) < CGRectGetMinX(self.bounds) + scrollingEdgeInsets.right) {
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
    
    reordering = YES;
    [self invalidateScrollTimer];
    cell.dragging = NO;
    
    range = [self findRangeForCellCount:cellCount
                               inBounds:cell.frame
                        withContentSize:self.contentSize];
    
    oldIndex = cell.index;
    newIndex = range.location;
    
    if(newIndex == NSNotFound) {
        newIndex = 0;
    }
    else if(newIndex < oldIndex) {
        ++newIndex;
    }
    
    if([dataSource respondsToSelector:@selector(timelineView:moveCellAtIndex:toIndex:withFrame:)]) {
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
        
        [dataSource timelineView:self moveCellAtIndex:oldIndex toIndex:newIndex withFrame:cell.frame];
    }
    
//    for (TimelineViewCell *otherCell in visibleCells) {
//        NSLog(@"%d", otherCell.index);
//    }
    
    reordering = NO;
    [cacheFrameLookup removeAllObjects];
    [self tileCells];
}

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
    
    if(direction == TimelineScrollDirectionVertical) {
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
