//
//  NextToArriveTableViewController.m
//  iSEPTA
//
//  Created by septa on 7/19/13.
//  Copyright (c) 2013 SEPTA. All rights reserved.
//

#import "NextToArriveTableViewController.h"

@interface NextToArriveTableViewController ()

@end

@implementation NextToArriveTableViewController
{

    // Favorites, Recently Viewed, Data, etc. are stored here for easy access
    TableViewStore *_tableData;
    
    // Contains detailed information about the start/end destinations selected in the topmost cell
    ItineraryObject *_itinerary;
    
    
    StopNamesTableViewControllerSelectionType _lastSelectedType;
    NextToArriveFavoriteSubtitleState _favoriteStatus;
    
    
    // Drop down window controller
    REMenu *_menu;

    
    // Handles Reading and Writing of Favorites and Recently Viewed
    NTASaveController *saveData;
    
    
    // Used for retrieving the latest JSON data on the Trains
    NSOperationQueue *_jsonQueue;
    NSBlockOperation *_jsonOp;

    
    NSTimer *menuRefreshTimer;
    NSTimer *updateTimer;
    BOOL _stillWaitingOnWebRequest;
    BOOL _launchUpdateTimer;
    BOOL _killAllTimers;
    
    // --==  This dictionary is the quick lookup hash for replacing one the correct, GTFS approved, station name with one that SEPTA's internal DBs will recognize.  *Insert face palm here*
    NSMutableDictionary *replacement;
    
    
    NextToArriveLeftButtonPressed _itineraryCompletion;
    
}



- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

-(void) viewWillAppear:(BOOL)animated
{

    // self.view.frame will display the actual width and height based on the orientation here.
    // viewDidLoad will only show the portriat width and height, regardless of orientation.
        
    LineHeaderView *titleView = (LineHeaderView*)self.navigationItem.titleView;
//    float navW = [(UIView*)[self.navigationItem.leftBarButtonItem  valueForKey:@"view"] frame].size.width;
    float w    = self.view.frame.size.width;
    [titleView updateWidth: w];
//    [titleView updateFrame: CGRectMake(0, 0, w - (navW*2) -8, 32)];

}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    
    // Initialize our objects
    _tableData = [[TableViewStore alloc] init];
    _itinerary = [[ItineraryObject alloc] init];
    
    [_itinerary setStartStopID:[NSNumber numberWithInt:0] ];
    [_itinerary setStartStopName: DEFAULT_MESSAGE];
    
    [_itinerary setEndStopID:[NSNumber numberWithInt:0] ];
    [_itinerary setEndStopName: DEFAULT_MESSAGE];
    
    
    [_tableData addObject:_itinerary forTitle:@"Itinerary"];
    
    
    
    // Registering xib
    [self.tableView registerNib:[UINib nibWithNibName:@"NextToArriveTripHistoryCell"    bundle:nil] forCellReuseIdentifier:@"NextToArriveTripHistoryCell"];
    [self.tableView registerNib:[UINib nibWithNibName:@"NextToArriveItineraryCell"      bundle:nil] forCellReuseIdentifier:@"NextToArriveItineraryCell"];
    [self.tableView registerNib:[UINib nibWithNibName:@"NextToArriveSingleTripCell"     bundle:nil] forCellReuseIdentifier:@"NextToArriveSingleTripCell"];
    [self.tableView registerNib:[UINib nibWithNibName:@"NextToArriveConnectionTripCell" bundle:nil] forCellReuseIdentifier:@"NextToArriveConnectionTripCell"];

    
    
    // --==  Create the NSOperationQueue to allow for cancelling
    _jsonQueue  = [[NSOperationQueue alloc] init];
    
    
    // Load Favorites and Recent from the Save Controller
    saveData = [[NTASaveController alloc] init];
    
    
    // --==  Favorites  ==--
//    for (id object in [saveData favorites] )
//    {
//        [_tableData addObject: object forTitle:@"Favorites"];
//    }
//    
//    if ( [saveData favorites] != nil )
//        [saveData setFavorites: [_tableData objectForSectionWithTitle:@"Favorites"] ];
    
    _favoriteStatus = kNextToArriveFavoriteSubtitleStatusUnknown;
    
    
    // --==  Recent  ==--
//    for (id object in [saveData recent] )
//    {
//        [_tableData addObject: object forTitle:@"Recent"];
//    }
//    
//    if ( [saveData recent] != nil )
//        [saveData setRecent: [_tableData objectForSectionWithTitle:@"Recent"] ];

    [_tableData replaceArrayWith: [saveData favorites] forTitle:@"Favorites"];
    [_tableData replaceArrayWith: [saveData recent]    forTitle:@"Recent"];
    
    [_tableData addObject: [[NextToArrivaJSONObject alloc] init] forTitle:@"Data"];
    [_tableData addObject: [[NextToArrivaJSONObject alloc] init] forTitle:@"Data"];
    [_tableData addObject: [[NextToArrivaJSONObject alloc] init] forTitle:@"Data"];
    [_tableData addObject: [[NextToArrivaJSONObject alloc] init] forTitle:@"Data"];
    
        
    _launchUpdateTimer = NO;
    _killAllTimers     = NO;

    
//    UIImage *backImg = [UIImage imageNamed:@"NTA-white.png"];
    CustomFlatBarButton *backBarButtonItem = [[CustomFlatBarButton alloc] initWithImageNamed:@"NTA-white.png" withTarget:self andWithAction:@selector(backButtonPressed:)];
    self.navigationItem.leftBarButtonItem = backBarButtonItem;
    
    
//    float navW = [(UIView*)[self.navigationItem.leftBarButtonItem  valueForKey:@"view"] frame].size.width;
//    float w    = self.view.frame.size.width;
    LineHeaderView *titleView = [[LineHeaderView alloc] initWithFrame:CGRectMake(0, 0,500, 32) withTitle:@"Next To Arrive"];
    [self.navigationItem setTitleView:titleView];

    
        
    // Now create an imageView with the background image you want to use
    UIImageView *bgImageView = [[UIImageView alloc] initWithImage: [UIImage imageNamed:@"mainBackground.png"] ];
    [self.tableView setBackgroundView: bgImageView];
    
    
    // Used in [self fixMismatchedStopName].  Key: GTFS-compliant station name, value: NTA recognized equivalent station name.
    // To any developer reading this, I'm sorry for this blight but there needs to be some glue logic to connect a GTFS stop name
    // to the names stored in the legacy database that the API uses.
    // TODO:  Change the *#@!ing NTA API to recognize these translations!
    replacement = [[NSMutableDictionary alloc] init];
    
    [self populateGTFSLookUp];
    
    
    //  Add Upper Right button
//    UIBarButtonItem *rightButton = [[UIBarButtonItem alloc] init];
//    [rightButton setImage: [UIImage imageNamed:@"second-menu.png"] ];
//    [rightButton setStyle: UIBarButtonItemStylePlain];
    
    CustomFlatBarButton *rightButton = [[CustomFlatBarButton alloc] initWithImageNamed:@"second-menu.png" withTarget:self andWithAction:@selector(dropDownMenuPressed:)];
    [self.navigationItem setRightBarButtonItem: rightButton];

 
    REMenuItem *refreshItem = [[REMenuItem alloc] initWithTitle:@"Refresh"
                                                       subtitle:@"select trip before refreshing"
                                                          image:[UIImage imageNamed:@"Refresh.png"]
                                               highlightedImage:nil
                                                         action:^(REMenuItem *item) {
                                                             [self refreshJSONData];
                                                         }];
    
    
    REMenuItem *favoritesItem = [[REMenuItem alloc] initWithTitle:@"Favorite"
                                                         subtitle:FAVORITE_SUBTITLE_NONE
                                                            image:[UIImage imageNamed:@"Favorite.png"]
                                                 highlightedImage:nil
                                                           action:^(REMenuItem *item) {
                                                               [self selectedFavorites];
                                                           }];
    
//    REMenuItem *filterItem = [[REMenuItem alloc] initWithTitle:@"Filter"
//                                                      subtitle:@"select filter options"
//                                                         image:[UIImage imageNamed:@"Filter.png"]
//                                              highlightedImage:nil
//                                                        action:^(REMenuItem *item) {
////                                                            [self showTSMessage];
//                                                        }];
//    
//    REMenuItem *advisoryItem = [[REMenuItem alloc] initWithTitle:@"Advisory"
//                                                        subtitle:@"Service Advisories"
//                                                           image:[UIImage imageNamed:@"Advisory.png"]
//                                                highlightedImage:nil
//                                                          action:^(REMenuItem *item) {
//                                                              
//                                                          }];

    REMenuItem *fareItem = [[REMenuItem alloc] initWithTitle:@"Fare"
                                                        subtitle:@"Fare Information"
                                                           image:[UIImage imageNamed:@"Fare.png"]
                                                highlightedImage:nil
                                                          action:^(REMenuItem *item) {
                                                              [self loadFareVC];
                                                          }];

    
//    _menu = [[REMenu alloc] initWithItems:@[refreshItem, favoritesItem, filterItem, advisoryItem, fareItem] ];
    _menu = [[REMenu alloc] initWithItems:@[refreshItem, favoritesItem, fareItem] ];
    _menu.cornerRadius = 4;
    _menu.shadowRadius = 4;
    _menu.shadowColor = [UIColor blackColor];
    _menu.shadowOffset = CGSizeMake(0, 1);
    _menu.shadowOpacity = 1;
    _menu.imageOffset = CGSizeMake(5, -1);
    _menu.itemHeight = 40.0f;
    _menu.waitUntilAnimationIsComplete = NO;
    
    _menu.font = [UIFont fontWithName:@"TrebuchetMS-Bold" size:20.0f];
    _menu.subtitleFont = [UIFont fontWithName:@"TrebuchetMS" size:15.0f];
    
    _menu.textColor = [UIColor whiteColor];
    _menu.subtitleTextColor = [UIColor whiteColor];
    
    
//    _menu.textAlignment = UITextAlignmentLeft;
 
    
    [[UITableView appearance] setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    
}


- (void)viewDidUnload
{
//    [self setGestureDoubleTap:nil];
    [self setGestureLongPress:nil];
    [super viewDidUnload];
}


-(void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    _killAllTimers = NO;
    // Let's not immediately kick off another JSON request this when user comes back into this view
    //    if ( _launchUpdateTimer )
    //        [self kickOffAnotherJSONRequest];
    
}


-(void) viewDidDisappear:(BOOL)animated
{
    
    [super viewDidDisappear:animated];
    
    NSLog(@"NTA -(void) viewDidDisappear");
    _killAllTimers = YES;
    
    if ( [SVProgressHUD isVisible] )
        [SVProgressHUD dismiss];
    
    
    [_jsonQueue cancelAllOperations];
    

    // Save Favorite/Recent data if it's been modified
    [saveData save];
    

    _launchUpdateTimer = NO;
    [self invalidateTimer];
    
}





- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    
}



-(void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    
    LineHeaderView *titleView = (LineHeaderView*)self.navigationItem.titleView;
//    float navW = [(UIView*)[self.navigationItem.leftBarButtonItem  valueForKey:@"view"] frame].size.width;
    float w    = self.view.frame.size.width;
    [titleView updateWidth: w];
//    [titleView updateFrame: CGRectMake(0, 0, w - (navW*2) -8, 32)];
    
}


//-(void) didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
//{
//    
//}


#pragma mark - Update Itinerary
-(void) updateItinerary
{
    
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    
    NextToArriveItineraryCell *myCell = (NextToArriveItineraryCell*)[self.tableView cellForRowAtIndexPath:indexPath];
    
    [[myCell btnStartDestination] setTitle:_itinerary.startStopName forState:UIControlStateNormal];
    [[myCell btnEndDestination  ] setTitle:_itinerary.endStopName   forState:UIControlStateNormal];
    
}


#pragma mark - UITableView data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{

    // Return the number of sections.
    return [_tableData numOfSections];
    
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    
    // Return the number of rows in the section.
    return [_tableData numOfRowsForSection:section];
    
}


-(void) tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    [cell setBackgroundColor: [UIColor colorWithWhite:1.0f alpha:.8] ];
    
    UIImageView *separator = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"gradient_line.png"]];
//    [separator setAutoresizesSubviews:YES];
//    [separator setAutoresizingMask: (UIViewAutoresizingFlexibleWidth) ];
//    [separator setContentMode: UIViewContentModeScaleAspectFit];
    
    UITableViewCell *newCell = (UITableViewCell*)cell;
    
    [separator setFrame: CGRectOffset(separator.frame, 0, newCell.frame.size.height-separator.frame.size.height)];
    [newCell.contentView addSubview: separator];
    
}



- (UITableViewCell *)tableView:(UITableView *)thisTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    static NSString *itineraryCell      = @"NextToArriveItineraryCell";

    
    id myCell;
    
    switch (indexPath.section)
    {
        case 0:
            
//            NextToArriveItineraryCell *cell = [thisTableView dequeueReusableCellWithIdentifier:itineraryCell forIndexPath:indexPath];

            myCell = (NextToArriveItineraryCell*)[thisTableView dequeueReusableCellWithIdentifier: itineraryCell];
            [myCell setSelectionStyle:UITableViewCellSelectionStyleNone];
            [myCell setDelegate:self];
            
            [[myCell btnStartDestination] setTitle:_itinerary.startStopName forState:UIControlStateNormal];
            [[myCell btnEndDestination  ] setTitle:_itinerary.endStopName   forState:UIControlStateNormal];
//            [myCell setEnd_stop_name  : _itinerary.endStopName  ];
            
            return myCell;
            
            break;
            
        default:
            
            return [self cellForSection: indexPath];
            
            break;
    }
    
    
//    static NSString *CellIdentifier = @"Cell";
//    UITableViewCell *cell = [thisTableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
//    
//    // Configure the cell...
//    
//    return cell;
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    switch (indexPath.section)
    {
        case 0:
            return 62.0f;
            break;
            
        default:
    
            return [self heightForSection: indexPath];
            break;
    }
    
}



-(CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{

    if ( section == 0 )
        return 0.0f;
    else
        return 22.0f;

}


-(UIView*) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{

    UILabel *headerLabel = [[UILabel alloc] init];
    [headerLabel setFont: [UIFont fontWithName:@"TrebuchetMS-Bold" size:17.0f] ];
    [headerLabel setTextColor: [UIColor whiteColor] ];

    
    // TODO: Prettify this so it doesn't make me want to bash my head against the desk.  Repeatedly.
    if ( [[_tableData titleForSection:section] isEqualToString:@"Favorites"] )
    {
        
//        UITableViewStandardHeaderLabel *label = [[UITableViewStandardHeaderLabel alloc] init];
//        
//        UIColor *gradient1 = [UIColor colorWithRed:13.0f/255.0f green:74.0f/255.0f  blue:26.0f/255.0f alpha:1.0f];
//        UIColor *gradient2 = [UIColor colorWithRed:26.0f/255.0f green:120.0f/255.0f blue:37.0f/255.0f alpha:0.8f];
//
//        NSArray *gradientArr = [NSArray arrayWithObjects:gradient2, gradient1, nil];

        [headerLabel setText:@"Favorites"];
        [headerLabel setBackgroundColor: [UIColor colorWithRed:13.0f/255.0f green:164.0f/255.0f blue:74.0f/255.0f alpha:0.6f]];

        return headerLabel;
        
//        [label setText:@"Favorites"];
//        [label setFont:[UIFont fontWithName:@"TrebuchetMS" size:20.0f] ];
//        [label setTextColor: [UIColor whiteColor] ];
//        
//        [label setLeftInset:3.0f];
//        [label addArrayOfColors: gradientArr];
//        
//        [label setBackgroundColor: [UIColor colorWithRed:13.0f/255.0f green:164.0f/255.0f blue:74.0f/255.0f alpha:1.0f] ];
//        
//        return label;
    }
    else if ( [[_tableData titleForSection:section] isEqualToString:@"Recent"] )
    {
//        UITableViewStandardHeaderLabel *label = [[UITableViewStandardHeaderLabel alloc] init];
//        
//        UIColor *gradient1 = [UIColor colorWithRed:13.0f/255.0f green:74.0f/255.0f  blue:26.0f/255.0f alpha:1.0f];
//        UIColor *gradient2 = [UIColor colorWithRed:26.0f/255.0f green:120.0f/255.0f blue:37.0f/255.0f alpha:0.8f];
//        
//        NSArray *gradientArr = [NSArray arrayWithObjects:gradient2, gradient1, nil];
//        
//        [label setText:@"Recent"];
//        [label setFont:[UIFont fontWithName:@"TrebuchetMS" size:20.0f] ];
//        [label setTextColor: [UIColor whiteColor] ];
//        
//        [label setLeftInset:3.0f];
//        [label addArrayOfColors: gradientArr];
//        
//        //        [label setBackgroundColor: [UIColor colorWithRed:13.0f/255.0f green:164.0f/255.0f blue:74.0f/255.0f alpha:1.0f] ];
//        
//        return label;
        
        [headerLabel setText:@"Recent"];
        [headerLabel setBackgroundColor: [UIColor colorWithRed:13.0f/255.0f green:164.0f/255.0f blue:74.0f/255.0f alpha:0.6f]];
        
        return headerLabel;
        
    }
    else if ( [[_tableData titleForSection:section] isEqualToString:@"Data"] )
    {
//        UITableViewStandardHeaderLabel *label = [[UITableViewStandardHeaderLabel alloc] init];
//        
//        UIColor *gradient3 = [UIColor colorWithRed:253.0f/255.0f green:78.0f/255.0f  blue:67.0f/255.0f alpha:1.0f];
//        UIColor *gradient4 = [UIColor colorWithRed:120.0f/255.0f green:39.0f/255.0f blue:34.0f/255.0f alpha:0.8f];
//        
//        NSArray *gradientArr = [NSArray arrayWithObjects:gradient3, gradient4, nil];
//
//        
//        [label setText:@"Next to Arrive Trains"];
//        [label setFont:[UIFont fontWithName:@"TrebuchetMS" size:20.0f] ];
//        [label setTextColor: [UIColor whiteColor] ];
//        
//        [label setLeftInset:3.0f];
//        [label addArrayOfColors: gradientArr];
//        
//        return label;

        [headerLabel setText:@"Next to Arrive Trains"];
        [headerLabel setBackgroundColor: [UIColor colorWithRed:13.0f/255.0f green:164.0f/255.0f blue:74.0f/255.0f alpha:0.6f]];
        
        return headerLabel;
        
    }
    else
        return nil;
    
}


-(CGFloat) tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 5.0f;
}


-(UIView*) tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{

    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 5.0f)];
    [footer setBackgroundColor: [UIColor clearColor] ];
    
    return footer;
    
}



#pragma - UITableView Helper Methods
-(id) cellForSection: (NSIndexPath*) indexPath
{

    static NSString *singleTripCell     = @"NextToArriveSingleTripCell";
    static NSString *connectionTripCell = @"NextToArriveConnectionTripCell";
    static NSString *tripHistoryCell    = @"NextToArriveTripHistoryCell";
    
    id myCell;
    if ( [[_tableData titleForSection:indexPath.section] isEqualToString:@"Favorites"] || [[_tableData titleForSection:indexPath.section] isEqualToString:@"Recent"] )
    {
        myCell = (NextToArriveTripHistoryCell*)[self.tableView dequeueReusableCellWithIdentifier: tripHistoryCell];

        NTASaveObject *saveObject = [_tableData objectForIndexPath:indexPath];
        
        [[myCell lblStartName] setText: [saveObject startStopName] ];
        [[myCell lblEndName]   setText: [saveObject endStopName]   ];
        
        return myCell;
    }
    else
    {
        NextToArrivaJSONObject *ntaObject = [_tableData objectForIndexPath: indexPath];
        
        if ( [ntaObject Connection] == nil )
        {
            myCell = (NextToArriveSingleTripCell*)[self.tableView dequeueReusableCellWithIdentifier: singleTripCell];
            [myCell updateCellUsingJsonData: ntaObject];

            //            NextToArrivaJSONObject *ntaObject = [_tableData objectForIndexPath:indexPath];

            // This is nice and all, but myCell objects are all UILabels, ntaObject objects are all strings.  Problem?  You bet!
//            [myCell setValuesForKeysWithDictionary: [ntaObject dictionaryWithValuesForKeys: [NSArray arrayWithObjects:@"orig_train", @"orig_arrival_time", @"orig_line", @"orig_departure_time", @"orig_delay", nil]] ];
            
        }
        else
        {
            myCell = (NextToArriveSingleTripCell*)[self.tableView dequeueReusableCellWithIdentifier: connectionTripCell];
            [myCell updateCellUsingJsonData: ntaObject];
        }
        
        
        return myCell;
    }

    
}


-(CGFloat) heightForSection: (NSIndexPath*) indexPath
{
    
    // TODO: Find a better way to do this, this happens very often
    if ( [[_tableData titleForSection:indexPath.section] isEqualToString:@"Favorites"] )
    {
        return 34.0f;
    }
    else if ( [[_tableData titleForSection:indexPath.section] isEqualToString:@"Recent"] )
    {
        return 34.0f;
    }
    else if ( [[_tableData titleForSection:indexPath.section] isEqualToString:@"Data"] )
    {
        
        NextToArrivaJSONObject *ntaObject = [_tableData objectForIndexPath: indexPath];
        
        if ( [ntaObject Connection] == nil )
            return 47.0f;
        else
            return 102.0f;
        
    }
    else  // Then it's Itinerary
        return 62.0f;
    
}



/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/


#pragma mark - UITableView Delete Rows
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    if ( editingStyle == UITableViewCellEditingStyleDelete )
    {
        
        if ( [[_tableData titleForSection:indexPath.section] isEqualToString:@"Itinerary"] )
        {
            NSLog(@"Clear the Itinerary Cells");
            [self clearItineraryCells];
        }
        else if ( [[_tableData titleForSection:indexPath.section] isEqualToString:@"Favorites"] )
        {
            NSLog(@"Forget Favorites");
            [self removeObjectAtIndexPath:indexPath];
        }
        else if ( [[_tableData titleForSection:indexPath.section] isEqualToString:@"Recent"] )
        {
            NSLog(@"Remove Recent");
            [self removeObjectAtIndexPath:indexPath];
        }
        
    }
    
}


- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ( [[_tableData titleForSection:indexPath.section] isEqualToString:@"Itinerary"] )
    {
        //        NSLog(@"Clear the Itinerary Cells");
        return YES;
    }
    else if ( [[_tableData titleForSection:indexPath.section] isEqualToString:@"Favorites"] )
    {
        //        NSLog(@"Forget Favorites");
        return YES;
    }
    else if ( [[_tableData titleForSection:indexPath.section] isEqualToString:@"Recent"] )
    {
        //        NSLog(@"Remove Recent");
        return YES;
    }
    
    return NO;
    
}


#pragma mark - UITableView Delete Helper Methods
-(void) clearItineraryCells
{
    [self invalidateTimer];
    
    // clear the _itineraryCompletion flag
    _itineraryCompletion = kNextToArriveNoButtonPressed;
    
    [_itinerary clearStops];
    [_itinerary setStartStopName: DEFAULT_MESSAGE];
    [_itinerary setEndStopName  : DEFAULT_MESSAGE];
    
    [self updateRefreshStatusWith: kNextToArriveRefreshStatusNoStops];
    
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationAutomatic];  // Itinerary is always at section 0
    
}


-(void) removeObjectAtIndexPath: (NSIndexPath *) indexPath
{
    
    [self.tableView beginUpdates];
    
    
    if ( [[_tableData titleForSection:indexPath.section] isEqualToString:@"Favorites"] )
    {
        [saveData makeSectionDirty: kNTASectionFavorites];
    }
    else if ( [[_tableData titleForSection:indexPath.section] isEqualToString:@"Recent"] )
    {
        [saveData makeSectionDirty: kNTASectionRecentlyViewed];
    }
    
    
    // Delete row only if there is more than one row in the table, others delete the entire section
    if ( [_tableData numOfRowsForSection: indexPath.section ] > 1 )
    {
        // Since there are at least 2 objects in Favorites, we can delete a row
        [_tableData removeObjectWithIndexPath: indexPath];
        [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
    else
    {
        // There is only 1 object remaining in Favorites, delete the section
//        [_tableData removeObjectWithIndexPath:indexPath];
        [_tableData removeSection: indexPath.section];
        [self.tableView deleteSections:[NSIndexSet indexSetWithIndex: indexPath.section ] withRowAnimation:UITableViewRowAnimationFade];
    }
    
    
    [self.tableView endUpdates];
    
    
}



#pragma mark - UITableView delegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{

    NSString *title = [_tableData titleForSection:indexPath.section];

    NTASaveSection selection = kNTASectionNone;
     
    if ( [title isEqualToString:@"Favorites"] )
    {
        selection = kNTASectionFavorites;
    }
    else if ( [title isEqualToString:@"Recent"] )
    {
        selection = kNTASectionRecentlyViewed;
    }
    
    
    
    if ( selection != kNTASectionNone )
    {
        
        NTASaveObject *sObject = [_tableData objectForIndexPath:indexPath];
        
        [_itinerary setStartStopName: [sObject startStopName] ];
        [_itinerary setEndStopName  : [sObject endStopName]   ];
        
        // A selection was made, whether it be in Favorites or Recent; update date
        [sObject setAddedDate:[NSDate date] ];
        
        [saveData makeSectionDirty: selection];
        
        // Sort Favorites/Recent with the new date
        [[_tableData objectForSectionWithTitle:title] sortUsingComparator: sortNextToArriveSaveObjectByDate];
        
        // Update the table view for just the Favorites/Recent section
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:[_tableData indexForSectionTitle:title] ] withRowAnimation:UITableViewRowAnimationAutomatic];
        
        // Indicate that both the Start and End buttons have been pressed
        _itineraryCompletion = kNextToArriveStartButtonPressed | kNextToArriveEndButtonPressed;
        
        // Then update the itinerary cell
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationAutomatic];
        
//        [self highlightRetrieveButton];
        [self updateRefreshStatusWith:kNextToArriveRefreshStatusReady];

        
    }



}


-(void) highlightRetrieveButton
{
    //    if ( self.btnRetrieveData.tintColor == [UIColor redColor] )
    //        [self.btnRetrieveData setTintColor:[UIColor blackColor] ];
    //    else
    
    //    REMenuItem *refreshItem = [[_menu items] objectAtIndex:0];
    //    [refreshItem setSubtitle:@"click to refresh data"];
    
    [self updateRefreshStatusWith:kNextToArriveRefreshStatusReady];
    
//    [self.btnRetrieveData setTintColor:[UIColor redColor] ];
    
}


#pragma mark - Buttons Pressed
-(void) backButtonPressed:(id) sender
{

    NSLog(@"Custom Back Button -- %@", sender);
//    [self dismissModalViewControllerAnimated:YES];  // Does not work
//    [self removeFromParentViewController];   // Does nothing!
//    [self.view removeFromSuperview];  // Removed from Superview but doesn't go back to previous VC
    
    
//    [self.navigationController removeFromParentViewController];  // Does not work, does not do anything

    [self.navigationController popViewControllerAnimated:YES];
    
}


#pragma mark - REMenu
-(void) dropDownMenuPressed:(id) sender
{
    
    
    if (_menu.isOpen)
    {
        [menuRefreshTimer invalidate];
        return [_menu close];
    }
    else
    {
        if ( ![menuRefreshTimer isValid] && [updateTimer isValid] )
            menuRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:0.5f target:self selector:@selector(menuRefreshUpdate:) userInfo:nil repeats:YES];
        
        if ( updateTimer != nil )
        {
            [self updateRefreshStatusWith:kNextToArriveRefreshStatusInUnknown];
        }
        
        
        [self updateFavoritesStatus];
        
//        CGRect rect = CGRectInset(self.view.frame, 5, 0);
        CGRect rect = CGRectInset(CGRectMake(0,0,self.view.frame.size.width, self.view.frame.size.height), 5, 0 );
        [_menu showFromRect:rect inView:self.view ];
        
    }
        
    
}


-(void) updateFavoritesStatus
{
    
    // Compare the list of Favorites to that of _itinerary

    NSArray *tempArr = [_tableData objectForSectionWithTitle:@"Favorites"];
    if (tempArr == nil)
    {
        
        if ( [_itinerary.startStopName isEqualToString:DEFAULT_MESSAGE] && [_itinerary.endStopName isEqualToString:DEFAULT_MESSAGE] )
            _favoriteStatus = kNextToArriveFavoriteSubtitleStatusUnknown;  // If either are not set, set status to unknown
        else
            _favoriteStatus = kNextToArriveFavoriteSubtitleNotAdded;  // If both have data, set not added for now.  We'll be checked for Added below.
        
    }
    
    
    for (NTASaveObject *sObject in [_tableData objectForSectionWithTitle:@"Favorites"] )
    {
        
        if ( [_itinerary.startStopName isEqualToString: [sObject startStopName] ] && [_itinerary.endStopName isEqualToString: [sObject endStopName] ] )
        {
            _favoriteStatus = kNextToArriveFavoriteSubtitleAdded;
            break;  // Once a match is found, no reason to continue searching
        }
        
    }
    

    // --==  Update Favorites subtitle
    REMenuItem *refreshItem = [[_menu items] objectAtIndex:1];
    NSString *status;
    
    switch (_favoriteStatus)
    {
            
        case kNextToArriveFavoriteSubtitleNotAdded:
            status = FAVORITE_SUBTITLE_ADD;
            break;
            
        case kNextToArriveFavoriteSubtitleAdded:
            status = FAVORITE_SUBTITLE_REMOVE;
            break;
        case kNextToArriveFavoriteSubtitleStatusUnknown:
            status = FAVORITE_SUBTITLE_NONE;
            break;
        default:
            break;
    }
    
    
    [refreshItem setSubtitle: status ];
    // If the _favoriteStatus is at "Added" then display the REMOVE message.  Likewise, if it's not "Added" display the Add Me message

    
}


-(void) menuRefreshUpdate: (NSTimer*) timer
{
    
    
    if ( [updateTimer isValid] )
    {
        NSTimeInterval seconds = [[updateTimer fireDate] timeIntervalSinceDate:[NSDate date] ];
        
        if ( seconds < 1.0f )
        {
            [self updateRefreshStatusWith:kNextToArriveRefreshStatusNow];
        }
        else
        {
            REMenuItem *refreshItem = [[_menu items] objectAtIndex:0];
            [refreshItem setSubtitle:[NSString stringWithFormat:@"refreshing in %d seconds", (int)round([[updateTimer fireDate] timeIntervalSinceDate:[NSDate date]]) ] ];
        }
        
    }  // if ( [updateTimer isValid] )
    
}


-(void)updateRefreshStatusWith:(NextToArriveRefreshStatusMessage) message
{
    
    REMenuItem *refreshItem = [[_menu items] objectAtIndex:0];
    
    switch (message)
    {
        case kNextToArriveRefreshStatusNoStops:
            [refreshItem setSubtitle:REFRESH_NO_STOPS];
            break;
            
        case kNextToArriveRefreshStatusInUnknown:
            [refreshItem setSubtitle:REFRESH_IN_UNKNOWN];
            break;
            
        case kNextToArriveRefreshStatusInXSecs:
            [refreshItem setSubtitle:REFRESH_IN_X_SECS];
            break;
            
        case kNextToArriveRefreshStatusNow:
            [refreshItem setSubtitle:REFRESH_NOW];
            break;
            
        case kNextToArriveRefreshStatusReady:
            [refreshItem setSubtitle:REFRESH_READY];
            break;
            
        default:
            break;
    }
    
}


#pragma mark - NextToArriveItineraryCellProtocol
-(void) itineraryButtonPressed:(NSInteger) buttonType
{
    
    StopNamesTableViewControllerSelectionType selType;
    switch (buttonType)
    {
            
        case kNextToArriveButtonTypeStart:
//            NSLog(@"NtATVC - start label pressed");
            
            // If the start label was pressed but the end is empty, then let's get the user to complete both of them.
//            if ( [_itinerary.endStopID intValue] <= 0 )
            if ( [_itinerary.startStopName isEqualToString: DEFAULT_MESSAGE] )
                selType = kNextToArriveSelectionTypeStartAndEnd;
            else
                selType = kNextToArriveSelectionTypeStart;
            
            break;
            
        case kNextToArriveButtonTypeEnd:
//            NSLog(@"NtATVC - end label pressed");
//            [self loadStopNamesVC];
            selType = kNextToArriveSelectionTypeEnd;
            break;
            
        case kNextToArriveButtonTypeStartEnd:
//            NSLog(@"NtATVC - start/end button pressed");
//            [self loadStopNamesVC];
            selType = kNextToArriveSelectionTypeStartAndEnd;
            break;
            
        case kNextToArriveButtonTypeReverse:
//            NSLog(@"NtATVC - reverse button pressed");
            _lastSelectedType = kNextToArriveSelectionNone;
            
            [_itinerary flipStops];
            
            [self updateItinerary];
            
//            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationAutomatic];
            
            return;
            break;
            
        default:
            // The code should never reach this point
            return;
            break;
    }
    
    
    _lastSelectedType = selType;
    
    NSString *storyboardName = @"StopNamesStoryboard";
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:storyboardName bundle:nil];
    StopNamesTableViewController *sntvc = (StopNamesTableViewController*)[storyboard instantiateInitialViewController];
    
    
    // Determine which route type
    RouteData *rData = [[RouteData alloc] init];
    [rData setRoute_type:[NSNumber numberWithInt:kGTFSRouteTypeRail] ];
    
    
    // Pass information to the stopNames VC
    [sntvc setStopData: rData];          // Contains: start/end stop names and id, along with routeType -- the data
    [sntvc setSelectionType: selType];   // Determines its behavior, whether to show only the start, end or both start/end stops information
    [sntvc setDelegate:self];
    
    [self.navigationController pushViewController:sntvc animated:YES];
    
}



#pragma mark - StopNameTableViewControllerProtocol
-(void) buttonPressed:(StopNamesTableViewControllerButtonPressed) buttonType withData:(StopNamesObject*) stopData
{
    
    // What happened in StopNames VC?  Was the Done button pressed, or was one of the cells selected by either a double tap or long press?
    // Or was the cancel button pressed?
    
//    NSLog(@"stopData: %@", stopData);
    
    switch (buttonType & kNextToArriveButtonMask)
    {
        case kNextToArriveButtonTypeDone:
        case kNextToArriveButtonTypeDoubleTap:
        case kNextToArriveButtonTypeLongPress:
            
            if ( buttonType & kNextToArriveButtonTypeStartField )
            {
                [_itinerary setStartStopID  : stopData.stop_id  ];
                [_itinerary setStartStopName: stopData.stop_name];
                
                _itineraryCompletion |= kNextToArriveStartButtonPressed;
            }
            else if ( buttonType & kNextToArriveButtonTypeEndField )
            {
                [_itinerary setEndStopID  : stopData.stop_id  ];
                [_itinerary setEndStopName: stopData.stop_name];
                
                _itineraryCompletion |= kNextToArriveEndButtonPressed;
            }

            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationAutomatic];
            
            break;
        case kNextToArriveButtonTypeCancel:
            break;
            
            
        default:
            break;
    }
 
    [self refreshJSONData];
    
}



//#pragma mark - Load Storyboards
//-(void) loadStopNamesVC
//{
//    
//
//    
//}


-(void) populateGTFSLookUp
{
    [replacement setObject:@"Norristown TC"         forKey:@"Norristown T.C."];
    [replacement setObject:@"Temple U"              forKey:@"Temple University"];
    [replacement setObject:@"Elm St"                forKey:@"Norristown"];
    [replacement setObject:@"Neshaminy Falls"       forKey:@"Neshaminy"];
    
    [replacement setObject:@"Mt Airy"               forKey:@"Mount Airy"];
    [replacement setObject:@"Morton"                forKey:@"Morton-Rutledge"];
    [replacement setObject:@"Main St"               forKey:@"Main Street"];
    [replacement setObject:@"Levittown"             forKey:@"Levittown-Tullytown"];
    
    [replacement setObject:@"Jenkintown-Wyncote"    forKey:@"Jenkintown Wyncote"];
    [replacement setObject:@"Highland Ave"          forKey:@"Highland Avenue"];
    [replacement setObject:@"Highland"              forKey:@"Highland Station"];
    [replacement setObject:@"Ft Washington"         forKey:@"Fort Washington"];
    
    [replacement setObject:@"Fernwood"              forKey:@"Fernwood-Yeadon"];
    [replacement setObject:@"Fern Rock TC"          forKey:@"Fern Rock T C"];
    [replacement setObject:@"Elwyn Station"         forKey:@"Elywn"];
    [replacement setObject:@"Eastwick Station"      forKey:@"Eastwick"];
    
    [replacement setObject:@"Churchmans Crossing"   forKey:@"Churchman's Crossing"];
    [replacement setObject:@"Chester TC"            forKey:@"Chester"];
    [replacement setObject:@"Airport Terminal E-F"  forKey:@"Airport Terminal E F"];
    [replacement setObject:@"Airport Terminal C-D"  forKey:@"Airport Terminal C D"];
    
    [replacement setObject:@"North Philadelphia"    forKey:@"North Philadelphia Amtrak"];
    [replacement setObject:@"Prospect Park"         forKey:@"Prospect Park - Moore"];
    [replacement setObject:@"Wayne Station"         forKey:@"Wayne"];
    [replacement setObject:@"Wayne Jct"             forKey:@"Wayne Junction"];
    
    [replacement setObject:@"49th St"               forKey:@"49th Street"];
}


#pragma mark - REMenu Selection
-(void) refreshJSONData
{
    
//    if ( (_buttonPressed & 0x03) != 3 )
//    {
//        // Both buttons have been pressed
//        return;
//    }
    
    if ( !( (_itineraryCompletion & kNextToArriveEndButtonPressed ) && ( _itineraryCompletion & kNextToArriveStartButtonPressed ) ) )
    {
        // Either the Start or End itinerary fields were not set
        return;
    }
    
    [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    
    NTASaveObject *sObject = [[NTASaveObject alloc] init];
    [sObject setStartStopName: _itinerary.startStopName];
    [sObject setEndStopName  : _itinerary.endStopName  ];
    
    NSInteger locatedAt;
    locatedAt = [saveData addObject: sObject intoSection: kNTASectionRecentlyViewed];
    NSLog(@"NTAVC - saveData, locatedAt: %d", locatedAt);  // if locatedAt == NSNotFound, it wasn't found in the recentlyViewed
    
//    [recentlyViewedSection sortUsingComparator:sortNTASaveObjectByDate];
    
    if ( ![[_tableData getSectionTitles] containsObject:@"Recent"] )
        [_tableData addSectionWithTitle:@"Recent"];
    
    [[_tableData objectForSectionWithTitle:@"Recent"] sortUsingComparator: sortNextToArriveSaveObjectByDate];
//    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex: [_tableData indexForSectionTitle:@"Recent"] ] withRowAnimation:UITableViewRowAnimationAutomatic];
    
    [self.tableView reloadData];
    
    [self invalidateTimer]; // Invalidate any timer that is already active.  If no timer is active, nothing happens
    [self getLatestJSONData];
    
}


-(void) selectedFavorites
{
    
    // _favoriteStatus is unknown
    if ( _favoriteStatus == kNextToArriveFavoriteSubtitleStatusUnknown )
        return;
    
    
    // The currente itinerary has been added to Favorites.  Click on it again will remove it
    if ( _favoriteStatus == kNextToArriveFavoriteSubtitleAdded )
    {
        
        NSIndexPath *indexPath;
        
        // Determine what indexPath the current favorites is at
//        if ( [_tableData numOfRowsForSection: [_tableData indexForSectionTitle:@"Favorites"] ] == 1 )
//            indexPath = [NSIndexPath indexPathForRow:0 inSection: [_tableData indexForSectionTitle:@"Favorites"] ];  // Well, that was easy
        
        
        int count = 0;  // Reading NSArray in sequential order
        for (NTASaveObject *sObject in [_tableData objectForSectionWithTitle:@"Favorites"] )
        {
            if ( [[sObject startStopName] isEqualToString:_itinerary.startStopName] && [[sObject endStopName] isEqualToString: _itinerary.endStopName] )
                indexPath = [NSIndexPath indexPathForRow:count inSection: [_tableData indexForSectionTitle:@"Favorites"] ];
            
            count++;
        }
        
        if ( indexPath != nil )
            [self removeObjectAtIndexPath:indexPath];
        
        return;
    }
    
    
    
    NTASaveObject *sObject = [[NTASaveObject alloc] init];
    [sObject setStartStopName: _itinerary.startStopName];
    [sObject setEndStopName  : _itinerary.endStopName  ];

    NSInteger locatedAt;
    locatedAt = [saveData addObject: sObject intoSection: kNTASectionFavorites];
    NSLog(@"NTAVC - saveData, locatedAt: %d", locatedAt);  // if locatedAt == NSNotFound, it wasn't found in the Favorites

//    NSLog(@"%@", _tableData);
    
    BOOL newSection = NO;
    if ( [_tableData objectForSectionWithTitle:@"Favorites"] == nil )
    {
        newSection = YES;
    }
        
    
    [_tableData addObject:sObject forTitle:@"Favorites"];
    
    [ [_tableData objectForSectionWithTitle:@"Favorites" ] sortUsingComparator:sortNextToArriveSaveObjectByDate];
    
    if ( newSection )
    {
        // Favorites always appears after Itineray but before Recent
        [_tableData moveSection:[_tableData indexForSectionTitle:@"Favorites"] afterSection:[_tableData indexForSectionTitle:@"Itinerary"] ];
        [self.tableView insertSections:[NSIndexSet indexSetWithIndex:[_tableData indexForSectionTitle:@"Favorites"] ] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    else
    {
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:[_tableData indexForSectionTitle:@"Favorites"] ] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    
//    [self.tableView reloadData];
    
}


NSComparisonResult (^sortNextToArriveSaveObjectByDate)(NTASaveObject*,NTASaveObject*) = ^(NTASaveObject *a, NTASaveObject *b)
{
    return [[b addedDate] compare: [a addedDate] ];
};


-(void) invalidateTimer
{
    
    if ( updateTimer != nil )
    {
        if ( [updateTimer isValid]  )
        {
            REMenuItem *refreshItem = [[_menu items] objectAtIndex:0];
            [refreshItem setSubtitle:@"click to refresh"];
            
            [updateTimer invalidate];
            updateTimer = nil;
        }
    }
    else
    {
        NSLog(@"NTAVC - Trying to send messages to updateTimer which no longer exists.");
    }
    
}


-(void) getLatestJSONData
{
    
    NSLog(@"DSTVC - getLatestBusJSONData");
    
    // Check for Internet connection
    Reachability *network = [Reachability reachabilityForInternetConnection];
    if ( ![network isReachable] )
        return;  // Don't bother continuing if no internet connection is available
    
    
    // If start and end points haven't been entered, do nothing
    //    if ( ( _startObject.stop_name == nil ) || ( _endObject.stop_name == nil ) )
    //    _startStopName = [[[_tData data] objectAtIndex:0] objectAtIndex:0];
    //    _endStopName   = [[[_tData data] objectAtIndex:0] objectAtIndex:1];
    
    
    NSString *startStopName = [self fixMismatchedStopName: [_itinerary startStopName] ];
    NSString *endStopName   = [self fixMismatchedStopName: [_itinerary endStopName] ];
    
    
    if ( ( startStopName == nil ) || ( endStopName == nil ) )
        return;
    
    if ( _stillWaitingOnWebRequest )  // The attempt here is to avoid asking the web server for data if it hasn't returned anything from the previous request
        return;
    else
        _stillWaitingOnWebRequest = YES;
    
    
    NSString *_newStartStop = [self fixMismatchedStopName: startStopName];
    NSString *_newEndStop   = [self fixMismatchedStopName: endStopName];
    
    //        NSString* stringURL = [NSString stringWithFormat:@"http://www3.septa.org/hackathon/NextToArrive/%@/%@/10", _startStopName, _endStopName];
    
    NSString* stringURL = [NSString stringWithFormat:@"http://www3.septa.org/hackathon/NextToArrive/%@/%@/50", _newStartStop, _newEndStop];
    
    
    NSString* webStringURL = [stringURL stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSLog(@"NTAVC - getLatestRailJSONData -- api url: %@", webStringURL);
    
    [SVProgressHUD showWithStatus:@"Loading..."]
    ;
    
    _jsonOp = [[NSBlockOperation alloc] init];
    
    __weak NSBlockOperation *weakOp = _jsonOp;
    [weakOp addExecutionBlock:^{
        
        NSData *realTimeTrainInfo = [NSData dataWithContentsOfURL:[NSURL URLWithString:webStringURL] ];
        
        if ( ![weakOp isCancelled] )
        {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                [self processJSONData:realTimeTrainInfo];
            }];
        }
        else
        {
            NSLog(@"FNRVC - getLatestJSONData: _jsonOp cancelled");
        }
        
    }];
    
    [_jsonQueue addOperation: _jsonOp];
    
    
    //        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul), ^{
    //
    //            NSData *realTimeTrainInfo = [NSData dataWithContentsOfURL:[NSURL URLWithString:webStringURL] ];
    //            [self performSelectorOnMainThread:@selector(processJSONData:) withObject: realTimeTrainInfo waitUntilDone:YES];
    //            
    //        });
    
}


-(NSString *) fixMismatchedStopName: (NSString*) stopName;
{
    
    // Unfortunately, at the time of writing this method, there are a few stop names in the GTFS file
    // that do not match up with the stop name of an internal SEPTA database.  As such, this method
    // looks for one of those stop names and replaces it with one that matches the internal name.
    
    // P.S. This is horrible code, if anyone asks, I'll deny ever writing in.
    //   Ran php jarowinkler | egrep -v 100% to find the gasps between the GTFS and internal naming.
    
    NSString *temp = [replacement objectForKey:stopName];
    
    if ( temp != nil )
    {
        NSLog(@"NTAVC - fixMismatchedStopName: replacing %@ with %@", stopName, temp);
        return temp;
    }
    else
        return stopName;
    
}



-(void) kickOffAnotherJSONRequest
{
    
    if ( _killAllTimers )
    {
        [self invalidateTimer];
        return;
    }
    
    NSLog(@"NTAVC - kickOffAnotherJSONRequest");
    updateTimer =[NSTimer scheduledTimerWithTimeInterval:JSON_REFRESH_RATE
                                                  target:self
                                                selector:@selector(getLatestJSONData)
                                                userInfo:nil
                                                 repeats:NO];
}


-(void) processJSONData:(NSData*) returnedData
{
    
    [SVProgressHUD dismiss];
    _stillWaitingOnWebRequest = NO;
    
    
    if ( returnedData == nil )  // If we didn't even receive data, try again in another JSON_REFRESH_RATE seconds
    {
        [self kickOffAnotherJSONRequest];
        return;
    }
    
    //    NSMutableArray *tableData;  // Array of NextToArrivaJSONObjects
    //    tableData = [[NSMutableArray alloc] init];
    
//    [ntaDataSection removeAllObjects];
    
    
    NSMutableArray *myData;
    myData = [[NSMutableArray alloc] init];
    
    
    // This method is called once the realtime positioning data has been returned via the API is stored in data
    NSError *error;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData: returnedData options:kNilOptions error:&error];

    
    if ( json == nil || error != nil )  // Something bad happened, so just return
    {
        [self kickOffAnotherJSONRequest];  // And before we return, let's try again in JSON_REFRESH_RATE seconds
        return;
    }
    
    
    for (NSDictionary *data in json)
    {
        
        if ( [_jsonOp isCancelled] )
            return;
        
        NextToArrivaJSONObject *ntaObject = [[NextToArrivaJSONObject alloc] init];
        
        [ntaObject setConnection: [data objectForKey:@"Connection"] ];
        [ntaObject setIsdirect: [data objectForKey:@"isdirect"] ];
        
        
        NSString *time = [data objectForKey:@"orig_arrival_time"];
        [ntaObject setOrig_arrival_time: [time stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet] ] ];
        [ntaObject setOrig_delay: [data objectForKey:@"orig_delay"] ];
        
        
        time = [data objectForKey:@"orig_departure_time"];
        [ntaObject setOrig_departure_time: [time stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet] ] ];
        
        [ntaObject setOrig_line: [data objectForKey:@"orig_line"] ];
        [ntaObject setOrig_train: [data objectForKey:@"orig_train"] ];
        
        time = [data objectForKey:@"term_arrival_time"];
        [ntaObject setTerm_arrival_time: [time stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet] ] ];
        
        [ntaObject setTerm_delay: [data objectForKey:@"term_delay"] ];
        
        time = [data objectForKey:@"term_depart_time"];
        [ntaObject setTerm_depart_time: [time stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet] ] ];
        
        [ntaObject setTerm_line: [data objectForKey:@"term_line"] ];
        [ntaObject setTerm_train: [data objectForKey:@"term_train"] ];
        
            [myData addObject:ntaObject];
//        [_tableData addObject: ntaObject];  // Because we cleared the @"Data" above, the _tableData internal indexPath is pointing to the @"Data" section
        
    }
    

    if ( [_tableData indexForSectionTitle:@"Data"] < 0 )
    {
        [_tableData addSectionWithTitle:@"Data"];
    }
    
    [_tableData clearSectionWithTitle:@"Data"];
    
    [_tableData replaceArrayWith: myData forTitle:@"Data"];
    _launchUpdateTimer = YES;
    
    // Only start the timer for the next JSON request after 
    [self kickOffAnotherJSONRequest];
    
    
    //    [self sortDataWithIndex: _previousIndex];
    [self.tableView reloadData];
    
}




#pragma mark - Gestures
- (IBAction)longPressRecognized:(UILongPressGestureRecognizer*)sender
{
    // Since a long press is triggered before a tap, a LP on a favorite or recent will not actually load any data into the start/end fields
    // Do that now
    //    NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
    
    UILongPressGestureRecognizer *gesture = (UILongPressGestureRecognizer*) sender;
    
    if ( gesture.state == UIGestureRecognizerStateBegan )
    {
//        NSLog(@"NtATVC - Began");
        CGPoint touchPoint = [sender locationInView: self.view];
        NSIndexPath *row = [self.tableView indexPathForRowAtPoint:touchPoint];
        
        [self tableView:self.tableView didSelectRowAtIndexPath:row];
        [self refreshJSONData];
        
//        NSLog(@"NtATVC - loading data in indexPath: %@", row);
    }
    else if ( gesture.state == UIGestureRecognizerStateRecognized )
    {
//        NSLog(@"NtATVC - Recognized");
        
    }
    else if ( gesture.state == UIGestureRecognizerStateEnded )
    {
//        NSLog(@"NtATVC - Ended");
    }

}


//- (IBAction)doubleTapRecognized:(id)sender1
//{
//    //    [self refreshJSONData];
//    
//    NSLog(@"Double Tab");
//    
//}

#pragma mark - Fare ViewController
-(void) loadFareVC
{
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"FareStoryboard" bundle:nil];
    FareViewController *fVC = (FareViewController*)[storyboard instantiateInitialViewController];
    [self.navigationController pushViewController: fVC animated: YES];
    
}

@end