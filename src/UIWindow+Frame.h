//
// Copyright (c) 2021 Nat!, Mulle kybernetiK
//

#import "UIWindow.h"

@class CGContext;

//
// Frame is about layouting views, animating views and layers and
// finally rendering into a framebuffer. If you want to directly get called
// without UIView handling then override the frameCallback.
//
@interface UIWindow( Frame)

- (void) getFrameInfo:(struct CGFrameInfo *) info;
- (void) syncFrameInfo:(struct CGFrameInfo *) info;
- (void) swapBuffers;
- (void) swapBuffersImmediately;
- (BOOL) renderWithFrameInfo:(struct CGFrameInfo *) info
                 displayBits:(NSUInteger) displayBits;  // assorted UIWindowNeedsDislay bits

- (id <UIGraphicsContext>) activateWindowGraphicsContext;
- (id <UIGraphicsContext>) activateRenderGraphicsContext;
- (id <UIGraphicsContext>) activateOffscreenGraphicsContext;

- (void) deactivateGraphicsContext:(id <UIGraphicsContext>) context;

- (mulle_relativetime_t) remainingFrameTime:(mulle_absolutetime_t) now
                                  frameRate:(mulle_relativetime_t) frameRate
                              animationRate:(mulle_relativetime_t) animationRate
                            frameStatistics:(struct UIWindowFrameStatistics *) stats
                           frameRateLimiter:(BOOL) frameLimiter;
#if 0
// this will activate the window context!
- (struct CGBitmap)
   lastRenderedFramebufferBitmapType:(CGFramebufferBitmapType) type
                            inFlight:(BOOL) inFlight
                           allocator:(struct mulle_allocator *) allocator;
#endif

@end

