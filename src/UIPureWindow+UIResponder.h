#import "UIPureWindow.h"


// TODO: if the mouse pointer leaves the window we should reset the 
//       firstResponder too
//
@interface UIPureWindow (UIResponder)

- (id<UIResponder>) firstResponder;

//
// You usually don't call this method, as it's too lowlevel.
// Use [responder becomeFirstResponder] and [responder resignFirstResponder]
// so that callback methods are properly triggered
//
- (BOOL) makeFirstResponder:(id<UIResponder>)responder;

- (id <UIResponder>) previousFirstResponder;
- (id <UIResponder>) nextFirstResponder;

- (UIInputEvent *) acceptKeyboardEvent:(UIKeyboardEvent *) event;

@end
