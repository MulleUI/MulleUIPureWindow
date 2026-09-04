//
//  UIPureWindow+FrameInfo.m
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
#define _GNU_SOURCE

#import "UIPureWindow+FrameInfo.h"

#import "import-private.h"

#import "UIPureWindow+DebugPrivate.h"
#import "UIPureWindow+UIResponder.h"
#import "UIPureWindow+UIEvent.h"


//#define RENDERINFO_DEBUG


@interface UIPureWindow( Private)

- (void) _setPosition:(CGPoint) position;
//- (void) _setSize:(CGSize) size;
- (void) _setFrame:(CGRect) rect;
//- (void) _setFramebufferSize:(CGPixelSize) size;

@end


@implementation UIPureWindow ( FrameInfo)

- (mulle_relativetime_t) displayAndRefreshRate
{
   if( [NSThread mulleIsMainThread])
      return( _mainThreadStatistics.lastEndTimestamp - _mainThreadStatistics.lastBeginTimestamp);
   return( _windowThreadStatistics.lastEndTimestamp - _windowThreadStatistics.lastBeginTimestamp);
}


//
// returns 0.0 : means refresh/redraw now
// otherwise the remainingFrameTime before paint
//
- (mulle_relativetime_t) remainingFrameTime:(mulle_absolutetime_t) now
                                  frameRate:(mulle_relativetime_t) frameRate
                              animationRate:(mulle_relativetime_t) animationRate
                            frameStatistics:(struct UIWindowFrameStatistics *) stats
                           frameRateLimiter:(BOOL) frameRateLimiter
{
   mulle_relativetime_t   remainingFrameTime;
   mulle_relativetime_t   rate;
   UIWindowDisplayBits    displayBits;

   // first run always draw
   if( stats->lastEndTimestamp == 0.0)
      return( 0.0);

   // unsynced always runs loose
   if( frameRate == UIWindowFrameRateUnsynced)
      return( 0.0);

   rate        = frameRate;
   displayBits = [self needsDisplay];
   // async is special, we ignore the frameRate but use the animationRate
   // instead (IF we are animating)
   if( frameRate == UIWindowFrameRateAsync)
   {
      if( ! displayBits)
         return( INFINITY);

      // if only animation is needed, we need to use the animationRate
      if( displayBits != UIWindowDisplayNeedsNextFrame)
         return( 0.0);

      rate = animationRate;
   }

   assert( now > stats->lastEndTimestamp);

   remainingFrameTime = rate - (now - stats->lastEndTimestamp); // - stats->avgElapsedHistory;

#ifdef DISPLAY_DEBUG
   MulleUIViewLog( "frameRate: %.3f now: %.6f last: %.6f remaining: %.6f",
               rate,
               now,
               previous,
               remainingFrameTime);
#endif

   if( remainingFrameTime <= 0.0)
      return( 0.0);

   if( frameRateLimiter)
   {
      if( ! displayBits) // ???
         return( INFINITY);
   }

   return( remainingFrameTime);
}


//
// this will ask the "real" window for its framebuffer size, window size
// and window position
//
- (void) getFrameInfo:(struct CGFrameInfo *) info
{
   struct UIOSWindowInfo   tmp;

   assert( info);

   [_OSWindow getOSWindowInfo:&tmp];

   memset( info, 0, sizeof( CGFrameInfo));

   info->window        = tmp.base;
   info->viewportFrame = CGPixelRectMake( 0,
                                          0,
                                          info->window.framebufferSize.width,
                                          info->window.framebufferSize.height);
   info->alpha         = 1.0;

   info->now           = mulle_absolutetime_now();
   info->refreshRate   = tmp.refreshRate;
   info->frameRate     = [self frameRate];
}


- (void) syncFrameInfo:(struct CGFrameInfo *) info
{
   BOOL   sendEvent;

#ifdef RENDERINFO_DEBUG
   MulleUILog( "info:%s previous:%s",
               CGWindowInfoUTF8String( &info->window),
               CGWindowInfoUTF8String( &self->_previousWindowInfo));
#endif

   sendEvent = NO;
   NSLockingDo( _windowPropertyLock)
   {
      if( ! CGWindowInfoEqualToWindowInfo( &info->window, &self->_previousWindowInfo))
      {
         // this will change the frame and _currentWindowInfo for the render thread
         // and same for the main thread, but the main thread shouldn't touch
         // _currentWindowInfo if a thread is active
         // whereas the thread doesn't touch _previousWindowInfo
         _previousWindowInfo = info->window;
         sendEvent = YES;
      }
   }

   if( sendEvent)
      [self sendWindowFramebufferGeometryEvent:&info->window];
}


@end


// use this for screenshots or something ?

#if 0
- (struct CGBitmap)
   lastRenderedFramebufferBitmapType:(CGFramebufferBitmapType) type
                            inFlight:(BOOL) inFlight
                           allocator:(struct mulle_allocator *) allocator
{
   id <UIGraphicsContext>     context;
   struct CGBitmap   fb;

   context = [self activateRenderGraphicsContext];
   {
     // need to blit from offscreen window to onscreen here
     // get image of offscreen framebuffer
     // can do this only, if we have rendered something last frame
     fb = [context lastRenderedFramebufferBitmapType:type
                                            inFlight:(BOOL) inFlight
                                           allocator:allocator];
   }
   [self deactivateGraphicsContext:context];

   return( fb);
}


- (struct CGBitmap) lastRenderedFramebuffer
{
   return( [self lastRenderedFramebufferBitmapType:CGFramebufferRGBABytes
                                          inFlight:NO
                                         allocator:NULL]);
}


- (struct CGBitmap)
   lastRenderedOffscreenFramebufferBitmapType:(CGFramebufferBitmapType) type
                                    allocator:(struct mulle_allocator *) allocator
{
   id <UIGraphicsContext>     context;
   struct CGBitmap   fb;

   context = [self activateRenderGraphicsContext];
   {
     // need to blit from offscreen window to onscreen here
     // get image of offscreen framebuffer
     // can do this only, if we have rendered something last frame
     fb = [context lastRenderedOffscreenFramebufferBitmapType:type
                                                    allocator:allocator];
   }
   [self deactivateGraphicsContext:context];

   return( fb);
}


- (struct CGBitmap) lastRenderedOffscreenFramebuffer
{
   return( [self lastRenderedOffscreenFramebufferBitmapType:CGFramebufferRGBABytes
                                                  allocator:NULL]);
}

#endif

#if 0

- (void) copyBackingStore
{
   struct CGBitmap   fb;
   struct CGFrameInfo           info;
   id <UIGraphicsContext>     context;

   fb = [self lastRenderedOffscreenFramebuffer];
   // if there has nothing been rendered yet, we decline the swap
   if( fb.bytes == 0)
      return;

   // mulle_rgba_dump( fb.bytes, fb.info.size.width, fb.info.size.height);

   //
   // draw the image we got from the framebuffer into the window
   //
   context = [self activateWindowGraphicsContext];
   {
      [self syncFrameAndFramebufferSizeWithOSWindow];
      [self getFrameInfo:&info];

      [context beginRender:&info];
      // [context clearFramebuffer]; // probably not needed
      [context drawBitmap:&fb];
      [context endRender];
   }
   [self deactivateGraphicsContext:context];

   CGFramebufferBitmapDone( &fb);
}
#endif
