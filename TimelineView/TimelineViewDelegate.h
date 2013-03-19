//
//  Copyright (c) 2013 Luke Scott
//  https://github.com/lukescott/TimelineView
//  Distributed under MIT license
//

#import <Foundation/Foundation.h>

@class TimelineView;
@class TimelineViewCell;

@protocol TimelineViewDelegate <NSObject>
@optional

- (void)timelineView:(TimelineView *)timelineView willDisplayCell:(TimelineViewCell *)cell atIndex:(NSInteger)index;
- (void)timelineView:(TimelineView *)timelineView didEndDisplayingCell:(TimelineViewCell *)cell atIndex:(NSInteger)index;

- (BOOL)timelineView:(TimelineView *)timelineView shouldSelectItemAtIndex:(NSInteger)index;
- (void)timelineView:(TimelineView *)timelineView willSelectItemAtIndex:(NSInteger)index;
- (void)timelineView:(TimelineView *)timelineView didSelectItemAtIndex:(NSInteger)index;

- (BOOL)timelineView:(TimelineView *)timelineView shouldDeselectItemAtIndex:(NSInteger)index;
- (void)timelineView:(TimelineView *)timelineView willDeselectItemAtIndex:(NSInteger)index;
- (void)timelineView:(TimelineView *)timelineView didDeselectItemAtIndex:(NSInteger)index;

- (BOOL)timelineView:(TimelineView *)timelineView shouldHighlightItemAtIndex:(NSInteger)index;
- (void)timelineView:(TimelineView *)timelineView didHighlightItemAtIndex:(NSInteger)index;
- (void)timelineView:(TimelineView *)timelineView didUnhighlightItemAtIndex:(NSInteger)index;

@end
