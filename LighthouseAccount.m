#import "LighthouseAccount.h"
#import <GTM/GTMBase64.h>
#import <GData/GDataHTTPFetcher.h>

static NSString *const kLighthouseURLString = @"http://lighthouseapp.com/";
static NSString *const kLighthouseAccountTypeName = @"com.google.qsb.lighthouse.account";
static NSString *const kLighthouseAccountProjectIDKey = @"LighthouseAccountProjectIDKey";

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

@implementation LighthouseAccount

@synthesize authCompleted = authCompleted_;
@synthesize authSucceeded = authSucceeded_;
@synthesize projectID     = projectID_;
//@synthesize domainName    = domainName_;
//@synthesize accessToken   = accessToken_;

- (id)initWithConfiguration:(NSDictionary *)prefDict {
  if ((self = [super initWithConfiguration:prefDict])) {
    NSString *projectID = [prefDict objectForKey:kLighthouseAccountProjectIDKey];
    if ([projectID length]) {
      projectID_    = [projectID copy];
      domainName_   = [self userName];
      accessToken_  = [self password];
    } else {
      HGSLog(@"Missing project ID");
      [self release];
      self = nil;
    }
  }
  return self;
}

- (NSDictionary *)configuration {
  NSDictionary *parentConfig = [super configuration];
  NSMutableDictionary *accountDict = [NSMutableDictionary dictionaryWithDictionary:parentConfig];
  [accountDict setObject:[self projectID] forKey:kLighthouseAccountProjectIDKey];
  return accountDict;
}

- (NSString *)type {
  return kLighthouseAccountTypeName;
}

- (void)setPassword:(NSString *)token {
  [super setPassword:token];
  accessToken_ = token;
}

- (void) setAccessToken:(NSString *) token {
  [self setPassword:token];
}

- (NSString *) accessToken {
  return accessToken_;
}

- (NSString *) domainName {
  return [self userName];
}

- (NSMutableURLRequest *)buildAuthRequestFor:(NSString *) domainName
                               accessToken:(NSString *) token
                                 projectID:(NSString *) projectID {
  NSString *authURLWithDomain = [NSString
                                 stringWithFormat:@"https://%@.lighthouseapp.com/project/%@.xml",
                                 domainName,
                                 projectID];
  NSURL *authURL = [NSURL URLWithString:authURLWithDomain];
  NSMutableURLRequest *authRequest
  = [NSMutableURLRequest requestWithURL:authURL
                            cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                        timeoutInterval:kAuthenticationTimeOutInterval];
  [authRequest setHTTPShouldHandleCookies:NO];
  [authRequest addValue:token forHTTPHeaderField:@"X-LighthouseToken"];
  return authRequest;
}

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

- (BOOL)authenticateWithPassword:(NSString *)token {
  NSString *projectID = [self projectID];
  return [self authenticateWithAccessToken:token andProjectID: projectID];
}

- (BOOL)authenticateWithAccessToken:(NSString *)token
                       andProjectID:(NSString *)projectID {
  NSMutableURLRequest *authRequest = [self buildAuthRequestFor:[self domainName]
                                                   accessToken:token
                                                     projectID:projectID];
  [self setAuthCompleted:NO];
  [self setAuthSucceeded:NO];

  GDataHTTPFetcher* authFetcher = [GDataHTTPFetcher httpFetcherWithRequest:authRequest];
  [authFetcher setIsRetryEnabled:YES];
  [authFetcher setCookieStorageMethod:kGDataHTTPFetcherCookieStorageMethodFetchHistory];
  [authFetcher beginFetchWithDelegate:self
                    didFinishSelector:@selector(authFetcher:finishedWithData:)
                      didFailSelector:@selector(authFetcher:failedWithError:)];
  NSTimeInterval endTime = [NSDate timeIntervalSinceReferenceDate] + kAuthenticationGiveUpInterval;
  NSRunLoop* loop = [NSRunLoop currentRunLoop];
  while (![self authCompleted]) {
    NSDate *sleepTilDate = [NSDate dateWithTimeIntervalSinceNow:kAuthenticationRetryInterval];
    [loop runUntilDate:sleepTilDate];
    if ([NSDate timeIntervalSinceReferenceDate] > endTime) {
      [authFetcher stopFetching];
      [self setAuthCompleted:YES];
    }
  }
  return [self authSucceeded];
}

- (BOOL)validateResponse:(NSURLResponse *)response {
  BOOL valid = NO;
  if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
    NSHTTPURLResponse *httpURLResponse = (NSHTTPURLResponse *)response;
    NSInteger statusCode = [httpURLResponse statusCode];
    valid = (statusCode == 200);
  }
  return valid;
}

+ (BOOL)openLighthouseHomePage {
  NSURL *lighthouseURL = [NSURL URLWithString:kLighthouseURLString];
  BOOL success = [[NSWorkspace sharedWorkspace] openURL:lighthouseURL];
  return success;
}

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
