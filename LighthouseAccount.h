
#import <Vermilion/Vermilion.h>
#import <QSBPluginUI/QSBPluginUI.h>

@interface LighthouseAccount : HGSSimpleAccount {
@private
  BOOL authCompleted_;
  BOOL authSucceeded_;
  NSString *projectID_;
}

@property (nonatomic, copy) NSString *projectID;
@property (nonatomic, copy) NSString *accessToken;
@property (nonatomic, copy, readonly) NSString *domainName;

+ (BOOL)openLighthouseHomePage;

+ (NSMutableURLRequest *)createAuthenticatedRequestFor:(NSString *)apiPathPattern
                                            domainName:(NSString *) domainName
                                           accessToken:(NSString *) accessToken
                                             projectID:(NSString *) projectID;

+ (NSMutableURLRequest *)createAuthenticatedRequestFor:(NSString *)urlPattern
                                               account:(LighthouseAccount *) account;

- (BOOL)authenticateWithAccessToken:(NSString *)accessToken
                       andProjectID: (NSString *)projectID;
@end
