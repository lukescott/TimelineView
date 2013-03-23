//
//  Copyright (c) 2013 Luke Scott
//  https://github.com/lukescott/TimelineView
//  Distributed under MIT license
//

#import "TimelineViewCell.h"

@interface TimelineViewCell ()
@property (strong, nonatomic) NSString *reuseIdentifier;
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
    self.transform = CGAffineTransformIdentity;
    self.highlighted = NO;
    self.selected = NO;
}

@end
