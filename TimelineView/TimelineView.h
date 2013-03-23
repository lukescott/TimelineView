//
//  Copyright (c) 2013 Luke Scott
//  https://github.com/lukescott/TimelineView
//  Distributed under MIT license
//

#import <UIKit/UIKit.h>
#import "TimelineViewCell.h"
#import "TimelineViewDataSource.h"
#import "TimelineViewDelegate.h"

typedef enum {
    TimelineViewScrollDirectionVertical,
    TimelineViewScrollDirectionHorizontal
} TimelineViewScrollDirection;

typedef enum {
    TimelineViewScrollPositionTop,
    TimelineViewScrollPositionCenter,
    TimelineViewScrollPositionBottom
} TimelineViewScrollPosition;

typedef void (^TimelineViewAnimationBlock)(NSMapTable *moved, NSSet *deleted, NSSet *inserted);

@interface TimelineView : UIScrollView

- (void)registerClass:(Class)cellClass forCellWithReuseIdentifier:(NSString *)identifier;
- (void)registerNib:(UINib *)nib forCellWithReuseIdentifier:(NSString *)identifier;
- (TimelineViewCell *)dequeueReusableCellWithReuseIdentifier:(NSString *)identifier forIndex:(NSInteger)index;

- (void)reloadData;

- (NSArray *)visibleCells;

- (NSInteger)indexForInsertingFrame:(CGRect)frame;
- (void)insertItemAtIndex:(NSInteger)index;
- (void)insertItemsAtIndexSet:(NSIndexSet *)indexSet;
- (void)deleteItemAtIndex:(NSInteger)index;
- (void)deleteItemsAtIndexSet:(NSIndexSet *)indexSet;
- (void)moveItemAtIndex:(NSInteger)index toIndex:(NSInteger)newIndex;
- (void)performBatchUpdates:(void (^)(void))updates completion:(void (^)(BOOL finished))completion;

- (void)selectItemAtIndex:(NSInteger)index;
- (void)deselectItemAtIndex:(NSInteger)index;

- (NSInteger)indexForSelectedItem;
- (NSInteger)indexForItemAtPoint:(CGPoint)point;
- (NSIndexSet *)indexSetForSelectedItems;
- (NSIndexSet *)indexSetForItemsInRect:(CGRect)rect;
- (NSIndexSet *)indexSetForVisibleItems;
- (TimelineViewCell *)cellForItemAtIndex:(NSInteger)index;
- (TimelineViewCell *)cellAtPoint:(CGPoint)point;

- (void)scrollToItemAtIndex:(NSInteger)index atScrollPosition:(TimelineViewScrollPosition)scrollPosition animated:(BOOL)animated;

@property (weak, nonatomic) IBOutlet id<TimelineViewDataSource>dataSource;
@property (weak, nonatomic) IBOutlet id<TimelineViewDelegate,UIScrollViewDelegate>delegate;
@property (readonly, nonatomic) UITapGestureRecognizer *tapGestureRecognizer;
@property (readonly, nonatomic) UILongPressGestureRecognizer *longPressGestureRecognizer;
@property (assign, nonatomic) TimelineViewScrollDirection scrollDirection;
@property (strong, nonatomic) TimelineViewAnimationBlock animationBlock;
@property (assign, nonatomic) BOOL allowsSelection;
@property (assign, nonatomic) BOOL allowsMultipleSelection;
@property (assign, nonatomic) BOOL scrollingSpeedScaled;
@property (assign, nonatomic) UIEdgeInsets scrollingEdgeInsets;
@property (assign, nonatomic) CGFloat scrollingSpeed;
@end
