
#import <Vermilion/Vermilion.h>
#import <GTM/GTMMethodCheck.h>
#import <GTM/GTMNSString+URLArguments.h>
#import <Vermilion/HGSKeychainItem.h>
#import <GData/GDataHTTPFetcher.h>
#import "LighthouseAccount.h"

// The URL path format for creating a ticket.
static NSString *const kLighthouseProjectsPathFormat = @"/projects/%@/tickets.xml";

// The XML format for creating a new ticket.
static NSString *const kMessageBodyFormat
  = @"<?xml version='1.0' encoding='UTF-8'?>"
"<ticket>"
"  <body>%@</body>"
"  <title>%@</title>"
"  <tag>qsb</tag>"
"</ticket>";

@interface LighthouseCreateTicketAction : HGSAction <HGSAccountClientProtocol> {
 @private
  HGSSimpleAccount *account_;
}

// Sends a request to create the new ticket.
- (void)createLighthouseTicket:(NSString *)ticketTitle;

// Displays a message (Growl).
- (void)informUserWithDescription:(NSString *)description
                      successCode:(NSInteger)successCode;

// Delegate method to handle a response from the API.
- (void)ticketFetcher:(GDataHTTPFetcher *)fetcher
    finishedWithData:(NSData *)data;

// Delegate method to handle failure to get a response from the API.
- (void)ticketFetcher:(GDataHTTPFetcher *)fetcher
     failedWithError:(NSError *)error;
@end


@implementation LighthouseCreateTicketAction

// Ensures that there is an account.
- (id)initWithConfiguration:(NSDictionary *)configuration {
  if ((self = [super initWithConfiguration:configuration])) {
    account_ = [[configuration objectForKey:kHGSExtensionAccountKey] retain];
    if (!account_) {
      HGSLogDebug(@"Missing account identifier for LighthouseTicketAction '%@'",
                  [self identifier]);
      [self release];
      self = nil;
    }
  }
  return self;
}

- (void)dealloc {
  [account_ release];
  [super dealloc];
}

/*!
 Called when the user invokes the action. If there is text available, it
 tries to create a ticket.
 */
- (BOOL)performWithInfo:(NSDictionary*)info {
  HGSResultArray *directObjects = [info objectForKey:kHGSActionDirectObjectsKey];
  BOOL success = NO;
  if (directObjects) {
    NSString *message = [directObjects displayName];
    [self createLighthouseTicket:message];
    success = YES;
  }
  return success;
}

/*!
 Create a new ticket with the specified text.
 */
- (void)createLighthouseTicket:(NSString *)ticketTitle {
  if (ticketTitle) {
    LighthouseAccount *account = ((LighthouseAccount*) account_);

    if (account) {
      NSString *messageBody = [NSString stringWithFormat:kMessageBodyFormat,
                               ticketTitle,
                               ticketTitle];
      NSData *bodyData = [messageBody dataUsingEncoding:NSUTF8StringEncoding];
      
      NSMutableURLRequest *createTicketRequest
        = [LighthouseAccount createAuthenticatedRequestFor:kLighthouseProjectsPathFormat
                                                   account:account];
      [createTicketRequest setHTTPMethod:@"POST"];
      [createTicketRequest setHTTPBody:bodyData];

      GDataHTTPFetcher* ticketFetcher = [GDataHTTPFetcher httpFetcherWithRequest:createTicketRequest];
      [ticketFetcher setIsRetryEnabled:YES];
      [ticketFetcher setCookieStorageMethod:kGDataHTTPFetcherCookieStorageMethodFetchHistory];
      [ticketFetcher beginFetchWithDelegate:self
                         didFinishSelector:@selector(ticketFetcher:
                                                     finishedWithData:)
                           didFailSelector:@selector(ticketFetcher:
                                                     failedWithError:)];
    } else {
      NSString *errorString
        = HGSLocalizedString(@"Could not create ticket. Please check the password for "
                             @"account %@",
                             @"A dialog label explaining that the user could "
                             @"not send their Lighthouse data due to a bad "
                             @"password for account %@");
      errorString = [NSString stringWithFormat:errorString, [account domainName]];
      [self informUserWithDescription:errorString
                          successCode:kHGSUserMessageWarningType];
      HGSLog(@"LighthouseTicketAction failed due to missing keychain item "
             @"for account '%@'.", [account_ displayName]);
    }
  }
}

- (void)ticketFetcher:(GDataHTTPFetcher *)fetcher
    finishedWithData:(NSData *)data {
  NSInteger statusCode = [fetcher statusCode];
  if (statusCode == 201) {
    NSString *successString
      = HGSLocalizedString(@"Ticket created!",
                           @"A dialog label explaining that the user's message "
                           @"has been successfully sent to Lighthouse");
    [self informUserWithDescription:successString
                        successCode:kHGSUserMessageNoteType];
  } else {
    NSString *errorFormat
      = HGSLocalizedString(@"Could not create ticket! (%d)",
                           @"A dialog label explaining to the user that we could "
                           @"not create the ticket. %d is an status code.");
    NSString *errorString = [NSString stringWithFormat:errorFormat, statusCode];
    [self informUserWithDescription:errorString
                        successCode:kHGSUserMessageErrorType];
    HGSLog(@"LighthouseTicketAction failed to create ticket for account '%@': "
           @"status=%d.", [account_ displayName], statusCode);
  }
}

- (void)ticketFetcher:(GDataHTTPFetcher *)fetcher
     failedWithError:(NSError *)error {
  NSString *errorFormat
    = HGSLocalizedString(@"Could not create ticket! (%d)",
                         @"A dialog label explaining to the user that we could "
                         @"not create the ticket. %d is an error code.");
  NSString *errorString = [NSString stringWithFormat:errorFormat,
                           [error code]];
  [self informUserWithDescription:errorString
                      successCode:kHGSUserMessageErrorType];
  HGSLog(@"Failed request with error: %@", error);
  HGSLog(@"LighthouseTicketAction failed to create ticket for account '%@': "
         @"error=%d '%@'.",
         [account_ displayName], [error code], [error localizedDescription]);
}

- (void)informUserWithDescription:(NSString *)description
                      successCode:(NSInteger)successCode {
  NSBundle *bundle = HGSGetPluginBundle();
  NSString *path = [bundle pathForResource:@"Lighthouse" ofType:@"icns"];
  NSImage *lighthouseT
    = [[[NSImage alloc] initByReferencingFile:path] autorelease];
  NSString *summary
    = HGSLocalizedString(@"Lighthouse",
                         @"A dialog title. Lighthouse is a product name");
  HGSUserMessenger *messenger = [HGSUserMessenger sharedUserMessenger];
  [messenger displayUserMessage:summary
                    description:description
                           name:@"LighthousePluginMessage"
                          image:lighthouseT
                           type:successCode];
}

- (BOOL)accountWillBeRemoved:(HGSAccount *)account {
  HGSAssert(account == account_, @"Notification from bad account!");
  return YES;
}

@end
