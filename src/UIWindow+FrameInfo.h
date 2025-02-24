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
@interface UIWindow( FrameInfo)

- (void) getFrameInfo:(struct CGFrameInfo *) info     MULLE_OBJC_THREADSAFE_METHOD;
- (void) syncFrameInfo:(struct CGFrameInfo *) info    MULLE_OBJC_THREADSAFE_METHOD;

- (mulle_relativetime_t) remainingFrameTime:(mulle_absolutetime_t) now
                                  frameRate:(mulle_relativetime_t) frameRate
                              animationRate:(mulle_relativetime_t) animationRate
                            frameStatistics:(struct UIWindowFrameStatistics *) stats
                           frameRateLimiter:(BOOL) frameLimiter;


- (void) render_requestFakeMouseEventIfNeeded:(UIWindowDisplayBits) displayBits;
- (void) render_setupInitialFirstResponderIfNeeded;
- (UIWindowDisplayBits) render_adjustFrameWithFrameInfo:(struct CGFrameInfo *) info
                                            displayBits:(UIWindowDisplayBits) displayBits;

//
// +--------------------------------------------+
// | render_setupInitialFirstResponderIfNeeded: |
// +--------------------------------------------+
//                      |
//                      v
//      +-----------------------------+
//      | render_adjustFrameIfNeeded: |
//      +-----------------------------+
//                      |
//                      v
//       +----------------------------+
//       | render_frameWithFrameInfo: |
//       |               displayBits: |
//       +----------------------------+
//                      |
//                      v
//   +---------------------------------------+
//   | render_requestFakeMouseEventIfNeeded: |
//   +---------------------------------------+
//
- (UIWindowDisplayBits) renderWithFrameInfo:(struct CGFrameInfo *) info
                                 displayBits:(UIWindowDisplayBits) displayBits;  // assorted UIWindowNeedsDislay bits


@end


@interface UIWindow( FrameFuture)

- (void) swapBuffers                MULLE_OBJC_THREADSAFE_METHOD;
- (void) swapBuffersImmediately     MULLE_OBJC_THREADSAFE_METHOD;

- (UIWindowDisplayBits) render_frameWithFrameInfo:(struct CGFrameInfo *) info
                                      displayBits:(UIWindowDisplayBits) displayBits;

@end



// returns UIWindowAnimationDidHappened if animations were run
// otherwise zero
UIWindowDisplayBits
   UIWindowDefaultPrepareRenderQueue( UIWindow *self,
                                      struct CGFrameInfo *info,
                                      UIWindowDisplayBits displayBits);
