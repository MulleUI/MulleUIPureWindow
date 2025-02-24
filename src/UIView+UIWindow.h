//
// Copyright (c) 2021 Nat!, Mulle kybernetiK
//
// prefer a local UIView over one in import.h

// we want "import.h" always anyway
#import "import.h"


#import "UIWindow.h"


@interface UIView( UIWindow)

//
// Needed when the CALayer needs to be immediately tied to the window
// (notcurses). The view though is *NOT* added as a subview to the window,
// because usually you want to place it as a subview into a different view.
//
//- (UIWindow *) window;

// returns nil, if view is not in a window or the window isn't configured with
// planes
- (UIWindowPlane *) windowPlane;
- (CGFloat) pixelsPerInchOfCurrentScreen;

- (void) setNeedsDisplay      MULLE_OBJC_THREADSAFE_METHOD;

// this flag is forwarded to the enclosing UIWindow
// will assert if none is present
- (void) setNeedsLayout;
- (BOOL) needsLayout;

@end
