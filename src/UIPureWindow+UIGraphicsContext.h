//
// Copyright (c) 2021 Nat!, Mulle kybernetiK
//
#ifdef __has_include
# if __has_include( "UIPureWindow.h")
#  import "UIPureWindow.h"
# endif
#endif

#import "import.h"

@class CGContext;

//
// Frame is about layouting views, animating views and layers and
// finally rendering into a framebuffer. If you want to directly get called
// without UIView handling then override the frameCallback.
//
@interface UIPureWindow( UIGraphicsContext)

//
// MEMO: put a NSAutoreleasePool between activate...GraphicsContext
//       and deactivateGraphicsContext so ephemeral CGCLayers can properly
//       relinquish their GPU textures, while the context is still active
//                 
// If the thread is running, then the main thread should never
// call activateOffscreenGraphicsContext, likeweise the thread should never
// call activateWindowGraphicsContext  
//               
- (id <UIGraphicsContext>) activateWindowGraphicsContext    MULLE_OBJC_THREADSAFE_METHOD;
- (id <UIGraphicsContext>) activateOffscreenGraphicsContext MULLE_OBJC_THREADSAFE_METHOD;

- (void) deactivateGraphicsContext:(id <UIGraphicsContext>) context  MULLE_OBJC_THREADSAFE_METHOD;

// TODO: not really/really threadsafe, pls to fix
- (void) activateRenderGraphicsContext                MULLE_OBJC_THREADSAFE_METHOD;
- (void) deactivateRenderGraphicsContext              MULLE_OBJC_THREADSAFE_METHOD;

@end

