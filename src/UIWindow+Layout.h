//
// Copyright (c) 2024 Nat!, Mulle kybernetiK
//
// prefer a local UIWindow over one in import.h
#ifdef __has_include
# if __has_include( "UIWindow.h")
#  import "UIWindow.h"
# endif
#endif

// we want "import.h" always anyway
#import "import.h"


@interface UIWindow( Layout)

// debug method, depending on how UIWindow is compiled, this will
// check for duplicated -layout calls to a UIView
- (void) addLayoutedView:(UIView *) view;

// used in setFrame: to catch subviews "managing" a superview state
- (BOOL) isLayoutedView:(UIView *) view;


//
// If you have preLayoutAnimations, layout will always be called
// -layout is needed for keeping tracking rects in sync (indirectly, by
// invalidating the quadtree)
//
- (UIWindowDisplayBits) preLayoutAnimations:(struct CGFrameInfo *) info;

- (void) layoutFrame:(struct CGFrameInfo *) info;

// runs even if layout is not called
- (UIWindowDisplayBits) postLayoutAnimations:(struct CGFrameInfo *) info;

// returns YES if animation ran
- (UIWindowDisplayBits) animateFrame:(struct CGFrameInfo *) info
                         displayBits:(UIWindowDisplayBits) displayBits;

@end



@interface UIWindow( LayoutForward)

- (void) createDrawingQueueForFrame:(struct CGFrameInfo *) info;

@end

//
// this function will call methods in this order (if needed)
//
// +-----------------------------+
// | willRenderWithAbsoluteTime: |
// +-----------------------------+
//        |
//        v
// +----------------------+
// | preLayoutAnimations: |
// +----------------------+
//        |
//        v
// +--------------+
// | layoutFrame: |
// +--------------+
//        |
//        v
// +-----------------------+
// | postLayoutAnimations: |
// +-----------------------+


UIWindowDisplayBits
   UIWindowDefaultLayout( UIWindow *self,
                          struct CGFrameInfo *info,
                          UIWindowDisplayBits displayBits);


//
// this function will call methods in this order (if needed)
//
//        |
//        v
// +-----------------------------+
// | createDrawingQueueForFrame: |  // Place [UIViews layers] in _drawingQueue
// +-----------------------------+
//        |
//        v
// +---------------+
// | animateFrame: |                // animate those in _drawingQueue
// +---------------+
//
UIWindowDisplayBits
   UIWindowDefaultPrepareDrawingQueue( UIWindow *self,
                                       struct CGFrameInfo *info,
                                       UIWindowDisplayBits displayBits);