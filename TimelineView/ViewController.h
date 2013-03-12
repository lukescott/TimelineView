//
//  ViewController.h
//  TimelineView
//
//  Created by Luke Scott on 3/4/13.
//  Copyright (c) 2013 Luke Scott. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TimelineView.h"

@interface ViewController : UIViewController <TimelineViewDataSource, TimelineViewDelegate>

@property (weak, nonatomic) IBOutlet TimelineView *timelineView;

@end
