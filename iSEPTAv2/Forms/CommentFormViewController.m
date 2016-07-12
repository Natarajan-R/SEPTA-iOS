//
//  CommentFormViewController.m
//  iSEPTA
//
//  Created by septa on 1/7/15.
//  Copyright (c) 2015 SEPTA. All rights reserved.
//

#import "CommentFormViewController.h"
#import "CustomerServiceForm.h"

//@interface CommentFormViewController ()
//
//@end

@implementation CommentFormViewController

- (void)awakeFromNib
{
    //set up form
    self.formController.form = [[CustomerServiceForm alloc] init];
}


- (void)updateFields
{
    //refresh the form
    self.formController.form = self.formController.form;
    [self.tableView reloadData];
}

- (void)submitRegistrationForm:(UITableViewCell<FXFormFieldCell> *)cell
{
    //we can lookup the form from the cell if we want, like this:
//    CustomerServiceForm *form = cell.field.form;
    
    CustomerServiceForm *form = cell.field.form;
    NSDictionary *dict;
    
    if ( [form validateForm] )
    {
        
        dict = [form dictionaryWithValuesForKeys: [CustomerServiceForm returnAllKeyValues] ];
        NSError *error = nil;
        
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
        if ( jsonData )
        {
            // process the data
            
            NSString *filteredName;
            NSString *filteredPhone;
            NSString *filteredEmail;
            NSString *filteredDate;
            NSString *filteredLocation;
            NSString *filteredRoute;
            NSString *filteredVehicle;
            NSString *filteredBlock;
            NSString *filteredTime;
            NSString *filteredDestination;
            NSString *filteredMode;
            NSString *filteredCommentType;
            NSString *filteredEmployee;  // First textarea
            NSString *filteredComments;  // Details (second) textarea

            
            filteredName  = [NSString stringWithFormat:@"%@ %@", form.firstName, form.lastName];
            filteredPhone = form.phoneNumber;
            
            filteredEmail = form.emailAddress;
            
            NSString *dateString = [NSDateFormatter localizedStringFromDate: form.date
                                                                  dateStyle:NSDateFormatterShortStyle
                                                                  timeStyle:NSDateFormatterFullStyle];
            filteredDate  = dateString;
            
            filteredLocation = form.where;
            filteredMode     = form.mode;
            filteredRoute    = form.route;


//            filteredName  = [[NSString stringWithFormat:@"%@ %@", form.firstName, form.lastName] stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
//            filteredPhone = [form.phoneNumber stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
//            
//            filteredEmail = [form.emailAddress stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
//            
//            NSString *dateString = [NSDateFormatter localizedStringFromDate: form.date
//                                                                  dateStyle:NSDateFormatterShortStyle
//                                                                  timeStyle:NSDateFormatterFullStyle];
//            filteredDate  = [dateString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
//            
//            filteredLocation = [form.where stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
//            filteredMode     = [form.mode stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
//            filteredRoute  = [form.route stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            
//            filteredVehicle = [form.vehicle stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
//            filteredBlock   = [form.blockTrain stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            
            
//            NSString *version = [NSString stringWithFormat:@"Version %@",[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
            NSString *appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
            NSString *iosVersion = [UIDevice currentDevice].systemVersion;
            
            NSString *addedComment = [NSString stringWithFormat:@"%@.\n\nThis was sent from the SEPTA App, version: %@, iOS version: %@", form.comment, appVersion, iosVersion];
            
            filteredComments    = addedComment;
            filteredDestination = form.destination;
            
//            filteredComments = [addedComment stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
//            filteredDestination = [form.destination stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

            NSString *body;
            
            body = [NSString stringWithFormat:
                    @"Name=%@\nphone=%@\nemail=%@\nIncident Date=%@\nBoarding Location=%@\nroute=%@\nvehicle=%@\nblock=%@\nTime of Incident=%@\nFinal Destination=%@\nComment=%@\nEmployee=%@\nComments=%@\nMode=%@\n", filteredName, filteredPhone, filteredEmail, filteredDate, filteredLocation, filteredRoute, filteredVehicle, filteredBlock, filteredTime, filteredDestination, filteredCommentType, filteredEmployee, filteredComments, filteredMode];
            
            if ( [MFMailComposeViewController canSendMail] )
            {
                
                MFMailComposeViewController *mailViewController = [[MFMailComposeViewController alloc] init];
                mailViewController.mailComposeDelegate = self;
                
                [mailViewController setSubject:
                    [NSString stringWithFormat:@"SEPTA App (v%@) Comment Form",
                        [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]
                     ]
                 ];
                
                // cservice@septa.org
                [mailViewController setToRecipients:[NSArray arrayWithObject:@"cservice@septa.org"] ];
                
                [mailViewController setMessageBody:body isHTML:NO];
                
                //            if ( attachmentImage != nil )
                //            {
                //                NSData *myData = UIImagePNGRepresentation( attachmentImage );
                //
                //                NSString *name = @"Untitled.png";
                //                //                if ( [imageElement imageNamed] != nil )
                //                //                    name = [imageElement imageValueNamed];
                //                //
                //                [mailViewController addAttachmentData:myData mimeType:@"image/png" fileName: name ];
                //            }
                
                [self presentViewController:mailViewController animated:YES completion:nil];
                
            }
                        
            
//            filteredEmployee = [form.employee_description stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
//            NSString *urlString = @"http://www.septa.org/cs/comment/FormMail.cgi";
//            
//            // Removed the ? from the beginning of POST string
//            NSString *postString = [NSString stringWithFormat:@"recipient=cservice%%40septa.org&wl_tp=Empolyee%%2CComments&subject=Inquiry+from+www.septa.org&required=Name%%2Cemail%%2Cphone&Name=%@&phone=%@&email=%@&Incident+Date=%@&Boarding+Location=%@&route=%@&vehicle=%@&block=%@&Time+of+Incident=%@&Final+Destination=%@&Comment=%@&Employee=%@&Comments=%@&Mode=%@", filteredName, filteredPhone, filteredEmail, filteredDate, filteredLocation, filteredRoute, filteredVehicle, filteredBlock, filteredTime, filteredDestination, filteredCommentType, filteredEmployee, filteredComments, filteredMode];
////            NSString *postString = [NSString stringWithFormat:@"recipient=ybaudru%%40septa.org&wl_tp=Empolyee%%2CComments&subject=Inquiry+from+www.septa.org&required=Name%%2Cemail%%2Cphone&Name=%@&phone=%@&email=%@&Incident+Date=%@&Boarding+Location=%@&route=%@&vehicle=%@&block=%@&Time+of+Incident=%@&Final+Destination=%@&Comment=%@&Employee=%@&Comments=%@&Mode=%@", filteredName, filteredPhone, filteredEmail, filteredDate, filteredLocation, filteredRoute, filteredVehicle, filteredBlock, filteredTime, filteredDestination, filteredCommentType, filteredEmployee, filteredComments, filteredMode];
//            
//            NSData *postData = [postString dataUsingEncoding:NSUTF8StringEncoding];
//            NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL: [NSURL URLWithString:urlString] ];
//            
//            
//            [request setHTTPMethod:@"POST"];
//            [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"content-type"];
//            [request setHTTPBody:postData];
//            
//            
//            NSHTTPURLResponse *urlResponse;
//            NSError *error;
//            NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&urlResponse error:&error];
//            
//            int statusCode = (int)[urlResponse statusCode];
//            int errorCode = (int)error.code;
//            
//            NSLog(@"urlString : %@", urlString);
//            NSLog(@"postString: %@", postString);
//            
//            NSLog(@"status: %d, errorCode: %d", statusCode, errorCode);
//            NSString *dataStr = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
//            NSString *content = [NSString stringWithUTF8String:[responseData bytes] ];
//            NSLog(@"response: %@", dataStr);
//            NSLog(@"content : %@", content);
//            
//            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Thank You!" message:@"Your comment has been submitted." delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
//            [alert show];
            
        }
        else
        {
            NSLog(@"Unable to serialize the data %@: %@", dict, error);
            return;
        }
        
    }
    
    //we can then perform validation, etc
//    if (form.agreedToTerms)
//    {
//        [[[UIAlertView alloc] initWithTitle:@"Registration Form Submitted" message:nil delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil] show];
//    }
//    else
//    {
//        [[[UIAlertView alloc] initWithTitle:@"User Error" message:@"Please agree to the terms and conditions before proceeding" delegate:nil cancelButtonTitle:nil otherButtonTitles:@"Yes Sir!", nil] show];
//    }

}





//- (void)viewDidLoad {
//    [super viewDidLoad];
//    // Do any additional setup after loading the view.
//}
//
//- (void)didReceiveMemoryWarning {
//    [super didReceiveMemoryWarning];
//    // Dispose of any resources that can be recreated.
//}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/



#pragma mark - MailComposer
-(void) mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    
    // Notifies users about errors associated with the interface
    switch (result)
    {
        case MFMailComposeResultCancelled:
            NSLog(@"Result: canceled");
            break;
        case MFMailComposeResultSaved:
            NSLog(@"Result: saved");
            break;
        case MFMailComposeResultSent:
            NSLog(@"Result: sent");
            break;
        case MFMailComposeResultFailed:
            NSLog(@"Result: failed");
            break;
        default:
            NSLog(@"Result: not sent");
            break;
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];
}




@end
