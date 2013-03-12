//
//  TimelineDataSource.h
//  TimelineView
//
//  Created by Luke Scott on 3/4/13.
//  Copyright (c) 2013 Luke Scott. All rights reserved.
//

#import <Foundation/Foundation.h>

@class TimelineView;
@class TimelineViewCell;

@protocol TimelineViewDataSource <NSObject>
@required

- (CGSize)contentSizeForTimelineView:(TimelineView *)timelineView;
- (NSInteger)numberOfCellsInTimelineView:(TimelineView *)timelineView;
- (CGRect)timelineView:(TimelineView *)timelineView cellFrameForIndex:(NSInteger)index;
- (TimelineViewCell *)timelineView:(TimelineView *)timelineView cellForIndex:(NSInteger)index;

@optional

- (BOOL)timelineView:(TimelineView *)timelineView canMoveCellAtIndex:(NSInteger)index;
- (void)timelineView:(TimelineView *)timelineView moveCellAtIndex:(NSInteger)sourceIndex toIndex:(NSInteger)destinationIndex withFrame:(CGRect)frame;

@end
