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

- (void) addTrackingArea:(UITrackingArea *) item
                toWindow:(UIWindow *) window;

// this convenience will use (UIWindow *) [self window] as the target window and will
// set [item owner] to self, if not already set
- (void) addTrackingArea:(UITrackingArea *) area;

- (void) removeTrackingArea:(UITrackingArea *) item;
- (void) removeAllTrackingAreas;

// default implementation will update tracking areas with 
// option UITrackingInVisibleRect set and will set rect to zero
// for all others!
- (void) updateTrackingAreas;

- (void) setNeedsDisplay;


// this flag is forwarded to the enclosing UIWindow
// will assert if none is present
- (void) setNeedsLayout;
- (BOOL) needsLayout;


- (void) mouseEntered:(UIMouseTrackingEvent *) event;
- (void) mouseMoved:(UIMouseTrackingEvent *) event;
- (void) mouseExited:(UIMouseTrackingEvent *) event;

@end
