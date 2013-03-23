//
//  Copyright (c) 2013 Luke Scott
//  https://github.com/lukescott/TimelineView
//  Distributed under MIT license
//

#import <UIKit/UIKit.h>
#import "TimelineView.h"

@interface ViewController : UIViewController <TimelineViewDataSource, TimelineViewDelegate>

- (IBAction)deleteButtonPush:(id)sender;
- (IBAction)swapButtonPush:(id)sender;
- (IBAction)insertTopButtonPush:(id)sender;

@property (weak, nonatomic) IBOutlet TimelineView *timelineView;
@end
