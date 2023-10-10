//
// Copyright (c) 2021 Nat!, Mulle kybernetiK
//
// prefer a local UIView over one in import.h

// we want "import.h" always anyway
#import "import.h"


#import "UIWindow.h"


@interface UIView( UIWindow)

//- (UIWindow *) window;

// returns nil, if view is not in a window or the window isn't configured with
// planes
- (UIWindowPlane *) windowPlane;
- (CGFloat) pixelsPerInchOfCurrentScreen;

- (void) setNeedsDisplay;

// this flag is forwarded to the enclosing UIWindow
// will assert if none is present
- (void) setNeedsLayout;
- (BOOL) needsLayout;

- (void) mouseEntered:(UIMouseTrackingEvent *) event;
- (void) mouseMoved:(UIMouseTrackingEvent *) event;
- (void) mouseExited:(UIMouseTrackingEvent *) event;

@end
