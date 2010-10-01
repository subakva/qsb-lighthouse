#import <QSBPluginUI/QSBSetUpAccountViewController.h>

@interface SetUpLighthouseAccountViewController : QSBSetUpAccountViewController {
@private
  NSString *domainName_;
  NSString *accessToken_;
  NSString *projectID_;
}

@property (nonatomic, copy) NSString *domainName;
@property (nonatomic, copy) NSString *accessToken;
@property (nonatomic, copy) NSString *projectID;

- (IBAction)acceptSetupAccountSheet:(id)sender;
- (IBAction)openLighthouseHomePage:(id)sender;
- (void)presentMessageOffWindow:(NSWindow *)parentWindow
                    withSummary:(NSString *)summary
              explanationFormat:(NSString *)format
                     alertStyle:(NSAlertStyle)style;
@end
