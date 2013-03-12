//
//  TimelineDelegate.h
//  TimelineView
//
//  Created by Luke Scott on 3/4/13.
//  Copyright (c) 2013 Luke Scott. All rights reserved.
//

#import <Foundation/Foundation.h>

@class TimelineView;
@class TimelineViewCell;

@protocol TimelineViewDelegate <NSObject>
@optional

- (void)timelineView:(TimelineView *)timelineView willDisplayCell:(TimelineViewCell *)cell atIndex:(NSInteger)index;
- (void)timelineView:(TimelineView *)timelineView didEndDisplayingCell:(TimelineViewCell *)cell atIndex:(NSInteger)index;

- (BOOL)timelineView:(TimelineView *)timelineView shouldSelectCellAtIndex:(NSInteger)index;
- (void)timelineView:(TimelineView *)timelineView willSelectCellAtIndex:(NSInteger)index;
- (void)timelineView:(TimelineView *)timelineView didSelectCellAtIndex:(NSInteger)index;

- (BOOL)timelineView:(TimelineView *)timelineView shouldDeselectCellAtIndex:(NSInteger)index;
- (void)timelineView:(TimelineView *)timelineView willDeselectCellAtIndex:(NSInteger)index;
- (void)timelineView:(TimelineView *)timelineView didDeselectCellAtIndex:(NSInteger)index;

- (BOOL)timelineView:(TimelineView *)timelineView shouldHighlightCellAtIndex:(NSInteger)index;
- (void)timelineView:(TimelineView *)timelineView didHighlightCellAtIndex:(NSInteger)index;
- (void)timelineView:(TimelineView *)timelineView didUnhighlightCellAtIndex:(NSInteger)index;

@end
