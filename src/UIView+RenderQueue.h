//
// Copyright (c) 2020 Nat!, Mulle kybernetiK
//
// prefer a local UIView over one in import.h
#ifdef __has_include
# if __has_include( "UIView.h")
#  import "UIView.h"
# endif
#endif

#import "import.h"


struct UIRenderQueueContext
{
   CGAffineTransform   xform;
   CGRect              clipRect;
   CGFloat             alpha;
};


@interface UIView( RenderQueue)

// all layers (are placed into the render queue, the layers get their
// transform and alpha set
- (void) createRenderQueue:(struct mulle_pointerarray *) renderQueue;

- (void) dumpRenderQueue:(struct mulle_pointerarray *) renderQueue;

// Possibly a good time to stuff values into the CALayer
// You must call super or everything breaks 
- (void) createRenderQueue:(struct mulle_pointerarray *) renderQueue
                   context:(struct UIRenderQueueContext *) ctx;

//
// this may be a good place for your view to override and copy some more
// values into its layer, all animations have run though already
//
- (void)    addLayer:(id <UILayer>) layer
       toRenderQueue:(struct mulle_pointerarray *) renderQueue
             context:(struct UIRenderQueueContext *) v;
@end

