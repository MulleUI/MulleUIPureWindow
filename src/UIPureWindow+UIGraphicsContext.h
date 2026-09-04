//
//  UIPureWindow+UIGraphicsContext.h
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
- (void) deactivateGraphicsContext:(id <UIGraphicsContext>) context
                         keepState:(UIGraphicsContextState) keepState  MULLE_OBJC_THREADSAFE_METHOD;

- (void) deactivateRenderGraphicsContextKeepState:(UIGraphicsContextState) keepState MULLE_OBJC_THREADSAFE_METHOD;

// TODO: not really/really threadsafe, pls to fix
- (void) activateRenderGraphicsContext                MULLE_OBJC_THREADSAFE_METHOD;
- (void) deactivateRenderGraphicsContext              MULLE_OBJC_THREADSAFE_METHOD;


// used by UIPureWindow in -finalize to circumvent an assert
- (id <UIGraphicsContext>) activateGraphicsContext:(id <UIGraphicsContext>) context
                                          OSWindow:(id<UIOSWindow>) OSWindow    MULLE_OBJC_THREADSAFE_METHOD;

@end
