//
// Copyright (c) 2021 Nat!, Mulle kybernetiK
//
// prefer a local UIView over one in import.h

// we want "import.h" always anyway
#import "import.h"


#import "UIWindow.h"


@interface UIView( UIWindow)

//- (UIWindow *) window;
- (UIWindowPlane *) windowPlane;
- (CGFloat) pixelsPerInchOfCurrentScreen;

- (void) setNeedsDisplay;

// calls sizeThatFits:context: with the renderContext of the window,
// this will abort, if we are not in render/layout phase but the view is
// part of a window. If there is no window, context will be nil... good luck
- (CGSize) sizeThatFits:(CGSize) size;


// this flag is forwarded to the enclosing UIWindow
// will assert if none is present
- (void) setNeedsLayout;
- (BOOL) needsLayout;


- (void) mouseEntered:(UIMouseTrackingEvent *) event;
- (void) mouseMoved:(UIMouseTrackingEvent *) event;
- (void) mouseExited:(UIMouseTrackingEvent *) event;

@end
