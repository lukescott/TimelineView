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
    NSMutableDictionary *registeredPrototypes;
    NSMutableDictionary *cacheFrameLookup;
    NSInteger cellCount;
    NSMutableSet *visibleCells;
    NSMutableSet *recycledCells;
    NSMutableIndexSet *selectedIndexes;
    TimelineViewCell *touchedCell;
    _TouchMode touchMode;
    CGPoint lastPoint;
    NSTimer *scrollingTimer;
    NSMutableSet *batchDelete;
    NSMutableSet *batchInsert;
    BOOL batching;
    BOOL updating;
    
    NSInteger maxOld;
    NSInteger maxNew;
}
@end

@interface TimelineViewCell ()
@property (strong, nonatomic) NSString *reuseIdentifier;
@property (assign, nonatomic) NSInteger index;
@end

@implementation TimelineView
@synthesize dataSource;
@synthesize delegate;
@synthesize tapGestureRecognizer;
@synthesize longPressGestureRecognizer;
@synthesize scrollDirection;
@synthesize allowsSelection;
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
    registeredPrototypes = [[NSMutableDictionary alloc] init];
    cacheFrameLookup = [[NSMutableDictionary alloc] initWithCapacity:FRAME_CACHE_SIZE];
    selectedIndexes = [[NSMutableIndexSet alloc] init];
    
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

- (void)registerClass:(Class)cellClass forCellWithReuseIdentifier:(NSString *)identifier
{
    [registeredPrototypes setObject:cellClass forKey:identifier];
}

- (void)registerNib:(UINib *)nib forCellWithReuseIdentifier:(NSString *)identifier
{
    [registeredPrototypes setObject:nib forKey:identifier];
}

- (TimelineViewCell *)dequeueReusableCellWithReuseIdentifier:(NSString *)identifier forIndex:(NSInteger)index
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
        id prototype = registeredPrototypes[identifier];
        if([prototype isKindOfClass:[UINib class]]) {
            NSArray *objects = [(UINib *)prototype instantiateWithOwner:nil options:nil];
            dequeuedCell = [objects lastObject];
            
            if(objects.count != 1 || ! [dequeuedCell isKindOfClass:[TimelineViewCell class]]) {
                @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                               reason:[NSString stringWithFormat:@"invalid nib registered for identifier (%@) - nib must contain exactly one top level object which must be a TimelineViewCell instance", identifier]
                                             userInfo:nil];
            }
            
            dequeuedCell.reuseIdentifier = identifier;
        }
        else {
            dequeuedCell = [[prototype alloc] initWithReuseIdentifier:identifier];
        }
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

- (CGRect)frameForItemAtIndex:(NSInteger)index
{
    NSValue *rectVal = [cacheFrameLookup objectForKey:@(index)];
    CGRect rect;
    if(rectVal) {
        rect = [rectVal CGRectValue];
    }
    else {
        rect = [dataSource timelineView:self frameForCellAtIndex:index];
        [cacheFrameLookup setObject:[NSValue valueWithCGRect:rect] forKey:@(index)];
    }
    return rect;
}

#pragma mark Cell placement
#pragma mark -

- (void)setScrollDirection:(TimelineViewScrollDirection)newDirection
{
    scrollDirection = newDirection;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if(updating) {
        return;
    }
    if(CGSizeEqualToSize(self.contentSize, CGSizeZero)) {
        [self reloadData];
    }
    else {
        [self tileCells];
    }
}

- (NSRange)findRangeInRect:(CGRect)rect
{
    if(scrollDirection == TimelineViewScrollDirectionVertical) {
        return [self verticalRangeInRect:rect];
    }
    else {
        return [self horizontalRangeInRect:rect];
    }
}

- (NSRange)verticalRangeInRect:(CGRect)rect
{
    CGFloat minY = CGRectGetMinY(rect);
    CGFloat maxY = CGRectGetMaxY(rect);
    NSInteger count = cellCount;
    NSRange searchRange = NSMakeRange(0, count);
    NSInteger estIndex = 0; // Nearest index
    NSInteger minIndex = NSNotFound; // Index closest to top
    NSInteger startIndex = NSNotFound; // First visible index
    NSInteger endIndex = 0; // Last visible index
    CGRect cellFrame;
    CGFloat cellMinY;
    
    // Discover closest visible index using binary tree
    for(;;) {
        estIndex = round((searchRange.location * 2 + searchRange.length - 1) / 2);
        cellFrame = [self frameForItemAtIndex:estIndex];
        cellMinY = CGRectGetMinY(cellFrame);
        
        if(CGRectIntersectsRect(cellFrame, rect)) {
            break;
        }
        
        if(cellMinY > minY) {
            searchRange = NSMakeRange(searchRange.location, searchRange.length / 2);
        }
        else if(cellMinY < minY) {
            searchRange = NSMakeRange(estIndex + 1, searchRange.length / 2 - 1);
        }
        
        if(searchRange.length < 2) {
            break;
        }
    }
    
    // Work backward to find starting index
    for(NSInteger i = estIndex; i >= 0; --i) {
        cellFrame = [self frameForItemAtIndex:i];
        
        if(CGRectGetMinY(cellFrame) > maxY) {
            continue;
        }
        
        minIndex = i;
        
        if(CGRectGetMaxY(cellFrame) < minY) {
            break;
        }
        
        startIndex = i;
        endIndex = i;
    }
    
    // Work forward to discover ending index
    for(NSInteger i = estIndex; i < count; ++i) {
        cellFrame = [self frameForItemAtIndex:i];
        
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

- (NSRange)horizontalRangeInRect:(CGRect)rect
{
    CGFloat minX = CGRectGetMinX(rect);
    CGFloat maxX = CGRectGetMaxX(rect);
    NSInteger count = cellCount;
    NSRange searchRange = NSMakeRange(0, count);
    NSInteger estIndex = 0; // Nearest index
    NSInteger minIndex = NSNotFound; // Index closest to top
    NSInteger startIndex = NSNotFound; // First visible index
    NSInteger endIndex = 0; // Last visible index
    CGRect cellFrame;
    CGFloat cellMinX;
    
    // Discover closest visible index using binary tree
    for(;;) {
        estIndex = round((searchRange.location * 2 + searchRange.length - 1) / 2);
        cellFrame = [self frameForItemAtIndex:estIndex];
        cellMinX = CGRectGetMinX(cellFrame);
        
        if(CGRectIntersectsRect(cellFrame, rect)) {
            break;
        }
        
        if(cellMinX > minX) {
            searchRange = NSMakeRange(searchRange.location, searchRange.length / 2);
        }
        else if(cellMinX < minX) {
            searchRange = NSMakeRange(estIndex + 1, searchRange.length / 2 - 1);
        }
        
        if(searchRange.length < 2) {
            break;
        }
    }
    
    // Work backward to find starting index
    for(NSInteger i = estIndex; i >= 0; --i) {
        cellFrame = [self frameForItemAtIndex:i];
        
        if(CGRectGetMinX(cellFrame) > maxX) {
            continue;
        }
        
        minIndex = i;
        
        if(CGRectGetMaxX(cellFrame) < minX) {
            break;
        }
        
        startIndex = i;
        endIndex = i;
    }
    
    // Work forward to discover ending index
    for(NSInteger i = estIndex; i < count; ++i) {
        cellFrame = [self frameForItemAtIndex:i];
        
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
    
    if (startIndex == NSNotFound) {
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

- (void)setAllowsSelection:(BOOL)value
{
    allowsSelection = value;
    
    if(!value && selectedIndexes.count > 0) {
        for(TimelineViewCell *cell in visibleCells) {
            if([selectedIndexes containsIndex:cell.index]) {
                cell.selected = NO;
            }
        }
        [selectedIndexes removeAllIndexes];
    }
}

- (void)setAllowsMultipleSelection:(BOOL)value
{
    allowsMultipleSelection = value;
    
    if(!value && selectedIndexes.count > 1) {
        NSUInteger firstIndex = [selectedIndexes firstIndex];
        for(TimelineViewCell *cell in visibleCells) {
            NSInteger cellIndex = cell.index;
            if(cellIndex != firstIndex && [selectedIndexes containsIndex:cellIndex]) {
                cell.selected = NO;
            }
        }
        [selectedIndexes removeAllIndexes];
        [selectedIndexes addIndex:firstIndex];
    }
}

- (BOOL)startSelectingCell:(TimelineViewCell *)cell
{
    if(allowsSelection) {
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
    if(scrollDirection == TimelineViewScrollDirectionVertical) {
        distance.x = 0;
    }
    else {
        distance.y = 0;
    }
    
    cell.center = CGPointAdd_(cell.center, distance);
    
    if(scrollDirection == TimelineViewScrollDirectionVertical) {
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
    
    updating = YES;
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
    
    updating = NO;
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

- (NSInteger)indexForSelectedItem
{
    return [selectedIndexes firstIndex];
}

- (NSInteger)indexForItemAtPoint:(CGPoint)point
{
    NSRange range = [self findRangeInRect:CGRectMake(point.x, point.y, 1, 1)];
    
    return range.length > 0 ? range.location : NSNotFound;
}

- (NSIndexSet *)indexSetForSelectedItems
{
    return [[NSIndexSet alloc] initWithIndexSet:selectedIndexes];
}

- (NSIndexSet *)indexSetForItemsInRect:(CGRect)rect
{
    NSRange range = [self findRangeInRect:rect];
    
    if(!range.length) {
        return nil;
    }
    
    return [NSIndexSet indexSetWithIndexesInRange:range];
}

- (NSIndexSet *)indexSetForVisibleItems
{
    NSMutableIndexSet *visibleIndexes = [[NSMutableIndexSet alloc] init];
    
    for(TimelineViewCell *cell in visibleCells) {
        [visibleIndexes addIndex:cell.index];
    }
    
    return [[NSIndexSet alloc] initWithIndexSet:visibleIndexes];
}

- (NSArray *)visibleCells
{
    return [visibleCells allObjects];
}

- (TimelineViewCell *)cellForItemAtIndex:(NSInteger)index
{
    TimelineViewCell *cell;
    for(TimelineViewCell *otherCell in visibleCells) {
        if(otherCell.index == index) {
            cell = otherCell;
            break;
        }
    }
    return cell;
}

- (void)selectItemAtIndex:(NSInteger)index
{
    if(!allowsSelection) {
        return;
    }
    for(TimelineViewCell *cell in visibleCells) {
        if(cell.index == index) {
            cell.selected = YES;
        }
        else if (!allowsMultipleSelection) {
            cell.selected = NO;
        }
    }
    if(!allowsMultipleSelection) {
        [selectedIndexes removeAllIndexes];
    }
    [selectedIndexes addIndex:index];
}

- (void)deselectItemAtIndex:(NSInteger)index
{
    if(!allowsSelection) {
        return;
    }
    for(TimelineViewCell *cell in visibleCells) {
        if(cell.index == index) {
            cell.selected = NO;
        }
    }
    [selectedIndexes removeIndex:index];
}

- (void)scrollToItemAtIndex:(NSInteger)index atScrollPosition:(TimelineViewScrollPosition)scrollPosition animated:(BOOL)animated
{
    CGRect cellFrame = [self frameForItemAtIndex:index];
    CGPoint contentOffset = self.contentOffset;
    CGSize size = self.bounds.size;
    
    if(CGRectEqualToRect(cellFrame, CGRectZero)) {
        return;
    }
    
    switch (scrollPosition) {
        case TimelineViewScrollPositionTop:
            if(scrollDirection == TimelineViewScrollDirectionVertical) {
                contentOffset.y = CGRectGetMinY(cellFrame);
            }
            else {
                contentOffset.x = CGRectGetMinX(cellFrame);
            }
            break;
        case TimelineViewScrollPositionCenter:
            if(scrollDirection == TimelineViewScrollDirectionVertical) {
                contentOffset.y = CGRectGetMidY(cellFrame) - roundf(size.height / 2);
            }
            else {
                contentOffset.x = CGRectGetMidX(cellFrame) - roundf(size.width / 2);
            }
            break;
        case TimelineViewScrollPositionBottom:
            if(scrollDirection == TimelineViewScrollDirectionVertical) {
                contentOffset.y = CGRectGetMaxY(cellFrame) - size.height;
            }
            else {
                contentOffset.x = CGRectGetMaxX(cellFrame) - size.width;
            }
            break;
    }
    
    [self setContentOffset:contentOffset animated:animated];
}

@end
