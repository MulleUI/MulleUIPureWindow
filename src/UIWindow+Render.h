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
extern BOOL   UIWindowDefaultRawFrameCallback( UIWindow *self,
                                               id <UIGraphicsContext> context,
                                               struct CGFrameInfo *info,
                                               NSUInteger displayBits);

@interface UIWindow( Render)

- (void) willRenderWithAbsoluteTime:(mulle_absolutetime_t) renderStart;

// runs even if layout is not
- (BOOL) preLayoutAnimations:(struct CGFrameInfo *) info
             graphicsContext:(id <UIGraphicsContext>) context;

- (void) layoutFrame:(struct CGFrameInfo *) info
     graphicsContext:(id <UIGraphicsContext>) context;

// runs even if layout is not
- (BOOL) postLayoutAnimations:(struct CGFrameInfo *) info
              graphicsContext:(id <UIGraphicsContext>) context;

// returns YES if animation ran
- (BOOL) animateFrame:(struct CGFrameInfo *) info
      graphicsContext:(id <UIGraphicsContext>) context;
- (void) drawFrame:(struct CGFrameInfo *) info
   graphicsContext:(id <UIGraphicsContext>) context;

@end


@interface UIEvent( UIResponder)

- (BOOL) isFirstResponderEvent;

@end 

