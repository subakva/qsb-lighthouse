//
//  LighthouseAccount.m
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

#import "LighthouseAccount.h"
#import <GTM/GTMBase64.h>
#import <GData/GDataHTTPFetcher.h>

static NSString *const kLighthouseURLString = @"http://lighthouseapp.com/";
static NSString *const kLighthouseAccountTypeName = @"com.google.qsb.lighthouse.account";

// Authentication timing constants.
static const NSTimeInterval kAuthenticationRetryInterval = 0.1;
static const NSTimeInterval kAuthenticationGiveUpInterval = 30.0;
static const NSTimeInterval kAuthenticationTimeOutInterval = 15.0;


@interface LighthouseAccount ()

// Check the authentication response to see if the token is valid.
- (BOOL)validateResponse:(NSURLResponse *)response;

// Add the token to the custom HTTP authorization header.
- (void)addAuthenticationToRequest:(NSMutableURLRequest *)request
                          token:(NSString *)token;

// Open lighthouseapp.com in the user's preferred browser.
+ (BOOL)openLighthouseHomePage;

- (void)authSetFetcher:(GDataHTTPFetcher *)fetcher
      finishedWithData:(NSData *)data;
- (void)authSetFetcher:(GDataHTTPFetcher *)fetcher
       failedWithError:(NSError *)error;
- (void)authFetcher:(GDataHTTPFetcher *)fetcher
   finishedWithData:(NSData *)data;
- (void)authFetcher:(GDataHTTPFetcher *)fetcher
    failedWithError:(NSError *)error;

@property (nonatomic, assign) BOOL authCompleted;
@property (nonatomic, assign) BOOL authSucceeded;

@end

@implementation LighthouseAccount

@synthesize authCompleted = authCompleted_;
@synthesize authSucceeded = authSucceeded_;
@synthesize projectID = projectID_;

- (NSString *)type {
  return kLighthouseAccountTypeName;
}

#pragma mark Account Editing

- (void)authenticate {
  NSString *domainName = [self userName];
  NSString *token = [self password];
  NSString *authURLWithDomain = [NSString stringWithFormat:@"https://%@.lighthouseapp.com/projects.xml", domainName];
  NSURL *authURL = [NSURL URLWithString:authURLWithDomain];
  NSMutableURLRequest *authRequest
    = [NSMutableURLRequest requestWithURL:authURL
                              cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                          timeoutInterval:kAuthenticationTimeOutInterval];
  if (authRequest) {
    [authRequest setHTTPShouldHandleCookies:NO];
    if ([domainName length]) {
      [self addAuthenticationToRequest:authRequest
                              token:token];
    }
    GDataHTTPFetcher* authSetFetcher
      = [GDataHTTPFetcher httpFetcherWithRequest:authRequest];
    [authSetFetcher setIsRetryEnabled:YES];
    [authSetFetcher
     setCookieStorageMethod:kGDataHTTPFetcherCookieStorageMethodFetchHistory];
    [authSetFetcher beginFetchWithDelegate:self
                         didFinishSelector:@selector(authSetFetcher:
                                                     finishedWithData:)
                           didFailSelector:@selector(authSetFetcher:
                                                     failedWithError:)];
  }
}

- (BOOL)authenticateWithPassword:(NSString *)token {
  BOOL authenticated = NO;
  // Test this account to see if we can connect.
  NSString *domainName = [self userName];
  NSString *projectID = [self projectID];
  NSString *authURLWithDomain = [NSString
                                 stringWithFormat:@"https://%@.lighthouseapp.com/project/%@.xml",
                                 domainName,
                                 projectID];
  NSURL *authURL = [NSURL URLWithString:authURLWithDomain];
  NSMutableURLRequest *authRequest
    = [NSMutableURLRequest requestWithURL:authURL
                              cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                          timeoutInterval:kAuthenticationTimeOutInterval];
  if (authRequest) {
    [authRequest setHTTPShouldHandleCookies:NO];
    if (domainName) {
      [self addAuthenticationToRequest:authRequest
                              token:token];
    }
    [self setAuthCompleted:NO];
    [self setAuthSucceeded:NO];
    GDataHTTPFetcher* authFetcher
      = [GDataHTTPFetcher httpFetcherWithRequest:authRequest];
    [authFetcher setIsRetryEnabled:YES];
    [authFetcher
     setCookieStorageMethod:kGDataHTTPFetcherCookieStorageMethodFetchHistory];
    [authFetcher beginFetchWithDelegate:self
                      didFinishSelector:@selector(authFetcher:
                                                  finishedWithData:)
                        didFailSelector:@selector(authFetcher:
                                                  failedWithError:)];
    // Block until this fetch is done to make it appear synchronous. Sleep
    // for a second and then check again until is has completed.  Just in
    // case, put an upper limit of 30 seconds before we bail.
    NSTimeInterval endTime
      = [NSDate timeIntervalSinceReferenceDate] + kAuthenticationGiveUpInterval;
    NSRunLoop* loop = [NSRunLoop currentRunLoop];
    while (![self authCompleted]) {
      NSDate *sleepTilDate
        = [NSDate dateWithTimeIntervalSinceNow:kAuthenticationRetryInterval];
      [loop runUntilDate:sleepTilDate];
      if ([NSDate timeIntervalSinceReferenceDate] > endTime) {
        [authFetcher stopFetching];
        [self setAuthCompleted:YES];
      }
    }
    authenticated = [self authSucceeded];
  }
  return authenticated;
}

- (BOOL)validateResponse:(NSURLResponse *)response {
  BOOL valid = NO;
  if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
    NSHTTPURLResponse *httpURLResponse = (NSHTTPURLResponse *)response;
    NSInteger statusCode = [httpURLResponse statusCode];
    // A 200 means verified, a 401 means not verified.
    valid = (statusCode == 200);
  }
  return valid;
}

- (void)addAuthenticationToRequest:(NSMutableURLRequest *)request
                          token:(NSString *)token {
  [request addValue:token forHTTPHeaderField:@"X-LighthouseToken"];
}

+ (BOOL)openLighthouseHomePage {
  NSURL *lighthouseURL = [NSURL URLWithString:kLighthouseURLString];
  BOOL success = [[NSWorkspace sharedWorkspace] openURL:lighthouseURL];
  return success;
}

- (void)storeProjectID:(BOOL) authenticated {
  if (authenticated) {
    //  // If the account is authenticated, check that there is a project ID, and add it to the
    //  // account.
    //  LighthouseAccount *account = ((LighthouseAccount*) [self account]);
    //  if ([account isAuthenticated]) {
    //    [account setProjectID:[self projectID]];
    ////    NSString *message = [NSString stringWithFormat:@"projectID = %@", projectID];
    ////    NSRunAlertPanel(@"Debug", message, @"OK", @"Cancel",nil);
    //  }

//    [[self configuration] setObject:[self projectID] forKey:@"LighthouseAccountProjectIDKey"];

    // TODO: set the project id in a properties file
  }  
}

#pragma mark GDataHTTPFetcher Delegate Methods

- (void)authSetFetcher:(GDataHTTPFetcher *)fetcher
      finishedWithData:(NSData *)data {
  NSURLResponse *response = [fetcher response];
  BOOL authenticated = [self validateResponse:response];
  [self storeProjectID:authenticated];
  [self setAuthenticated:authenticated];
}

- (void)authSetFetcher:(GDataHTTPFetcher *)fetcher
       failedWithError:(NSError *)error {
  HGSLogDebug(@"Authentication failed for account '%@' (%@), error: '%@' (%d)",
              [self userName], [self type], [error localizedDescription],
              [error code]);
  [self setAuthenticated:NO];
}

- (void)authFetcher:(GDataHTTPFetcher *)fetcher
   finishedWithData:(NSData *)data {
  NSURLResponse *response = [fetcher response];
  BOOL authenticated = [self validateResponse:response];
  [self storeProjectID:authenticated];  
  [self setAuthCompleted:YES];
  [self setAuthSucceeded:authenticated];
}

- (void)authFetcher:(GDataHTTPFetcher *)fetcher
    failedWithError:(NSError *)error {
  HGSLogDebug(@"Authentication failed for account '%@' (%@), error: '%@' (%d)",
              [self userName], [self type], [error localizedDescription],
              [error code]);
  [self setAuthCompleted:YES];
  [self setAuthSucceeded:NO];
}

@end
