//
//  TimelineCell.m
//  TimelineView
//
//  Created by Luke Scott on 3/4/13.
//  Copyright (c) 2013 Luke Scott. All rights reserved.
//

#import "TimelineViewCell.h"

@interface TimelineViewCell ()
@property (assign, nonatomic) NSInteger index;
@end

@implementation TimelineViewCell
@synthesize reuseIdentifier=_reuseIdentifier;
@synthesize index=_index;
@synthesize selected;
@synthesize highlighted;
@synthesize dragging;

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super init];
    if(self) {
        _reuseIdentifier = reuseIdentifier;
    }
    return self;
}

- (void)prepareForReuse
{
    self.highlighted = NO;
    self.selected = NO;
}

@end
