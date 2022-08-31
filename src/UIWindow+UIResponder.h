#import "UIWindow.h"


// TODO: if the mouse pointer leaves the window we should reset the 
//       firstResponder too
//
@interface UIWindow (UIResponder)

- (id<UIResponder>)firstResponder;
- (BOOL)makeFirstResponder:(id<UIResponder>)responder;

@end
