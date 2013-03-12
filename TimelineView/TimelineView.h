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
    TimelineScrollDirectionVertical,
    TimelineScrollDirectionHorizontal
} TimelineScrollDirection;

@interface TimelineView : UIScrollView

- (void)reloadData;
- (void)registerClass:(Class)cellClass forCellReuseIdentifier:(NSString *)identifier;
- (TimelineViewCell *)dequeueReuseableViewWithIdentifier:(NSString *)identifier forIndex:(NSInteger)index;

@property (weak, nonatomic) IBOutlet id<TimelineViewDataSource>dataSource;
@property (weak, nonatomic) IBOutlet id<TimelineViewDelegate,UIScrollViewDelegate>delegate;
@property (assign, nonatomic) TimelineScrollDirection direction;
@property (assign, nonatomic) BOOL allowsMultipleSelection;

@property (readonly, nonatomic) UITapGestureRecognizer *tapGestureRecognizer;
@property (readonly, nonatomic) UILongPressGestureRecognizer *longPressGestureRecognizer;

@property (assign, nonatomic) UIEdgeInsets scrollingEdgeInsets;
@property (assign, nonatomic) CGFloat scrollingSpeed;
@property (assign, nonatomic) BOOL scrollingSpeedScaled;
@end
