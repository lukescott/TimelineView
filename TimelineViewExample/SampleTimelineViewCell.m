//
//  Copyright (c) 2013 Luke Scott
//  https://github.com/lukescott/TimelineView
//  Distributed under MIT license
//

#import "SampleTimelineViewCell.h"

@interface SampleTimelineViewCell ()

@end

@implementation SampleTimelineViewCell
@synthesize color = _color;
@synthesize label;

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithReuseIdentifier:reuseIdentifier];
    if(self) {
        label = [[UILabel alloc] init];
        label.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        label.textColor = [UIColor whiteColor];
        label.backgroundColor = [UIColor clearColor];
        label.textAlignment = NSTextAlignmentCenter;
        label.font = [UIFont systemFontOfSize:20.f];
        [self addSubview:label];
    }
    return self;
}

- (void)setColor:(UIColor *)color
{
    _color = color;
    
    if(! self.selected) {
        self.backgroundColor = color;
    }
}

- (void)prepareForReuse
{
    // Always call super
    [super prepareForReuse];
    
    _color = nil;
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    
    if(highlighted) {
        self.alpha = 0.5f;
    }
    else {
        self.alpha = 1.f;
    }
}

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    
    if(selected) {
        self.backgroundColor = [UIColor whiteColor];
        label.textColor = [UIColor blackColor];
    }
    else {
        self.backgroundColor = _color;
        label.textColor = [UIColor whiteColor];
    }
}

- (void)setDragging:(BOOL)dragging
{
    [super setDragging:dragging];
    
    if(dragging) {
        [UIView animateWithDuration:0.3 animations:^{
            self.transform = CGAffineTransformScale(self.transform, .9f, .9f);
        }];
    }
    else {
        [UIView animateWithDuration:0.3 animations:^{
            self.transform = CGAffineTransformIdentity;
        }];
    }
}

@end
