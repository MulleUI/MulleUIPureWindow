//
//  UIPureWindow+Frame.h
//  MulleUIPureWindow
//
//  Copyright (c) 2025 Nat! - Mulle kybernetiK.
//  All rights reserved.
//
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  Redistributions of source code must retain the above copyright notice, this
//  list of conditions and the following disclaimer.
//
//  Redistributions in binary form must reproduce the above copyright notice,
//  this list of conditions and the following disclaimer in the documentation
//  and/or other materials provided with the distribution.
//
//  Neither the name of Mulle kybernetiK nor the names of its contributors
//  may be used to endorse or promote products derived from this software
//  without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//
#ifdef __has_include
# if __has_include( "UIPureWindow.h")
#  import "UIPureWindow.h"
# endif
#endif

#import "import.h"

@class CGContext;



@protocol UIPureWindowBitmapImage

+ (id) imageWithBitmap:(struct CGBitmap) bitmap
          freeWhenDone:(BOOL) YES;
- (BOOL) writeToPNGUTF8String:(char *) filename;

@end


//
// Frame is about layouting views, animating views and layers and
// finally rendering into a framebuffer. If you want to directly get called
// without UIView handling then override the frameCallback.
//
@interface UIPureWindow( Frame)

- (void) swapBuffers                MULLE_OBJC_THREADSAFE_METHOD;
- (void) swapBuffersImmediately     MULLE_OBJC_THREADSAFE_METHOD;


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

- (struct CGBitmap) screenshotBitmap;
- (id <UIPureWindowBitmapImage>) screenshotBitmapImage;
- (BOOL) writeScreenshotToPNGUTF8String:(char *) filename;

@end


@interface UIPureWindow( FrameFuture) <MulleObjCFuture>

+ (Class) bitmapImageClass;

@end
