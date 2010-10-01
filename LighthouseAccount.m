#import "LighthouseAccount.h"
#import <GTM/GTMBase64.h>
#import <GData/GDataHTTPFetcher.h>

static NSString *const kLighthouseURLString = @"http://lighthouseapp.com/";
static NSString *const kLighthouseAccountTypeName = @"com.google.qsb.lighthouse.account";
static NSString *const kLighthouseAccountProjectIDKey = @"LighthouseAccountProjectIDKey";

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

- (id)initWithConfiguration:(NSDictionary *)prefDict {
  if ((self = [super initWithConfiguration:prefDict])) {
    NSString *projectID = [prefDict objectForKey:kLighthouseAccountProjectIDKey];
    if ([projectID length]) {
      projectID_ = [projectID copy];
    } else {
      HGSLog(@"Missing project ID");
      [self release];
      self = nil;
    }
  }
  return self;
}

- (NSString *)type {
  return kLighthouseAccountTypeName;
}

#pragma mark Account Editing

- (void)authenticate {
  NSString *domainName = [self userName];
  NSString *token = [self password];
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

- (BOOL)authenticateWithPassword:(NSString *)token
                    andProjectID: (NSString *)projectID {
  BOOL authenticated = NO;
  // Test this account to see if we can connect.
  NSString *domainName = [self userName];
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

- (BOOL)authenticateWithPassword:(NSString *)token {
  NSString *projectID = [self projectID];
  return [self authenticateWithPassword:token andProjectID: projectID];
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

- (NSDictionary *)configuration {
  NSDictionary *parentConfig = [super configuration];
  NSMutableDictionary *accountDict = [NSMutableDictionary dictionaryWithDictionary:parentConfig];
  [accountDict setObject:[self projectID] forKey:kLighthouseAccountProjectIDKey];
  return accountDict;
}

#pragma mark GDataHTTPFetcher Delegate Methods

- (void)authSetFetcher:(GDataHTTPFetcher *)fetcher
      finishedWithData:(NSData *)data {
  NSURLResponse *response = [fetcher response];
  BOOL authenticated = [self validateResponse:response];
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
