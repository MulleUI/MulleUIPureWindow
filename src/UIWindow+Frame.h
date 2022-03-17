//
// Copyright (c) 2021 Nat!, Mulle kybernetiK
//

#import "UIWindow.h"

@class CGContext;

//
// Frame is about layouting views, animating views and layers and
// finally rendering into a framebuffer. If you want to directly get called
// without UIView handling then override the renderFrameCallback.
//
@interface UIWindow( Frame)

- (void) _getFrameInfo:(struct CGFrameInfo *) info; // does not send event
- (void) getFrameInfo:(struct CGFrameInfo *) info;
- (void) swapBuffers;
- (void) renderWithFrameInfo:(struct CGFrameInfo *) info
         displayBits:(NSUInteger) displayBits;  // assorted UIWindowNeedsDislay bits

- (id <UIGraphicsContext>) activateWindowGraphicsContext;
- (id <UIGraphicsContext>) activateRenderGraphicsContext;

- (void) deactivateContext:(id <UIGraphicsContext>) context;

// UIWindowFrameRateAsync    : INFINITY
// UIWindowFrameRateSynced   : refreshRate
// UIWindowFrameRateUnsynced : 0.0
// other                     : other
- (double) fastestFrameRate;

// UIWindowFrameRateAsync    : INFINITY
// UIWindowFrameRateSynced   : frameLimiter ? INFINITY : refreshRate
// UIWindowFrameRateUnsynced : 0.0
// other                     : frameLimiter ? INFINITY : other
- (double) slowestFrameRate;

- (BOOL) frameTimeReached;

#if 0
// this will activate the window context!
- (struct CGBitmap)
   lastRenderedFramebufferBitmapType:(enum CGFramebufferBitmapType) type
                            inFlight:(BOOL) inFlight
                           allocator:(struct mulle_allocator *) allocator;
#endif

@end

