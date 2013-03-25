//
//  Copyright (c) 2013 Luke Scott
//  https://github.com/lukescott/TimelineView
//  Distributed under MIT license
//

#import "ViewController.h"
#import "TimelineView.h"
#import "SampleTimelineViewCell.h"

@interface ViewController ()
{
    NSMutableArray *data;
}
@end

@implementation ViewController
@synthesize timelineView = _timelineView;

#pragma mark Helper Functions
#pragma mark -

- (NSInteger)randFrom:(NSInteger)from to:(NSInteger)to
{
    return (arc4random() % to) + from;
}

- (UIColor *)colorByColorInt:(NSInteger)colorInt
{
    UIColor *color;
    switch (colorInt) {
        case 1: color = [UIColor redColor]; break;
        case 2: color = [UIColor blackColor]; break;
        case 3: color = [UIColor yellowColor]; break;
        case 4: color = [UIColor orangeColor]; break;
        case 5: color = [UIColor greenColor]; break;
        case 6: color = [UIColor purpleColor]; break;
        case 7: color = [UIColor brownColor]; break;
        case 8: color = [UIColor blueColor]; break;
        case 9: color = [UIColor magentaColor]; break;
    }
    
    return color;
}

#pragma mark UIViewController
#pragma mark -

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSInteger num = 10000;
    NSInteger lastPos = 0;
    NSInteger minSep = 96;
    NSInteger maxSep = 384;
    NSInteger lastColorInt = 0;
    
    data = [[NSMutableArray alloc] initWithCapacity:num];
    
    // Make a bunch of random data
    for(NSInteger i = 0; i < num; ++i) {
        UIColor *color;
        NSInteger colorInt = 0;
        lastPos = lastPos + [self randFrom:minSep to:maxSep];
        
        // Make sure same color doesn't appear twice in a row
        do {
            colorInt = [self randFrom:1 to:9];
        } while (colorInt == lastColorInt);
        
        lastColorInt = colorInt;
        color = [self colorByColorInt:colorInt];
        
        [data addObject:@{
            @"rect":NSStringFromCGRect(CGRectMake(0.f, (CGFloat)lastPos, 128.f, 128.f)),
            @"color":color,
            @"num":@(i)}];
    }
    
    [_timelineView registerNib:[UINib nibWithNibName:@"SampleTimelineViewCell" bundle:nil]
    forCellWithReuseIdentifier:@"SampleTimelineViewCell"];
    
    _timelineView.allowsMultipleSelection = YES;
    
    // Change delete/insert animation to shrink effect
    _timelineView.animationBlock = ^(NSMapTable *moved, NSSet *deleted, NSSet *inserted) {
        for(TimelineViewCell *cell in moved) {
            cell.frame = [[moved objectForKey:cell] CGRectValue];
        }
        for(TimelineViewCell *cell in deleted) {
            cell.transform = CGAffineTransformScale(cell.transform, 0, 0);
        }
        for(TimelineViewCell *cell in inserted) {
            cell.transform = CGAffineTransformScale(cell.transform, 0, 0);
            cell.transform = CGAffineTransformIdentity;
        }
    };
}

#pragma mark TimelineViewDataSource
#pragma mark -

- (CGSize)contentSizeForTimelineView:(TimelineView *)timelineView
{
    NSDictionary *lastObject = [data lastObject];
    NSString *strRect = lastObject[@"rect"];
    CGRect frame = CGRectFromString(strRect);
    
    return CGSizeMake(timelineView.bounds.size.width, CGRectGetMaxY(frame));
}

- (NSInteger)numberOfCellsInTimelineView:(TimelineView *)timelineView
{
    return data.count;
}

- (CGRect)timelineView:(TimelineView *)timelineView frameForCellAtIndex:(NSInteger)index
{
    return CGRectFromString([[data objectAtIndex:index] objectForKey:@"rect"]);
}

- (TimelineViewCell *)timelineView:(TimelineView *)timelineView cellForIndex:(NSInteger)index
{
    SampleTimelineViewCell *cell = (SampleTimelineViewCell*)[timelineView dequeueReusableCellWithReuseIdentifier:@"SampleTimelineViewCell" forIndex:index];
    NSDictionary *info = [data objectAtIndex:index];
    
    cell.color = info[@"color"];
    cell.label.text = [NSString stringWithFormat:@"%@", info[@"num"]];
    
    return cell;
}

- (BOOL)timelineView:(TimelineView *)timelineView canMoveItemAtIndex:(NSInteger)index
{
    return YES;
}

- (void)timelineView:(TimelineView *)timelineView moveItemAtIndex:(NSInteger)sourceIndex toIndex:(NSInteger)destinationIndex withFrame:(CGRect)frame
{
    NSDictionary *info = [data objectAtIndex:sourceIndex];
    
    [data removeObjectAtIndex:sourceIndex];
    [data insertObject:@{@"rect": NSStringFromCGRect(frame), @"color": info[@"color"], @"num": info[@"num"]} atIndex:destinationIndex];
}

#pragma mark Buttons
#pragma mark -

- (IBAction)deleteButtonPush:(id)sender
{
    NSIndexSet *indexSet = _timelineView.indexSetForSelectedItems;
    
    [data removeObjectsAtIndexes:indexSet];
    [_timelineView deleteItemsAtIndexSet:indexSet];
}

- (IBAction)swapButtonPush:(id)sender
{
    NSIndexSet *indexSet = _timelineView.indexSetForSelectedItems;
    
    if(indexSet.count != 2) {
        NSLog(@"No more than 2 items selected!");
        return;
    }
    
    NSDictionary *firstInfo = [data objectAtIndex:indexSet.firstIndex];
    NSDictionary *lastInfo = [data objectAtIndex:indexSet.lastIndex];
    
    [data replaceObjectAtIndex:indexSet.firstIndex withObject:@{@"rect": firstInfo[@"rect"], @"color": lastInfo[@"color"], @"num": lastInfo[@"num"]}];
    [data replaceObjectAtIndex:indexSet.lastIndex withObject:@{@"rect": lastInfo[@"rect"], @"color": firstInfo[@"color"], @"num": firstInfo[@"num"]}];
    
    [_timelineView performBatchUpdates:^{
        [_timelineView moveItemAtIndex:indexSet.firstIndex toIndex:indexSet.lastIndex];
        [_timelineView moveItemAtIndex:indexSet.lastIndex toIndex:indexSet.firstIndex];
    } completion:nil];
}

- (IBAction)insertTopButtonPush:(id)sender
{
    CGRect cellFrame = CGRectMake(0, _timelineView.bounds.origin.y, 128.f, 128.f);
    NSInteger index = [_timelineView indexForInsertingFrame:cellFrame];
    NSString *rect = NSStringFromCGRect(cellFrame);
    NSInteger colorInt = [self randFrom:1 to:9];
    UIColor *color = [self colorByColorInt:colorInt];
    NSArray *num = [NSString stringWithFormat:@"%c", [self randFrom:65 to:122]];
    
    [data insertObject:@{@"rect":rect, @"color":color, @"num": num} atIndex:index];
    [_timelineView insertItemAtIndex:index];
}

@end
