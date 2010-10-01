
#import "SetUpLighthouseAccountViewController.h"
#import <Vermilion/Vermilion.h>
#import <Vermilion/HGSKeychainItem.h>
#import "LighthouseAccount.h"

@implementation SetUpLighthouseAccountViewController

@synthesize domainName  = domainName_;
@synthesize accessToken = accessToken_;
@synthesize projectID   = projectID_;

- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil {
  self = [super initWithNibName:nibNameOrNil
                         bundle:nibBundleOrNil
               accountTypeClass:[LighthouseAccount class]];
  return self;
}

- (void)dealloc {
  [domainName_ release];
  [accessToken_ release];
  [projectID_ release];
  [super dealloc];
}

- (IBAction)acceptSetupAccountSheet:(id)sender {
  NSWindow *sheet = [sender window];
  NSString *domainName = [self domainName];
  if ([domainName length] > 0) {
    NSString *token     = [self accessToken];
    NSString *projectID = [self projectID];

    LighthouseAccount *newAccount = [[[LighthouseAccount alloc] initWithName:domainName] autorelease];
    [self setAccount:newAccount];

    BOOL isGood = NO;

    isGood = [newAccount authenticateWithAccessToken:token
                                        andProjectID:projectID];
    [newAccount setAuthenticated:isGood];
    [newAccount setProjectID:projectID];
    [newAccount setAccessToken:token];

    if (isGood) {
      // Install the account.
      HGSAccountsExtensionPoint *accountsPoint = [HGSExtensionPoint accountsPoint];
      isGood = [accountsPoint extendWithObject:newAccount];
      if (isGood) {
        [NSApp endSheet:sheet];
        NSString *summary
        = NSLocalizedString(@"Enable searchable items for this account.",
                            @"A dialog title telling the user that they "
                            @"should enable some searchable items for "
                            @"the account they just set up.");
        NSString *format
        = NSLocalizedString(@"One or more search sources may have been "
                            @"added for the account '%@'. It may be "
                            @"necessary to manually enable each search "
                            @"source that uses this account.  Do so via "
                            @"the 'Searchable Items' tab in Preferences.",
                            @"A dialog label telling the user in detail "
                            @"how they should enable some searchable items "
                            @"for the account they just set up.");
        [self presentMessageOffWindow:[self parentWindow]
                          withSummary:summary
                    explanationFormat:format
                           alertStyle:NSInformationalAlertStyle];
        
        [self setDomainName:nil];
        [self setAccessToken:nil];
        [self setProjectID:nil];
      } else {
        HGSLogDebug(@"Failed to install account extension for account '%@'.",
                    domainName);
      }
    } else {
      NSString *summary = NSLocalizedString(@"Could not authenticate that "
                                            @"account.", 
                                            @"A dialog title denoting that "
                                            @"we were unable to authenticate "
                                            @"the account with the user info "
                                            @"given to us".);
      NSString *format
      = NSLocalizedString(@"The account '%@' could not be authenticated. "
                          @"Please check the account name and password "
                          @"and try again.", 
                          @"A dialog label explaining in detail that "
                          @"we were unable to authenticate the account "
                          @"with the user info given to us".);
      [self presentMessageOffWindow:sheet
                        withSummary:summary
                  explanationFormat:format
                         alertStyle:NSWarningAlertStyle];
    }
  }
}

- (IBAction)cancelSetupAccountSheet:(id)sender {
  [self setDomainName:nil];
  [self setAccessToken:nil];
  [self setProjectID:nil];
  [super cancelSetupAccountSheet:sender];
}

- (IBAction)openLighthouseHomePage:(id)sender {
  BOOL success = [LighthouseAccount openLighthouseHomePage];
  if (!success) {
    NSBeep();
  }
}

- (void)presentMessageOffWindow:(NSWindow *)parentWindow
                    withSummary:(NSString *)summary
              explanationFormat:(NSString *)format
                     alertStyle:(NSAlertStyle)style {
  NSString *domainName = [self domainName];
  NSString *explanation = [NSString stringWithFormat:format, domainName];
  [self presentMessageOffWindow:parentWindow
                    withSummary:summary
                    explanation:explanation
                     alertStyle:style];
}

@end
