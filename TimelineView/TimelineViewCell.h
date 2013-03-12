//
//  Copyright (c) 2013 Luke Scott
//  https://github.com/lukescott/TimelineView
//  Distributed under MIT license
//

#import <UIKit/UIKit.h>

@interface TimelineViewCell : UIView

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier;
- (void)prepareForReuse;

@property (readonly, nonatomic) NSString *reuseIdentifier;
@property (assign, nonatomic) BOOL highlighted;
@property (assign, nonatomic) BOOL selected;
@property (assign, nonatomic) BOOL dragging;
@end
