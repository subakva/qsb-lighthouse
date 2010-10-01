//
//  LighthouseTicketAction.m
//
//  Copyright (c) 2009 Google Inc. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are
//  met:
//
//    * Redistributions of source code must retain the above copyright
//  notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above
//  copyright notice, this list of conditions and the following disclaimer
//  in the documentation and/or other materials provided with the
//  distribution.
//    * Neither the name of Google Inc. nor the names of its
//  contributors may be used to endorse or promote products derived from
//  this software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
//  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
//  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
//  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
//  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
//  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import <Vermilion/Vermilion.h>
#import <GTM/GTMMethodCheck.h>
#import <GTM/GTMNSString+URLArguments.h>
#import <Vermilion/HGSKeychainItem.h>
#import <GData/GDataHTTPFetcher.h>
#import "LighthouseAccount.h"

static NSString *const kCreateTicketURLFormat = @"https://%@.lighthouseapp.com/projects/%@/tickets.xml";
static NSString *const kMessageBodyFormat = @"<?xml version='1.0' encoding='UTF-8'?>"
"<ticket>"
"  <body>%@</body>"
"  <title>%@</title>"
"  <tag>qsb</tag>"
"</ticket>";

// An action that will create a new ticket for a Lighthouse account.
//
@interface LighthouseCreateTicketAction : HGSAction <HGSAccountClientProtocol> {
 @private
  HGSSimpleAccount *account_;
}

// Called by performWithInfo: to actually send the message.
- (void)createLighthouseTicket:(NSString *)ticketTitle;

// Utility function to send notification so user can be notified of
// success or failure.
- (void)informUserWithDescription:(NSString *)description
                      successCode:(NSInteger)successCode;
- (void)loginCredentialsChanged:(NSNotification *)notification ;
- (void)ticketFetcher:(GDataHTTPFetcher *)fetcher
    finishedWithData:(NSData *)data;
- (void)ticketFetcher:(GDataHTTPFetcher *)fetcher
     failedWithError:(NSError *)error;
@end


@implementation LighthouseCreateTicketAction

GTM_METHOD_CHECK(NSString, gtm_stringByEscapingForURLArgument);

- (id)initWithConfiguration:(NSDictionary *)configuration {
  if ((self = [super initWithConfiguration:configuration])) {
    account_ = [[configuration objectForKey:kHGSExtensionAccountKey] retain];
    if (account_) {
      // Watch for credential changes.
      NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
      [nc addObserver:self
             selector:@selector(loginCredentialsChanged:)
                 name:kHGSAccountDidChangeNotification
               object:account_];
    } else {
      HGSLogDebug(@"Missing account identifier for LighthouseTicketAction '%@'",
                  [self identifier]);
      [self release];
      self = nil;
    }
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [account_ release];
  [super dealloc];
}

- (BOOL)performWithInfo:(NSDictionary*)info {
  HGSResultArray *directObjects
    = [info objectForKey:kHGSActionDirectObjectsKey];
  BOOL success = NO;
  if (directObjects) {
    // Pull something out of |directObjects| that can be turned into a ticket.
    NSString *message = [directObjects displayName];
    [self createLighthouseTicket:message];
    success = YES;
  }
  return success;
}

- (void)createLighthouseTicket:(NSString *)ticketTitle {
  if (ticketTitle) {
    // NSString *trimmedTicketTitle = [ticketTitle stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    HGSKeychainItem* keychainItem
      = [HGSKeychainItem keychainItemForService:[account_ identifier]
                                       username:nil];
    NSString *username = [keychainItem username];
    NSString *password = [keychainItem password];
    LighthouseAccount *account = ((LighthouseAccount*) account_);
    NSString *projectID = [account projectID];

    if (username && password) {
      if ([ticketTitle length] > 140) {
        NSString *warningString
          = HGSLocalizedString(@"Message too long - truncated.",
                               @"A dialog label explaining that their Lighthouse "
                               @"message was too long and was truncated");
        [self informUserWithDescription:warningString
                            successCode:kHGSUserMessageWarningType];
        ticketTitle = [ticketTitle substringToIndex:140];
      }

      NSString *encodedMessage
        = [ticketTitle gtm_stringByEscapingForURLArgument];
      NSString *encodedMessageBody
        = [NSString stringWithFormat:kMessageBodyFormat, encodedMessage, encodedMessage];
      NSString *sendStatusString = [NSString stringWithFormat:kCreateTicketURLFormat,
                                    username,
                                    projectID];
      NSURL *sendStatusURL = [NSURL URLWithString:sendStatusString];

      // Construct an NSMutableURLRequest for the URL and set appropriate
      // request method.
      NSMutableURLRequest *sendStatusRequest
        = [NSMutableURLRequest requestWithURL:sendStatusURL
                                  cachePolicy:NSURLRequestReloadIgnoringCacheData
                              timeoutInterval:15.0];
      [sendStatusRequest setHTTPMethod:@"POST"];
      [sendStatusRequest setHTTPShouldHandleCookies:NO];
      [sendStatusRequest setValue:@"application/xml" forHTTPHeaderField:@"Content-Type"];
      [sendStatusRequest setValue:password forHTTPHeaderField:@"X-LighthouseToken"];

      // Set request body, if specified (hopefully so), with 'source'
      // parameter if appropriate.
      NSData *bodyData = [encodedMessageBody dataUsingEncoding:NSUTF8StringEncoding];
      [sendStatusRequest setHTTPBody:bodyData];

      GDataHTTPFetcher* ticketFetcher = [GDataHTTPFetcher httpFetcherWithRequest:sendStatusRequest];
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
      errorString = [NSString stringWithFormat:errorString, username];
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

- (void)loginCredentialsChanged:(NSNotification *)notification {
  HGSAccount *account = [notification object];
  HGSAssert(account == account_, @"Notification from bad account!");
}

#pragma mark HGSAccountClientProtocol Methods

- (BOOL)accountWillBeRemoved:(HGSAccount *)account {
  HGSAssert(account == account_, @"Notification from bad account!");
  return YES;
}

@end
