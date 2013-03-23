//
//  Copyright (c) 2013 Luke Scott
//  https://github.com/lukescott/TimelineView
//  Distributed under MIT license
//

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
    // Properties
    __weak id<TimelineViewDataSource>dataSource;
    __weak id<TimelineViewDelegate,UIScrollViewDelegate>delegate;
    UITapGestureRecognizer *tapGestureRecognizer;
    UILongPressGestureRecognizer *longPressGestureRecognizer;
    TimelineViewScrollDirection scrollDirection;
    TimelineViewAnimationBlock animationBlock;
    BOOL allowsSelection;
    BOOL allowsMultipleSelection;
    BOOL scrollingSpeedScaled;
    UIEdgeInsets scrollingEdgeInsets;
    CGFloat scrollingSpeed;
    
    // Private iVars
    NSInteger cellCount;
    NSInteger updating;
    NSInteger batching;
    NSRange visibleRange;
    NSMutableSet *visibleCells;
    NSMutableSet *recycledCells;
    NSMutableDictionary *registeredPrototypes;
    NSMutableDictionary *cacheFrameLookup;
    NSMutableDictionary *indexesToMove;
    NSMutableIndexSet *indexesToDelete;
    NSMutableIndexSet *indexesToInsert;
    NSMutableIndexSet *selectedIndexes;
    TimelineViewCell *touchedCell;
    _TouchMode touchMode;
    CGPoint lastPoint;
    NSTimer *scrollingTimer;
}
@end

@interface TimelineViewCell ()
@property (strong, nonatomic) NSString *reuseIdentifier;
@property (assign, nonatomic) NSInteger index;
@end

