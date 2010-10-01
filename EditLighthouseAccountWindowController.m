#import "EditLighthouseAccountWindowController.h"
#import <Vermilion/Vermilion.h>
#import "LighthouseAccount.h"

@implementation EditLighthouseAccountWindowController

@synthesize domainName  = domainName_;
@synthesize accessToken = accessToken_;
@synthesize projectID   = projectID_;

- (void)dealloc {
  [domainName_ release];
  [accessToken_ release];
  [projectID_ release];
  [super dealloc];
}

- (void)awakeFromNib {
  LighthouseAccount *account = (LighthouseAccount *)[self account];
  NSString *domainName  = [account userName];
  NSString *accessToken = [account password];
  NSString *projectID   = [account projectID];
  [self setDomainName:domainName];
  [self setAccessToken:accessToken];
  [self setProjectID:projectID];
}

- (IBAction)acceptEditAccountSheet:(id)sender {
  NSWindow *sheet = [self window];
  NSString *accessToken = [self accessToken];
  NSString *projectID   = [self projectID];
  LighthouseAccount *account = (LighthouseAccount *)[self account];
  if ([account authenticateWithPassword:accessToken andProjectID:projectID]) {
    [account setPassword:accessToken];
    [account setProjectID:projectID];
    [NSApp endSheet:sheet];
    [account setAuthenticated:YES];
  } else {
    NSString *summaryFormat = NSLocalizedString(@"Could not set up that %@ "
                                                @"account.", 
                                                @"A dialog title denoting that "
                                                @"we were unable to set up the "
                                                @"%@ account");
    NSString *summary = [NSString stringWithFormat:summaryFormat,
                         [account type]];
    NSString *explanationFormat
    = NSLocalizedString(@"The %1$@ account '%2$@' could not be set up for "
                        @"use.  Please check your password and try "
                        @"again.", 
                        @"A dialog label explaining in detail that we could "
                        @"not set up an account of type 1 with username 2.");
    NSString *explanation = [NSString stringWithFormat:explanationFormat,
                             [account type],
                             [account userName]];
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert setMessageText:summary];
    [alert setInformativeText:explanation];
    [alert beginSheetModalForWindow:sheet
                      modalDelegate:self
                     didEndSelector:nil
                        contextInfo:nil];
  }
}

- (IBAction)openLighthouseHomePage:(id)sender {
  BOOL success = [LighthouseAccount openLighthouseHomePage];
  if (!success) {
    NSBeep();
  }
}

@end

