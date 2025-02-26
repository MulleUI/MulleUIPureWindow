#import "UIPureWindow.h"

#import "UIPureWindow+UIWindow.h"

//
// This is support for the "conventional" GLFW render/waitForEvents loop
// which has fallen out of favor for UIApplication
//
@interface UIPureWindow( OneFrame)

// returns ORed bits of handled events
- (NSUInteger) waitForEventsUntil:(mulle_absolutetime_t) timeout
                     returnsEarly:(BOOL) returnsEarly;

//
// eventHandling calls eventHandlingWithFrameRate: which will call
// processEvents:frameRate: which will call waitForEventsUntil:returnsEarly:
//
- (NSUInteger) processEvents:(mulle_absolutetime_t) now
                   frameRate:(mulle_relativetime_t) frameRate;

- (void) eventHandlingWithFrameRate:(mulle_relativetime_t) frameRate;

// returns NO, if windows should close
// does event handling after renderAndSwapOneFrame
- (BOOL) processOneFrame:(CGFloat) frameRate;
- (BOOL) processOneFrame;  // Use unsynced


// as processOneFrame
- (void) renderAndSwapOneFrame;

@end

