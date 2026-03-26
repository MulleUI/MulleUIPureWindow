//
// Copyright (c) 2021 Nat!, Mulle kybernetiK
//
#define _GNU_SOURCE

#import "UIPureWindow+Frame.h"
#import "UIPureWindow+UIGraphicsContext.h"

#import "import-private.h"

#import "UIPureWindow+DebugPrivate.h"
#import "UIPureWindow+FrameInfo.h"


//#define FAKE_MOUSE_MOTION_CALLBACK_DEBUG
//#define SWAP_DEBUG
//#define RENDERINFO_DEBUG

@interface UIPureWindow( Private)

- (void) _setPosition:(CGPoint) position MULLE_OBJC_THREADSAFE_METHOD;
//- (void) _setSize:(CGSize) size;
- (void) _setFrame:(CGRect) rect MULLE_OBJC_THREADSAFE_METHOD;
//- (void) _setFramebufferSize:(CGPixelSize) size;

@end


@implementation UIPureWindow ( Frame)

//
// does a screenshot of the primary context (front buffer)
// TODO: could grab hidden framebuffer, maybe even more easy ?
//
- (struct CGBitmap) screenshotBitmap
{
   id <UIGraphicsContext>   context;
   struct CGBitmap          bitmap;
   struct CGFrameInfo       frameInfo;
   CGPixelRect              rect;

   context = [self activateWindowGraphicsContext];
   @autoreleasepool
   {
      [self getFrameInfo:&frameInfo];

      rect   = CGPixelRectMake( 0,
                                0,
                                frameInfo.window.framebufferSize.width,
                                frameInfo.window.framebufferSize.height);
      bitmap = [context readFramebufferBitmap:rect
                        framebufferBitmapType:CGFramebufferRGBABytes
                                    allocator:NULL];
   }
   [self deactivateGraphicsContext:context];

   return( bitmap);
}



/***
 *** SWAP
 ***
 ***/


- (void) changeSwapIntervalIfNeeded    MULLE_OBJC_THREADSAFE_METHOD
{
   NSUInteger   swapInterval;
   BOOL         changeSwapInterval;

   changeSwapInterval = NO;

   [_windowPropertyLock lock];
   {
      swapInterval        = _swapInterval;
      changeSwapInterval  = swapInterval != _oldSwapInterval;
      if( changeSwapInterval)
         _oldSwapInterval = swapInterval;
   }
   [_windowPropertyLock unlock];

   if( ! changeSwapInterval)
      return;

   // need to know that we can activate the context here, otherwise
   // we'd lock and that's bad. Changing the swapInterval on the fly
   // is probably a feature noone will ever use
   [_OSWindow os_setSwapInterval:swapInterval];  // need 0 for smooth pointer/control sync
}

//
// Can only swap buffers if we have rendered at least once
// An early incoming windows refresh request needs to be discarded
// This need not be executed on the main thread (but it always will)
//
- (void) swapBuffers
{
   id <UIGraphicsContext>   context;

   // NO LONGER WELL SUPPORTED AS WAYLAND / EGL CAN'T DO IT
   // single buffer framebuffers don't swap.
   // Flush should have been done already
   if( _styleMask & UIWindowStyleSingleBuffer)  
   {
      UIWindowSwapLog( "no swap because single style");
      return;
   }

   MulleWindowProfileBegin();

   UIWindowSwapLog( "swap");

   context = [self activateWindowGraphicsContext];
   {
      [_OSWindow os_swapBuffers];
      // changing the swap interval afterwards involved locking, intuitively
      // prefer this after the swap
      [self changeSwapIntervalIfNeeded];
   }
   [self deactivateGraphicsContext:context];

   if( _needsFirstShow)
   {
      UIWindowSwapLog( "show window after first swap");
      _needsFirstShow = NO;
      [_OSWindow os_show];
   }

   MulleWindowProfileEnd();

   //
   // from here on CGImages should be safe to be reaped by autorelease pool
   // or ?
   //
   if( _didSwapBuffersCallback)
   {
      UIWindowSwapLog( "Executing didSwapBuffersCallback");
      (*_didSwapBuffersCallback)( self, NO);
   }

   // now call sync, so this is the first of the "not"
   MulleWindowProfileSync();
}


- (void) swapBuffersImmediately
{
   id <UIGraphicsContext>   context;

   UIWindowSwapLog( "swap immediately");

   MulleWindowProfileBegin();

   context = [self activateWindowGraphicsContext];
   {
      [_OSWindow os_setSwapInterval:0]; 
      [_OSWindow os_swapBuffers];
      [_OSWindow os_setSwapInterval:_swapInterval];  // need 0 for smooth pointer/control sync
   }
   [self deactivateGraphicsContext:context];

   if( _needsFirstShow)
   {
      UIWindowSwapLog( "show window after first immediate swap");
      _needsFirstShow = NO;
      [_OSWindow os_show];
   }

   MulleWindowProfileEnd();

   if( _didSwapBuffersCallback)
   {
      UIWindowSwapLog( "Executing didSwapBuffersCallback");
      (*_didSwapBuffersCallback)( self, YES);
   }
   // now call sync, so this is the first of the "not"
   MulleWindowProfileSync();
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
