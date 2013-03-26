//
//  Copyright (c) 2013 Luke Scott
//  https://github.com/lukescott/TimelineView
//  Distributed under MIT license
//

#import "TimelineView.h"
#import "TimelineView_Private.h"
#import "TimelineView+Tiling.h"
#import "TimelineView+Discovery.h"
#import "TimelineView+Gestures.h"
#import "TimelineView+Mutation.h"

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
@synthesize animationBlock;

- (void)setupDefaults
{
    cellCount = 0;
    updating = 0;
    batching = 0;
    allowsSelection = YES;
    visibleRange = NSMakeRange(0, 0);
    recycledCells = [[NSMutableSet alloc] init];
    visibleCells = [[NSMutableSet alloc] init];
    registeredPrototypes = [[NSMutableDictionary alloc] init];
    cacheFrameLookup = [[NSMutableDictionary alloc] init];
    indexesToDelete = [[NSMutableIndexSet alloc] init];
    indexesToInsert = [[NSMutableIndexSet alloc] init];
    indexesToMove = [[NSMutableDictionary alloc] init];
    [self setupGestures];
}

#pragma mark Initialization
#pragma mark -

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

#pragma mark Properties
#pragma mark -

- (void)setDelegate:(id<TimelineViewDelegate,UIScrollViewDelegate>)value
{
    delegate = value;
    [super setDelegate:value];
}

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
        NSInteger firstIndex = [selectedIndexes firstIndex];
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

- (TimelineViewAnimationBlock)animationBlock
{
    if(!animationBlock) {
        animationBlock = [self defaultAnimationBlock];
    }
    return animationBlock;
}

#pragma mark Creating Cells
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

#pragma mark Reloading Content
#pragma mark -

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

#pragma mark State of TimelineView
#pragma mark -

- (NSArray *)visibleCells
{
    return [visibleCells allObjects];
}

#pragma mark Inserting, Moving, and Deleting Items
#pragma mark -

- (NSInteger)indexForInsertingFrame:(CGRect)frame
{
    CGRect minFrame = frame;
    NSRange range;
    NSInteger index = 0;
    
    if(scrollDirection == TimelineViewScrollDirectionVertical) {
        minFrame.size.height = 1;
    }
    else {
        minFrame.size.width = 1;
    }
    
    range = [self findRangeInRect:minFrame];
    
    if(range.location != NSNotFound) {
        index = range.location + 1;
    }
    
    return index;
}

- (void)insertItemAtIndex:(NSInteger)index
{
    [self insertItemsAtIndexSet:[NSIndexSet indexSetWithIndex:index]];
}

- (void)insertItemsAtIndexSet:(NSIndexSet *)indexSet
{
    if(batching > 0) {
        [indexesToInsert addIndexes:indexSet];
    }
    else {
        [self updateCells:^{
            [indexesToInsert addIndexes:indexSet];
        } completion:nil];
    }
}

- (void)deleteItemAtIndex:(NSInteger)index
{
    [self deleteItemsAtIndexSet:[NSIndexSet indexSetWithIndex:index]];
}

- (void)deleteItemsAtIndexSet:(NSIndexSet *)indexSet
{
    if(batching > 0) {
        [indexesToDelete addIndexes:indexSet];
    }
    else {
        [self updateCells:^{
            [indexesToDelete addIndexes:indexSet];
        } completion:nil];
    }
}

- (void)moveItemAtIndex:(NSInteger)index toIndex:(NSInteger)newIndex
{
    NSArray *existingKeys = [indexesToMove allKeysForObject:@(newIndex)];
    
    if(existingKeys.count > 0 && ! [existingKeys containsObject:@(index)]) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:[NSString stringWithFormat:@"attempt to move items at indexes %@ and %d to same index %d",
                                               [existingKeys lastObject], index, newIndex]
                                     userInfo:nil];
    }
    
    if(batching > 0) {
        [indexesToMove setObject:@(newIndex) forKey:@(index)];
    }
    else {
        [self updateCells:^{
            [indexesToMove setObject:@(newIndex) forKey:@(index)];
        } completion:nil];
    }
}

- (void)performBatchUpdates:(void (^)(void))updates completion:(void (^)(BOOL finished))completion
{
    NSMutableIndexSet *pIndexesToDelete = indexesToDelete;
    NSMutableIndexSet *pIndexesToInsert = indexesToInsert;
    NSMutableDictionary *pIndexesToMove = indexesToMove;
    
    ++batching;
    indexesToDelete = [[NSMutableIndexSet alloc] init];
    indexesToInsert = [[NSMutableIndexSet alloc] init];
    indexesToMove = [[NSMutableDictionary alloc] init];
    
    [self updateCells:^{
        if(updates) updates();
    } completion:^(BOOL finished) {
        if(completion) completion(finished);
    }];
    
    indexesToDelete = pIndexesToDelete;
    indexesToInsert = pIndexesToInsert;
    indexesToMove = pIndexesToMove;
    --batching;
}

#pragma mark Managing the Selection
#pragma mark -

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

#pragma mark Locating Items in Timeline View
#pragma mark -

- (NSInteger)indexForSelectedItem
{
    return [selectedIndexes firstIndex];
}

- (NSInteger)indexForItemAtPoint:(CGPoint)point
{
    NSInteger index = NSNotFound;
    
    if(CGRectContainsPoint(self.bounds, point)) {
        TimelineViewCell *cell = [self cellAtPoint:point];
        if(cell) {
            index = cell.index;
        }
    }
    else {
        NSRange range = [self findRangeInRect:CGRectMake(point.x, point.y, 1, 1)];
        if(range.length > 0) {
            index = range.location;
        }
    }
    
    return index;
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
    return [NSIndexSet indexSetWithIndexesInRange:visibleRange];
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

#pragma mark Scrolling an Item Into View
#pragma mark -

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
