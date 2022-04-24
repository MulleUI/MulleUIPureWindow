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
#define SWAP_DEBUG
#define RENDERINFO_DEBUG


@interface UIWindow( Private)

//- (void) _setPosition:(CGPoint) position;
//- (void) _setSize:(CGSize) size;
- (void) _setFrame:(CGRect) rect;
//- (void) _setFramebufferSize:(struct CGBitmapSize) size;

@end


@implementation UIWindow ( Frame)

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
   mulle_relativetime_t   diff;
   mulle_relativetime_t   elapsed;
   mulle_relativetime_t   avgElapsed;
   BOOL                   frameTimeReached;
   mulle_relativetime_t   remainingFrameTime;
   mulle_relativetime_t   rate;
   unsigned int           i;
   NSUInteger             displayBits;

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
      if( displayBits != UIWindowNeedsAnimation)
         return( 0.0);

      rate = animationRate;
   }

   assert( now > stats->lastEndTimestamp);

   remainingFrameTime = rate - (now - stats->lastEndTimestamp); // - stats->avgElapsedHistory;

#ifdef DISPLAY_DEBUG
   MulleUILog( "frameRate: %.3f now: %.6f last: %.6f remaining: %.6f",
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
   MulleUILog( "window context");
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
   MulleUILog( "offscreen context");
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
   MulleUILog( "offscreen context");
#endif
      [_offscreenOSWindow os_deactivateGraphicsContext];
   }
   else
   {
#ifdef SWAP_DEBUG
      MulleUILog( "window context");
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
   struct UIOSWindowInfo   tmp;

   assert( info);
   assert( [NSThread mulleIsMainThread]);

   //
   // assumption is, the optimizing compiler will inline this with -O3
   // and then combine with settings
   //
   [_OSWindow getOSWindowInfo:&tmp];

   info->window        = tmp.base;
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
   MulleUILog( "info:%s previous:%s",
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


- (BOOL) renderWithFrameInfo:(struct CGFrameInfo *) info
                 displayBits:(NSUInteger) displayBits
{
   id <UIGraphicsContext>   context;
   BOOL                     didAnimate;

   context = [self activateRenderGraphicsContext];
   {
#ifdef RENDERINFO_DEBUG
      MulleUILog( "%s", CGFrameInfoUTF8String( info));
#endif
      // if the window size changed, we need to relayout
      if( ! CGSizeEqualToSize( info->window.frame.size, [self frame].size))
      {
         [self _setFrame:info->window.frame]; // don't trigger property change
         displayBits |= UIWindowNeedsLayout;
      }

      // This is usually UIWindowDefaultFrameCallback (UIWindow+Render.m)
      didAnimate = (*self->_renderFrameCallback)( self, context, info, displayBits);
   }
   [self deactivateContext:context];
   return( didAnimate);
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
   MulleUILog( "swap");
#endif

   [self changeSwapIntervalIfNeeded];
   [_OSWindow os_swapBuffers];

   //
   // from here on CGImages should be safe to be reaped by autorelease pool
   // or ?
   //
#ifdef SWAP_DEBUG
   MulleUILog( "\033[1mswapped buffers\033[0m");
#endif
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
