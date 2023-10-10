//
// Copyright (c) 2021 Nat!, Mulle kybernetiK
//
// prefer a local UIWindow over one in import.h
#ifdef __has_include
# if __has_include( "UIWindow.h")
#  import "UIWindow.h"
# endif
#endif

// we want "import.h" always anyway
#import "import.h"



//
// this callback does the UIView layout, animation unless _frameCallback is set
//
extern UIWindowDisplayBits
   UIWindowDefaultRawFrameCallback( UIWindow *self,
                                    id <UIGraphicsContext> context,
                                    struct CGFrameInfo *info,
                                    UIWindowDisplayBits displayBits);

extern UIWindowDisplayBits
   UIWindowDefaultWillRenderFrameCallback( UIWindow *self,
                                           id <UIGraphicsContext> context,
                                           struct CGFrameInfo *info,
                                           UIWindowDisplayBits displayBits);

extern UIWindowDisplayBits
   UIWindowDefaultDidRenderFrameCallback( UIWindow *self,
                                          id <UIGraphicsContext> context,
                                          struct CGFrameInfo *info,
                                          UIWindowDisplayBits didAnimate);

@interface UIWindow( Render)

- (void) willRenderWithAbsoluteTime:(mulle_absolutetime_t) renderStart;

//
// If you have preLayoutAnimations, layout will always be called
// -layout is needed for keeping tracking rects in sync (indirectly, by
// invalidating the quadtree)
//
- (BOOL) preLayoutAnimations:(struct CGFrameInfo *) info
             graphicsContext:(id <UIGraphicsContext>) context;

- (void) layoutFrame:(struct CGFrameInfo *) info
     graphicsContext:(id <UIGraphicsContext>) context;

// runs even if layout is not called
- (BOOL) postLayoutAnimations:(struct CGFrameInfo *) info
              graphicsContext:(id <UIGraphicsContext>) context;

// returns YES if animation ran
- (BOOL) animateFrame:(struct CGFrameInfo *) info
      graphicsContext:(id <UIGraphicsContext>) context;
- (void) drawFrame:(struct CGFrameInfo *) info
   graphicsContext:(id <UIGraphicsContext>) context;


// debug method, depending on how UIWindow is compiled, this will
// check for duplicated -layout calls to a UIView
- (void) addLayoutedView:(UIView *) view;

// used in setFrame: to catch subviews "managing" a superview state
- (BOOL) isLayoutedView:(UIView *) view;

@end


mulle_relativetime_t    UIWindowGetAnimationRate( UIWindow *self);
