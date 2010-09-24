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

static NSString *const kMessageBodyFormat = @"status=%@";
static NSString *const kSendStatusFormat
  = @"https://lighthouse.com/statuses/update.xml?"
    @"source=googlequicksearchboxmac&status=%@";

// An action that will send a status update message for a Lighthouse account.
//
@interface LighthouseSendMessageAction : HGSAction <HGSAccountClientProtocol> {
 @private
  HGSSimpleAccount *account_;
}

// Called by performWithInfo: to actually send the message.
- (void)sendLighthouseStatus:(NSString *)lighthouseMessage;

// Utility function to send notification so user can be notified of
// success or failure.
- (void)informUserWithDescription:(NSString *)description
                      successCode:(NSInteger)successCode;
- (void)loginCredentialsChanged:(NSNotification *)notification ;
- (void)tweetFetcher:(GDataHTTPFetcher *)fetcher
    finishedWithData:(NSData *)data;
- (void)tweetFetcher:(GDataHTTPFetcher *)fetcher
     failedWithError:(NSError *)error;
@end


@implementation LighthouseSendMessageAction

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
    // Pull something out of |directObjects| that can be turned into a tweet.
    NSString *message = [directObjects displayName];
    [self sendLighthouseStatus:message];
    success = YES;
  }
  return success;
}

- (void)sendLighthouseStatus:(NSString *)lighthouseMessage {
  if (lighthouseMessage) {
    HGSKeychainItem* keychainItem
      = [HGSKeychainItem keychainItemForService:[account_ identifier]
                                       username:nil];
    NSString *username = [keychainItem username];
    NSString *password = [keychainItem password];
    if (username && password) {
      if ([lighthouseMessage length] > 140) {
        NSString *warningString
          = HGSLocalizedString(@"Message too long - truncated.",
                               @"A dialog label explaining that their Lighthouse "
                               @"message was too long and was truncated");
        [self informUserWithDescription:warningString
                            successCode:kHGSUserMessageWarningType];
        lighthouseMessage = [lighthouseMessage substringToIndex:140];
      }

      NSString *encodedMessage
        = [lighthouseMessage gtm_stringByEscapingForURLArgument];
      NSString *encodedMessageBody
        = [NSString stringWithFormat:kMessageBodyFormat, encodedMessage];
      NSString *sendStatusString = [NSString stringWithFormat:kSendStatusFormat,
                                    encodedMessage];
      NSURL *sendStatusURL = [NSURL URLWithString:sendStatusString];

      // Construct an NSMutableURLRequest for the URL and set appropriate
      // request method.
      NSMutableURLRequest *sendStatusRequest
        = [NSMutableURLRequest requestWithURL:sendStatusURL
                                  cachePolicy:NSURLRequestReloadIgnoringCacheData
                              timeoutInterval:15.0];
      [sendStatusRequest setHTTPMethod:@"POST"];
      [sendStatusRequest setHTTPShouldHandleCookies:NO];
      [sendStatusRequest setValue:@"QuickSearchBox"
               forHTTPHeaderField:@"X-Lighthouse-Client"];
      [sendStatusRequest setValue:@"1.0.0"
               forHTTPHeaderField:@"X-Lighthouse-Client-Version"];
      [sendStatusRequest setValue:@"http://www.google.com/qsb-mac"
               forHTTPHeaderField:@"X-Lighthouse-Client-URL"];

      // Set request body, if specified (hopefully so), with 'source'
      // parameter if appropriate.
      NSData *bodyData
        = [encodedMessageBody dataUsingEncoding:NSUTF8StringEncoding];
      [sendStatusRequest setHTTPBody:bodyData];

      GDataHTTPFetcher* tweetFetcher
        = [GDataHTTPFetcher httpFetcherWithRequest:sendStatusRequest];
      [tweetFetcher setIsRetryEnabled:YES];
      [tweetFetcher
       setCookieStorageMethod:kGDataHTTPFetcherCookieStorageMethodFetchHistory];
      [tweetFetcher setCredential:
       [NSURLCredential credentialWithUser:username
                                  password:password
                               persistence:NSURLCredentialPersistenceNone]];
      [tweetFetcher beginFetchWithDelegate:self
                         didFinishSelector:@selector(tweetFetcher:
                                                     finishedWithData:)
                           didFailSelector:@selector(tweetFetcher:
                                                     failedWithError:)];
    } else {
      NSString *errorString
        = HGSLocalizedString(@"Could not tweet. Please check the password for "
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

- (void)tweetFetcher:(GDataHTTPFetcher *)fetcher
    finishedWithData:(NSData *)data {
  NSInteger statusCode = [fetcher statusCode];
  if (statusCode == 200) {
    NSString *successString
      = HGSLocalizedString(@"Message tweeted!",
                           @"A dialog label explaning that the user's message "
                           @"has been successfully sent to Lighthouse");
    [self informUserWithDescription:successString
                        successCode:kHGSUserMessageNoteType];
  } else {
    NSString *errorFormat
      = HGSLocalizedString(@"Could not tweet! (%d)",
                           @"A dialog label explaining to the user that we could "
                           @"not tweet. %d is an status code.");
    NSString *errorString = [NSString stringWithFormat:errorFormat, statusCode];
    [self informUserWithDescription:errorString
                        successCode:kHGSUserMessageErrorType];
    HGSLog(@"LighthouseTicketAction failed to tweet for account '%@': "
           @"status=%d.", [account_ displayName], statusCode);
  }
}

- (void)tweetFetcher:(GDataHTTPFetcher *)fetcher
     failedWithError:(NSError *)error {
  NSString *errorFormat
    = HGSLocalizedString(@"Could not tweet! (%d)",
                         @"A dialog label explaining to the user that we could "
                         @"not tweet. %d is an error code.");
  NSString *errorString = [NSString stringWithFormat:errorFormat,
                           [error code]];
  [self informUserWithDescription:errorString
                      successCode:kHGSUserMessageErrorType];
  HGSLog(@"LighthouseTicketAction failed to tweet for account '%@': "
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
