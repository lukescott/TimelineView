TimelineView
============

TimelineView functions like a UITableView, but allows you to position cells anywhere using a custom frame (CGRect). This allows you to have irregular spacing, overlapping cells, etc... The only requirement is the data source must be sorted by min X/Y position (horizontal/vertical). Cells can be highlighted, selected, and dragged by the user. Works in the horizontal or vertical direction.

For the most part the delegate and dataSource protocol is similar to a UITableView/UICollectionView with the following additions/changes:

TimelineView uses an NSInteger for index instead of NSIndexPath. TimelineView doesn't have sections.

You must specify a content size. The TimelineView cannot assume what the content size is. You may want it to be as large as the last element, or you may want it larger to allow the user to drag elements beyond the last element.

    - (CGSize)contentSizeForTimelineView:(TimelineView *)timelineView

TimelineView asks for the frame size to determine the visible index range. It makes an educated guess what the top visible index is and works backward/forward until it finds the visible range. It will try to cache requests for the frame size.

    - (CGRect)timelineView:(TimelineView *)timelineView cellFrameForIndex:(NSInteger)index

When a user drags a cell to a new position it also passes the new frame (CGRect). You can use this to update your data source. It will determine the correct destination index, provided your data source is properly sorted.

    (void)timelineView:(TimelineView *)timelineView moveCellAtIndex:(NSInteger)sourceIndex toIndex:(NSInteger)destinationIndex withFrame:(CGRect)frame;

Other than what is mentioned above, the TimelineView has the same delegate calls a UITableView / UICollectionView has, so it can be used (almost) identically.