//
//  TimelineCell.h
//  TimelineView
//
//  Created by Luke Scott on 3/4/13.
//  Copyright (c) 2013 Luke Scott. All rights reserved.
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
