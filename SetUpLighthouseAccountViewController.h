#import <QSBPluginUI/QSBPluginUI.h>
#import <QSBPluginUI/QSBSetUpSimpleAccountViewController.h>

/*
 A controller which manages a view used to specify a Lighthouse domain
 name, token and project ID during the setup process.
*/
@interface SetUpLighthouseAccountViewController : QSBSetUpSimpleAccountViewController {
@private
  NSString *projectID_;
}

/*! The ID of the lighthouse project. */
@property (nonatomic, copy) NSString *projectID;

/*! Open lighthouseapp.com in the user's preferred browser. */
- (IBAction)openLighthouseHomePage:(id)sender;

@end
