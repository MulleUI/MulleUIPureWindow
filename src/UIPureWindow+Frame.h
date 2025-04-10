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
@interface UIPureWindow( Frame)

- (void) swapBuffers                MULLE_OBJC_THREADSAFE_METHOD;
- (void) swapBuffersImmediately     MULLE_OBJC_THREADSAFE_METHOD;

- (struct CGBitmap) screenshotBitmap;

#if 0
// this will activate the window context!
- (struct CGBitmap)
   lastRenderedFramebufferBitmapType:(CGFramebufferBitmapType) type
                            inFlight:(BOOL) inFlight
                           allocator:(struct mulle_allocator *) allocator;
#endif


// render_frameWithFrameInfo:displayBits: is the method you want to override,
// if you are implementing a graphics system which has no UIGraphicsContext.
// The default implementation does:
//
// +----------------------------------+
// | activateRenderGraphicsContext    |
// +----------------------------------+
//                  |
//                  v
//   # Then it executes these three callbacks in succession:
//
//   +---------------------------------+
//   | self->_willRenderFrameCallback  |
//   +---------------------------------+
//             |
//             v
//   +---------------------------------+
//   | self->_rawFrameCallback         |
//   +---------------------------------+
//             |
//             v
//   +---------------------------------+
//   | self->_didRenderFrameCallback   |
//   +---------------------------------+
//
//   # In the default configuration these are:
//   #
//   #  * UIPureWindowDefaultWillRenderFrameCallback() - does nothing
//   #  * UIPureWindowDefaultRawFrameCallback()        - the real smarts are here
//   #  * UIPureWindowDefaultDidRenderFrameCallback()  - does nothing
//   #
//   # See UIWindow+Render.h for more info.
//
//                  |
//                  v
// +----------------------------------+
// | deactivateRenderGraphicsContext  |
// +----------------------------------+
//
//

@end

