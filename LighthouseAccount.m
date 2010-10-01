
#import "LighthouseAccount.h"
#import <GTM/GTMBase64.h>
#import <GData/GDataHTTPFetcher.h>

static NSString *const kLighthouseURLString = @"http://lighthouseapp.com/";
static NSString *const kLighthouseAccountTypeName = @"com.subakva.qsb.lighthouse.account";
static NSString *const kLighthouseAccountProjectIDKey = @"LighthouseAccountProjectIDKey";
static NSString *const kLighthouseAuthURLFormat = @"https://%@.lighthouseapp.com/projects/%@.xml";
static NSString *const kLighthouseAuthHeaderName = @"X-LighthouseToken";

static const NSTimeInterval kAuthenticationRetryInterval = 0.1;
static const NSTimeInterval kAuthenticationGiveUpInterval = 30.0;
static const NSTimeInterval kAuthenticationTimeOutInterval = 15.0;

@interface LighthouseAccount ()

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

/*!
 Contains the credentials for a lighthouse account and methods for
 authenticating a set of credentials.
 */
@implementation LighthouseAccount

@synthesize authCompleted = authCompleted_;
@synthesize authSucceeded = authSucceeded_;
@synthesize projectID     = projectID_;

/*!
 Overrides the initWithConfiguration to load the project ID from the
 preferences dictionary.
 */
- (id)initWithConfiguration:(NSDictionary *)prefDict {
  if ((self = [super initWithConfiguration:prefDict])) {
    NSString *projectID = [prefDict objectForKey:kLighthouseAccountProjectIDKey];
    if ([projectID length]) {
      projectID_    = [projectID copy];
    } else {
      HGSLog(@"Missing project ID");
      [self release];
      self = nil;
    }
  }
  return self;
}

/*!
 Overrides the configuration to include the projectId.
 
 This is used by the parent class when writing out the account preferences.
 */
- (NSDictionary *)configuration {
  NSDictionary *parentConfig = [super configuration];
  NSMutableDictionary *accountDict = [NSMutableDictionary dictionaryWithDictionary:parentConfig];
  [accountDict setObject:[self projectID] forKey:kLighthouseAccountProjectIDKey];
  return accountDict;
}

/*!
 Returns the type name of the Lighthouse account.
 
 This is used by QSB as the name of this account type. It shows up in the user
 preferences, and possibly in other places.
 */
- (NSString *)type {
  return kLighthouseAccountTypeName;
}

/*!
 Sets the accessToken as the password on the keychain item.
 */
- (void) setAccessToken:(NSString *) token {
  [self setPassword:token];
}

/*!
 Returns the password (from the keychain item) as the accessToken.
 */
- (NSString *) accessToken {
  return [self password];
}

/*!
 Returns the userName (from the keychain item) as the domainName.
 */
- (NSString *) domainName {
  return [self userName];
}

/*!
 Builds an request with all the appropriate headers for authenticating an
 account.
 
 This is called by the various authenticate methods.
 */
- (NSMutableURLRequest *)buildAuthRequestFor:(NSString *) domainName
                               accessToken:(NSString *) token
                                 projectID:(NSString *) projectID {
  NSString *authURLWithDomain = [NSString
                                 stringWithFormat:kLighthouseAuthURLFormat,
                                 domainName,
                                 projectID];
  NSURL *authURL = [NSURL URLWithString:authURLWithDomain];
  NSMutableURLRequest *authRequest
  = [NSMutableURLRequest requestWithURL:authURL
                            cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                        timeoutInterval:kAuthenticationTimeOutInterval];
  [authRequest setHTTPShouldHandleCookies:NO];
  [authRequest addValue:token forHTTPHeaderField:kLighthouseAuthHeaderName];
  return authRequest;
}

/*!
 Starts an asynchronous authentication request to check whether the account
 credentials are valid.

 The responses to the asynchronous HTTP fetcher are handled by delagate methods
 on this class: 
    authSetFetcher:finishedWithData:
    authSetFetcher:failedWithError:

 This is called by something inside QSB, but I haven't looked into it.
 */
- (void)authenticate {
  NSMutableURLRequest *authRequest = [self buildAuthRequestFor:[self domainName]
                                                   accessToken:[self accessToken]
                                                     projectID:[self projectID]];
  GDataHTTPFetcher *authSetFetcher = [GDataHTTPFetcher httpFetcherWithRequest:authRequest];
  [authSetFetcher setIsRetryEnabled:YES];
  [authSetFetcher setCookieStorageMethod:kGDataHTTPFetcherCookieStorageMethodFetchHistory];
  [authSetFetcher beginFetchWithDelegate:self
                       didFinishSelector:@selector(authSetFetcher:finishedWithData:)
                         didFailSelector:@selector(authSetFetcher:failedWithError:)];
}

/*!
 See authenticateWithAccessToken:andProjectID:
 */
- (BOOL)authenticateWithPassword:(NSString *)token {
  NSString *projectID = [self projectID];
  return [self authenticateWithAccessToken:token andProjectID: projectID];
}

/*!
 Performs a pseudo-synchronous request to check whether the given token and
 project ID are valid for the domainName. Internally, this method performs an
 asynchronous HTTP request. It starts a run loop, checking for a response every
 0.1 secondes (kAuthenticationRetryInterval). It gives up on the request after
 polling for 30 seconds (kAuthenticationGiveUpInterval).

 The responses to the asynchronous HTTP fetcher are handled by delagate methods
 on this class: 
    authFetcher:finishedWithData:
    authFetcher:failedWithError:

 This method is called when checking credentials that were entered into one of
 the account management UIs.
 */
- (BOOL)authenticateWithAccessToken:(NSString *)token
                       andProjectID:(NSString *)projectID {
  NSMutableURLRequest *authRequest = [self buildAuthRequestFor:[self domainName]
                                                   accessToken:token
                                                     projectID:projectID];
  [self setAuthCompleted:NO];
  [self setAuthSucceeded:NO];

  GDataHTTPFetcher* authFetcher =
    [GDataHTTPFetcher httpFetcherWithRequest:authRequest];
  [authFetcher setIsRetryEnabled:YES];
  [authFetcher
    setCookieStorageMethod:kGDataHTTPFetcherCookieStorageMethodFetchHistory];
  [authFetcher beginFetchWithDelegate:self
                    didFinishSelector:@selector(authFetcher:finishedWithData:)
                      didFailSelector:@selector(authFetcher:failedWithError:)];
  NSTimeInterval endTime =
    [NSDate timeIntervalSinceReferenceDate] + kAuthenticationGiveUpInterval;

  NSRunLoop* loop = [NSRunLoop currentRunLoop];
  while (![self authCompleted]) {
    NSDate *sleepTilDate =
      [NSDate dateWithTimeIntervalSinceNow:kAuthenticationRetryInterval];
    [loop runUntilDate:sleepTilDate];
    if ([NSDate timeIntervalSinceReferenceDate] > endTime) {
      [authFetcher stopFetching];
      [self setAuthCompleted:YES];
    }
  }
  return [self authSucceeded];
}

/*!
 Checks the content of the response to determine whether the account
 credentials are valid. In this case, we assume that the credentials are valid
 if we get a 200 response code from the Lighthouse API when request project
 data.

 This is called by the finishedWithData delegate methods when any of the HTTP
 fetchers get a response.
 */
- (BOOL)validateResponse:(NSURLResponse *)response {
  BOOL valid = NO;
  if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
    NSHTTPURLResponse *httpURLResponse = (NSHTTPURLResponse *)response;
    NSInteger statusCode = [httpURLResponse statusCode];
    valid = (statusCode == 200);
  }
  return valid;
}

/*!
 Opens the Lighthouse home page in a web browser.
 
 This is called by the account UI when the user clicks on the Lighthouse icon.
 */
+ (BOOL)openLighthouseHomePage {
  NSURL *lighthouseURL = [NSURL URLWithString:kLighthouseURLString];
  BOOL success = [[NSWorkspace sharedWorkspace] openURL:lighthouseURL];
  return success;
}

/*!
 Delegate handler for a data response during an asynchronous authentication
 request. If this is called by the fetcher, it means that the authentication
 process has completed. The account may have been authenticated,
 depending on whether the content of the response is valid.

 This is called by the fetcher when a response is received from the server.
 */
- (void)authSetFetcher:(GDataHTTPFetcher *)fetcher
      finishedWithData:(NSData *)data {
  NSURLResponse *response = [fetcher response];
  BOOL authenticated = [self validateResponse:response];
  [self setAuthenticated:authenticated];
}

/*!
 Delegate handler for an error response during an asynchronous authentication
 request. If this is called by the fetcher, it means that the authentication
 process has failed. The assumption is that the account is not authenticated
 in this case.

 This is called by the fetcher when it is unable to get a response from the
 server.
 */
- (void)authSetFetcher:(GDataHTTPFetcher *)fetcher
       failedWithError:(NSError *)error {
  HGSLogDebug(@"Authentication failed for account '%@' (%@), error: '%@' (%d)",
              [self userName], [self type], [error localizedDescription],
              [error code]);
  [self setAuthenticated:NO];
}

/*!
 Delegate handler for a data response during a pseudo-synchronous
 authentication request. If this is called by the fetcher, it means that the
 authentication process has completed. The account may have been authenticated,
 depending on whether the content of the response is valid.

 This is called by the fetcher when a response is received from the server.
 */
- (void)authFetcher:(GDataHTTPFetcher *)fetcher
   finishedWithData:(NSData *)data {
  NSURLResponse *response = [fetcher response];
  BOOL authenticated = [self validateResponse:response];
  [self setAuthCompleted:YES];
  [self setAuthSucceeded:authenticated];
}

/*!
 Delegate handler for an error response during a pseudo-synchronous
 authentication request. If this is called by the fetcher, it means that the
 authentication process has completed, but the account has not been
 authenticated.

 This is called by the fetcher when it is unable to get a response from the
 server.
 */
- (void)authFetcher:(GDataHTTPFetcher *)fetcher
    failedWithError:(NSError *)error {
  HGSLogDebug(@"Authentication failed for account '%@' (%@), error: '%@' (%d)",
              [self userName], [self type], [error localizedDescription],
              [error code]);
  [self setAuthCompleted:YES];
  [self setAuthSucceeded:NO];
}

@end
