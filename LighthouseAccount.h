#import <Vermilion/Vermilion.h>
#import <QSBPluginUI/QSBPluginUI.h>

@class LighthouseAccountEditController;

@interface LighthouseAccount : HGSSimpleAccount {
@private
  BOOL authCompleted_;
  BOOL authSucceeded_;
  NSString *projectID_;
}

@property (nonatomic, copy) NSString *projectID;

+ (BOOL)openLighthouseHomePage;
- (BOOL)authenticateWithPassword:(NSString *)token
                    andProjectID: (NSString *)projectID;
@end
