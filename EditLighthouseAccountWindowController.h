
#import <QSBPluginUI/QSBEditAccountWindowController.h>

@interface EditLighthouseAccountWindowController : QSBEditAccountWindowController {
@private
  NSString *domainName_;
  NSString *accessToken_;
  NSString *projectID_;
}

@property (nonatomic, copy) NSString *domainName;
@property (nonatomic, copy) NSString *accessToken;
@property (nonatomic, copy) NSString *projectID;

- (IBAction)acceptEditAccountSheet:(id)sender;
- (IBAction)openLighthouseHomePage:(id)sender;

@end
