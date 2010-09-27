#import "EditLighthouseAccountWindowController.h"
#import "LighthouseAccount.h"

@implementation EditLighthouseAccountWindowController

@synthesize projectID = projectID_;

- (IBAction)openLighthouseHomePage:(id)sender {
  BOOL success = [LighthouseAccount openLighthouseHomePage];
  if (!success) {
    NSBeep();
  }
}

- (IBAction)acceptEditAccountSheet:(id)sender {
  //  JDW: This won't work, because the account hasn't been created yet.
  //  // Set the projectID so we can use it to authenticate the account.
  //  LighthouseAccount *account = ((LighthouseAccount*) [self account]);
  //  [account setProjectID:[self projectID]];
  [super acceptEditAccountSheet:sender];
}

@end
