
#import <QSBPluginUI/QSBPluginUI.h>

/*
 A controller which manages a window used to edit the token
 for a Lighthouse account.  Exposed publicly so that Interface
 Builder can see the action.
 */
@interface EditLighthouseAccountWindowController : QSBEditSimpleAccountWindowController {
@private
NSString *projectID_;
}

/*! The ID of the lighthouse project. */
@property (nonatomic, copy) NSString *projectID;


/*! Open lighthouseapp.com in the user's preferred browser. */
- (IBAction)openLighthouseHomePage:(id)sender;

@end
