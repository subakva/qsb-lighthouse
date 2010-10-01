#import <Vermilion/Vermilion.h>
#import <QSBPluginUI/QSBPluginUI.h>

@class LighthouseAccountEditController;

@interface LighthouseAccount : HGSSimpleAccount {
@private
  BOOL authCompleted_;
  BOOL authSucceeded_;
  NSString *projectID_;
  NSString *accessToken_;
  NSString *domainName_;
}

@property (nonatomic, copy) NSString *projectID;
@property (nonatomic, copy) NSString *accessToken;
@property (nonatomic, copy, readonly) NSString *domainName;

+ (BOOL)openLighthouseHomePage;
- (BOOL)authenticateWithAccessToken:(NSString *)accessToken
                    andProjectID: (NSString *)projectID;
@end
