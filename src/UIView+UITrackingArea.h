//
// Copyright (c) 2023 Nat!, Mulle kybernetiK
//
// prefer a local UIView over one in import.h
#ifdef __has_include
# if __has_include( "UIView.h")
#  import "UIView.h"
# endif
#endif

// we want "import.h" always anyway
#import "import.h"


@class UITrackingArea;
@class UIWindow;
@class UIMouseTrackingEvent;


@interface UIView( UITrackingArea)

// ---
// UIView( UITrackingArea)
// ---
- (NSUInteger) numberOfTrackingAreas;
- (UITrackingArea *) trackingAreaAtIndex:(NSUInteger) i;

- (void) addRetainedTrackingArea:(UITrackingArea *) item
                        toWindow:(UIWindow *) window;

- (void) addRetainedTrackingArea:(UITrackingArea *) area;

// this convenience will use (UIWindow *) [self window] as the target window and will
// set [item owner] to self, if not already set
- (void) addTrackingArea:(UITrackingArea *) area;

- (void) removeTrackingArea:(UITrackingArea *) item;
- (void) removeAllTrackingAreas;

// default implementation will update tracking areas with
// option UITrackingVisibleRectOnly set. Other areas will stale away, if
// this method isn't overridden.
- (void) updateTrackingAreas;


- (mulle_relativetime_t) hoverTimeInterval;

//
// these do nothing (except trace) so you don't need to super these
//
- (void) mouseEntered:(UIMouseTrackingEvent *) event;
- (void) mouseMoved:(UIMouseTrackingEvent *) event;
- (void) mouseExited:(UIMouseTrackingEvent *) event;
- (void) mouseHoverStarted:(UIMouseTrackingEvent *) event;
- (void) mouseHoverEnded:(UIMouseTrackingEvent *) event;

@end
