//
//  Copyright (c) 2013 Luke Scott
//  https://github.com/lukescott/TimelineView
//  Distributed under MIT license
//

#import "TimelineView.h"

@interface TimelineView (Mutation)

- (TimelineViewAnimationBlock)defaultAnimationBlock;
- (void)updateCells:(void (^)(void))updates completion:(void (^)(BOOL finished))completion;

@end
