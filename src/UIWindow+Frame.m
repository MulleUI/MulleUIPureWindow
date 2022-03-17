//
// Copyright (c) 2021 Nat!, Mulle kybernetiK
//
#define _GNU_SOURCE

#import "UIWindow+Frame.h"

#import "import-private.h"

#import "UIWindow+Render.h"
#import "UIWindow+UIEvent.h"
#import "UIView+RenderQueue.h"
#import "CGFrameInfo+UTF8String.h"


//#define LAYOUT_ANIMATIONS
//#define SWAP_DEBUG
#define RENDERINFO_DEBUG

@implementation UIWindow ( Frame)

- (double) fastestFrameRate
{
   if( _frameRate == UIWindowFrameRateSynced)
      return( [self monitorRefreshRate]);
   return( _frameRate);  // async=INFINITY, unsynced=0.0
}


- (double) slowestFrameRate
{
   // if we use a limiter, we could make no updates for forever
   if( _frameRateLimiter)
      return( INFINITY);
   if( _frameRate == UIWindowFrameRateSynced)
      return( [self monitorRefreshRate]);
   return( _frameRate);
}


- (id <UIGraphicsContext>) activateWindowGraphicsContext
{
   Class   osGraphicsContextClass;

   [_OSWindow os_activateGraphicsContext];

   if( ! _context)
   {
      osGraphicsContextClass = [[self class] osGraphicsContextClass];
      _context               = [[osGraphicsContextClass alloc] initWithEdgeAntialiasing:(_styleMask & UIWindowStyleEdgeAntialias)
                                                                      useStencilStrokes:(_styleMask & UIWindowStyleStencilStrokes)];
      [_context setOSWindow:_OSWindow];
   }
   [_context setActive:YES];

#ifdef SWAP_DEBUG
   mulle_fprintf( stderr, "%@: %s %@ window context\n",
            [NSThread currentThread], __PRETTY_FUNCTION__, self);
#endif
   return( _context);
}


// TODO: memo, maybe the context triggers os_activateGraphicsContext ?
- (id <UIGraphicsContext>) activateRenderGraphicsContext
{
   id <UIGraphicsContext>   context;
   Class                      cls;

   // take renderlock here, relinquish later when wating for events
   // or when someone closes the window

   if( _backingStore == UIWindowBackingStoreVolatile)
      return( [self activateWindowGraphicsContext]);

   assert( _offscreenOSWindow);

   [_offscreenOSWindow os_activateGraphicsContext];
   if( ! _offscreenContext)
   {
      cls               = [[self class] osGraphicsContextClass];
      _offscreenContext = [[cls alloc] initWithEdgeAntialiasing:(_offscreenStyleMask & UIWindowStyleEdgeAntialias)
                                              useStencilStrokes:(_offscreenStyleMask & UIWindowStyleStencilStrokes)];
      [_offscreenContext setRendersOffScreen:YES];
      [_context setOSWindow:_offscreenOSWindow];
   }
   [_offscreenContext setActive:YES];                        // just a flag

#ifdef SWAP_DEBUG
   mulle_fprintf( stderr, "%@: %s %@ offscreen context\n",
            [NSThread currentThread], __PRETTY_FUNCTION__, self);
#endif
   return( _offscreenContext);
}


- (void) deactivateContext:(id <UIGraphicsContext>) context
{
   assert( context);

   [context setActive:NO];
   if( context == _offscreenContext)
   {
#ifdef SWAP_DEBUG
   mulle_fprintf( stderr, "%@: %s %@ offscreen context\n",
            [NSThread currentThread], __PRETTY_FUNCTION__, self);
#endif
      [_offscreenOSWindow os_deactivateGraphicsContext];
   }
   else
   {
#ifdef SWAP_DEBUG
      mulle_fprintf( stderr, "%@: %s %@ window context\n",
            [NSThread currentThread], __PRETTY_FUNCTION__, self);
#endif
      [_OSWindow os_deactivateGraphicsContext];
   }
}


//
// this will ask the "real" window for its framebuffer size, window size
// and window position
//
- (void) _getFrameInfo:(struct CGFrameInfo *) info
{
   assert( info);
   assert( [NSThread mulleIsMainThread]);

   //
   // assumption is, the optimizing compiler will inline this with -O3
   // and then combine with settings
   //
   [_OSWindow getWindowInfo:&info->window];
   info->viewportFrame = CGBitmapRectMake( 0,
                                           0,
                                           info->window.framebufferSize.width,
                                           info->window.framebufferSize.height);
   info->alpha         = 1.0;
   info->now           = mulle_absolutetime_now();
}


- (void) getFrameInfo:(struct CGFrameInfo *) info
{
   [self _getFrameInfo:info];
#ifdef RENDERINFO_DEBUG
   mulle_fprintf( stderr, "%@: %@ %s info:%s previous:%s\n",
                        [NSThread currentThread],
                        self,
                        __PRETTY_FUNCTION__,
                        CGWindowInfoUTF8String( &info->window),
                        CGWindowInfoUTF8String( &self->_previousWindowInfo));
#endif
   if( ! CGWindowInfoEqualToWindowInfo( &info->window, &self->_previousWindowInfo))
   {
      // this will change the frame and _currentWindowInfo for the render thread
      // and same for the main thread, but the main thread shouldn't touch
      // _currentWindowInfo if a thread is active
      // whereas the thread doesn't touch _previousWindowInfo
      _previousWindowInfo = info->window;

      [self sendWindowFramebufferGeometryEvent:&info->window];
   }
}


- (void) renderWithFrameInfo:(struct CGFrameInfo *) info
                 displayBits:(NSUInteger) displayBits
{
   id <UIGraphicsContext>   context;

   context = [self activateRenderGraphicsContext];
   {
#ifdef RENDERINFO_DEBUG
      mulle_fprintf( stderr, "%@: %@ %s %s\n",
                        [NSThread currentThread], self, __PRETTY_FUNCTION__,
                        CGFrameInfoUTF8String( info));
#endif
      // This is usually UIWindowDefaultFrameCallback (UIWindow+Render.m)
      (*self->_renderFrameCallback)( self, context, info, displayBits);
   }
   [self deactivateContext:context];
}


- (void) changeSwapIntervalIfNeeded
{
   id <UIGraphicsContext>   context;
   NSUInteger               swapInterval;
   BOOL                     changeSwapInterval;
   mulle_absolutetime_t     now;

   changeSwapInterval = NO;

   [_windowPropertyLock lock];
   {
      swapInterval        = _swapInterval;
      changeSwapInterval  =  swapInterval != _oldSwapInterval;
      if( changeSwapInterval)
         _oldSwapInterval = swapInterval;
   }
   [_windowPropertyLock unlock];

   if( ! changeSwapInterval)
      return;

   // need to know that we can activate the context here, otherwise
   // we'd lock and that's bad. Changing the swapInterval on the fly
   // is probably a feature noone will ever use

   context = [self activateWindowGraphicsContext];
   {
      [_OSWindow os_setSwapInterval:_swapInterval];  // need 0 for smooth pointer/control sync
   }
   [self deactivateContext:context];
}

//
// Can only swap buffers if we have rendered at least once
// An early incoming windows refresh request needs to be discarded
// This need not be executed on the main thread (but it always will)
//
- (void) swapBuffers
{
#ifdef SWAP_DEBUG
   mulle_fprintf( stderr, "%@: %s %@\n",
            [NSThread currentThread], __PRETTY_FUNCTION__, self);
#endif

   [self changeSwapIntervalIfNeeded];
   [_OSWindow os_swapBuffers];

#ifdef SWAP_DEBUG
   mulle_fprintf( stderr, "%@: UIWindow %@ swapped buffers (%.6f)\n",
                        [NSThread currentThread], self, now);
#endif

   //
   // from here on CGImages should be safe to be reaped by autorelease pool
   // or ?
   //
}


@end

// use this for screenshots or something ?

#if 0
- (struct CGBitmap)
   lastRenderedFramebufferBitmapType:(enum CGFramebufferBitmapType) type
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
   [self deactivateContext:context];

   return( fb);
}


- (struct CGBitmap) lastRenderedFramebuffer
{
   return( [self lastRenderedFramebufferBitmapType:CGFramebufferRGBABytes
                                          inFlight:NO
                                         allocator:NULL]);
}


- (struct CGBitmap)
   lastRenderedOffscreenFramebufferBitmapType:(enum CGFramebufferBitmapType) type
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
   [self deactivateContext:context];

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
   [self deactivateContext:context];

   CGFramebufferBitmapDone( &fb);
}
#endif
