//
//  Copyright (c) 2013 Luke Scott
//  https://github.com/lukescott/TimelineView
//  Distributed under MIT license
//

#import "TimelineView+Mutation.h"
#import "TimelineView_Private.h"

@implementation TimelineView (Mutation)

- (TimelineViewAnimationBlock)defaultAnimationBlock
{
    return ^(NSMapTable *moved, NSSet *deleted, NSSet *inserted) {
        for(TimelineViewCell *cell in moved) {
            cell.frame = [[moved objectForKey:cell] CGRectValue];
        }
        for(TimelineViewCell *cell in deleted) {
            cell.alpha = 0.f;
        }
        for(TimelineViewCell *cell in inserted) {
            cell.alpha = 0.f;
            cell.alpha = 1.f;
        }
    };
}

- (NSSet *)deleteCellsWithIndexSet:(NSIndexSet *)indexSet
{
    NSMutableSet *items = [[NSMutableSet alloc] initWithCapacity:indexSet.count];
    
    for(TimelineViewCell *cell in visibleCells) {
        if([indexSet containsIndex:cell.index]) {
            [items addObject:cell];
        }
    }
    [selectedIndexes removeIndexes:indexSet];
    [visibleCells minusSet:items];
    
    [indexSet enumerateRangesUsingBlock:^(NSRange range, BOOL *stop) {
        for(TimelineViewCell *cell in visibleCells) {
            NSInteger cellIndex = cell.index;
            if(cellIndex >= range.location + range.length) {
                cell.index = cellIndex - range.length;
                [selectedIndexes shiftIndexesStartingAtIndex:cellIndex by:-range.length];
            }
        }
    }];
    
    return [items copy];
}

- (NSMapTable *)moveCellsWithDictionary:(NSDictionary *)dictionary offscreenCells:(NSMutableSet *)offscreenCells
{
    NSMutableDictionary *moveIndexes = [[NSMutableDictionary alloc] initWithDictionary:dictionary];
    NSMapTable *itemMap = [NSMapTable strongToStrongObjectsMapTable];
    CGRect visibleBounds = self.bounds;
    CGFloat minY = CGRectGetMinY(visibleBounds);
    CGFloat minX = CGRectGetMinX(visibleBounds);
    CGFloat maxY = CGRectGetMaxY(visibleBounds);
    CGFloat maxX = CGRectGetMaxX(visibleBounds);
    
    // "Move" visible cells
    for(TimelineViewCell *cell in visibleCells) {
        NSNumber *moveFrom = @(cell.index);
        NSNumber *moveTo = [moveIndexes objectForKey:moveFrom];
        if(moveTo) {
            NSInteger fromIndex = moveFrom.integerValue;
            NSInteger toIndex = moveTo.integerValue;
            CGRect newFrame = [dataSource timelineView:self frameForCellAtIndex:toIndex];
            
            if([selectedIndexes containsIndex:fromIndex] && ! [selectedIndexes containsIndex:toIndex]) {
                [selectedIndexes removeIndex:fromIndex];
                [selectedIndexes addIndex:toIndex];
            }
            
            if(! CGRectIntersectsRect(cell.frame, visibleBounds)) {
                [offscreenCells addObject:cell];
            }
            
            cell.index = toIndex;
            [moveIndexes removeObjectForKey:moveFrom];
            [itemMap setObject:[NSValue valueWithCGRect:newFrame] forKey:cell];
        }
    }
    [visibleCells minusSet:offscreenCells];
    
    // "Move" hidden cells
    for(NSNumber *moveFrom in moveIndexes) {
        TimelineViewCell *cell;
        NSNumber *moveTo = [moveIndexes objectForKey:moveFrom];
        NSInteger fromIndex = moveFrom.integerValue;
        NSInteger toIndex = moveTo.integerValue;
        CGRect newFrame = [dataSource timelineView:self frameForCellAtIndex:toIndex];
        CGRect startFrame = newFrame;
        NSInteger multiplier;
        
        // If selected, move selection
        if([selectedIndexes containsIndex:fromIndex] && ! [selectedIndexes containsIndex:toIndex]) {
            [selectedIndexes removeIndex:fromIndex];
            [selectedIndexes addIndex:toIndex];
        }
        
        if(CGRectIntersectsRect(newFrame, visibleBounds)) {
            cell = [dataSource timelineView:self cellForIndex:toIndex];
            
            // We really don't know the cell's original location, so we fake it...
            if(fromIndex < visibleRange.location) {
                multiplier = MIN(10, visibleRange.location - fromIndex);
                
                if(scrollDirection == TimelineViewScrollDirectionVertical) {
                    startFrame.origin.y = minY - startFrame.size.height * multiplier;
                }
                else {
                    startFrame.origin.x = minX - startFrame.size.width * multiplier;
                }
            }
            else {
                multiplier = MIN(10, fromIndex - visibleRange.location + visibleRange.length - 1);
                
                if(scrollDirection == TimelineViewScrollDirectionVertical) {
                    startFrame.origin.y = maxY + startFrame.size.height * multiplier;
                }
                else {
                    startFrame.origin.x = maxX + startFrame.size.width * multiplier;
                }
            }
            
            cell.frame = startFrame;
            cell.index = toIndex;
            
            if([selectedIndexes containsIndex:fromIndex]) {
                cell.selected = YES;
            }
            
            [self addSubview:cell];
            [visibleCells addObject:cell];
            [itemMap setObject:[NSValue valueWithCGRect:newFrame] forKey:cell];
        }
    }
    
    return itemMap;
}

- (NSSet *)insertCellsWithIndexSet:(NSIndexSet *)indexSet
{
    NSMutableSet *items = [[NSMutableSet alloc] initWithCapacity:indexSet.count];
    CGRect visibleBounds = self.bounds;
    
    [indexSet enumerateRangesUsingBlock:^(NSRange range, BOOL *stop) {
        NSInteger lastIndex = range.location + range.length - 1;
        
        for(TimelineViewCell *cell in visibleCells) {
            NSInteger cellIndex = cell.index;
            if(cellIndex >= range.location) {
                cell.index = cellIndex + range.length;
                [selectedIndexes shiftIndexesStartingAtIndex:cellIndex by:range.length];
            }
        }
        
        for(NSInteger index = range.location; index <= lastIndex; ++index) {
            CGRect cellFrame = [dataSource timelineView:self frameForCellAtIndex:index];
            if(CGRectIntersectsRect(cellFrame, visibleBounds)) {
                TimelineViewCell *cell = [dataSource timelineView:self cellForIndex:index];
                cell.frame = cellFrame;
                cell.index = index;
                [items addObject:cell];
                [self addSubview:cell];
            }
        }
    }];
    [visibleCells unionSet:items];
    
    return [items copy];
}

- (void)updateCells:(void (^)(void))updates completion:(void (^)(BOOL finished))completion
{
    NSInteger deleteCount = 0;
    NSInteger insertCount = 0;
    NSInteger pastCount = cellCount;
    NSInteger expectedCount;
    NSMutableSet *offscreenCells;
    NSMapTable *movedCellMap;
    NSSet *deletedCells;
    NSSet *insertedCells;
    
    if(!updates) {
        if(completion) completion(YES);
        return;
    }
    
    ++updating;
    updates();
    
    if(dataSource) {
        cellCount = [dataSource numberOfCellsInTimelineView:self];
    }
    expectedCount = pastCount - indexesToDelete.count + indexesToInsert.count;
    
    if(cellCount != expectedCount) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:[NSString stringWithFormat:@"Invalid update: invalid number of items. The number of items after the update (%d) must be equal to the number of items before the update (%d), plus or minus the number of items inserted or deleted (%d inserted, %d deleted).", cellCount, pastCount, insertCount, deleteCount]
                                     userInfo:nil];
    }
    
    
    offscreenCells = [[NSMutableSet alloc] init];
    movedCellMap = [self moveCellsWithDictionary:indexesToMove offscreenCells:offscreenCells];
    deletedCells = [self deleteCellsWithIndexSet:indexesToDelete];
    insertedCells = [self insertCellsWithIndexSet:indexesToInsert];
    
    [UIView animateWithDuration:0.3 animations:^{
        self.animationBlock(movedCellMap, deletedCells, insertedCells);
    } completion:^(BOOL finished) {
        for (TimelineViewCell *cell in deletedCells) {
            [cell removeFromSuperview];
        }
        [recycledCells unionSet:deletedCells];
        
        for (TimelineViewCell *cell in offscreenCells) {
            [cell removeFromSuperview];
        }
        [recycledCells unionSet:offscreenCells];
        
        --updating;
        if(completion) completion(finished);
    }];
    
    [indexesToDelete removeAllIndexes];
    [indexesToInsert removeAllIndexes];
    [cacheFrameLookup removeAllObjects];
}

@end
