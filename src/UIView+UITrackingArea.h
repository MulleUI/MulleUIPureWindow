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


@interface UIView( UITrackingArea)

// ---
// UIView( UITrackingArea)
// ---
- (NSUInteger) numberOfTrackingAreas;
- (UITrackingArea *) trackingAreaAtIndex:(NSUInteger) i;

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


@end
