#import "SetUpLighthouseAccountViewController.h"
#import "LighthouseAccount.h"

@implementation SetUpLighthouseAccountViewController

@synthesize projectID = projectID_;

- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil {
  self = [super initWithNibName:nibNameOrNil
                         bundle:nibBundleOrNil
               accountTypeClass:[LighthouseAccount class]];
  return self;
}

- (IBAction)acceptSetupAccountSheet:(id)sender {
  //  JDW: This won't work, because the account hasn't been created yet.
  //  // Set the projectID so we can use it to authenticate the account.
  //  LighthouseAccount *account = ((LighthouseAccount*) [self account]);
  //  [account setProjectID:[self projectID]];
  [super acceptSetupAccountSheet:sender];
}

- (IBAction)openLighthouseHomePage:(id)sender {
  BOOL success = [LighthouseAccount openLighthouseHomePage];
  if (!success) {
    NSBeep();
  }
}

@end
