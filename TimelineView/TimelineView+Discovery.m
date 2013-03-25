//
//  Copyright (c) 2013 Luke Scott
//  https://github.com/lukescott/TimelineView
//  Distributed under MIT license
//

#import "TimelineView+Discovery.h"
#import "TimelineView_Private.h"

@implementation TimelineView (Discovery)

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
    
    if(count < 1) {
        return (NSRange){NSNotFound, 0};
    }
    
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
            searchRange = NSMakeRange(estIndex + 1, searchRange.length / 2);
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
    
    if(count < 1) {
        return (NSRange){0, 0};
    }
    
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

@end
