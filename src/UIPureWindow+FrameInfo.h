//
// Copyright (c) 2021 Nat!, Mulle kybernetiK
//

#import "UIPureWindow.h"

@class CGContext;

//
// Frame is about layouting views, animating views and layers and
// finally rendering into a framebuffer. If you want to directly get called
// without UIView handling then override the frameCallback.
//
@interface UIPureWindow( FrameInfo)

- (void) getFrameInfo:(struct CGFrameInfo *) info     MULLE_OBJC_THREADSAFE_METHOD;
- (void) syncFrameInfo:(struct CGFrameInfo *) info    MULLE_OBJC_THREADSAFE_METHOD;

- (mulle_relativetime_t) remainingFrameTime:(mulle_absolutetime_t) now
                                  frameRate:(mulle_relativetime_t) frameRate
                              animationRate:(mulle_relativetime_t) animationRate
                            frameStatistics:(struct UIWindowFrameStatistics *) stats
                           frameRateLimiter:(BOOL) frameLimiter;

@end
