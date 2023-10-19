//
// Copyright (c) 2021 Nat!, Mulle kybernetiK
//
#define _GNU_SOURCE

#import "UIWindow+Frame.h"

#import "import-private.h"

#import "UIWindow+Render.h"
#import "UIWindow+DebugPrivate.h"
#import "UIWindow+UIEvent.h"
#import "UIView+UIResponder.h"
#import "UIView+RenderQueue.h"
#import "CGFrameInfo+UTF8String.h"


//#define FAKE_MOUSE_MOTION_CALLBACK_DEBUG
//#define SWAP_DEBUG
//#define RENDERINFO_DEBUG

@interface UIWindow( Private)

//- (void) _setPosition:(CGPoint) position;
//- (void) _setSize:(CGSize) size;
- (void) _setFrame:(CGRect) rect;
//- (void) _setFramebufferSize:(struct MulleIntegerSize) size;

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
   mulle_relativetime_t   remainingFrameTime;
   mulle_relativetime_t   rate;
   UIWindowDisplayBits   displayBits;

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
      if( displayBits != UIWindowDisplayNeedsAnimation)
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


- (id <UIGraphicsContext>) activateWindowGraphicsContext
{
   Class        cls;
   NSUInteger   options;

   assert( [NSThread mulleIsMainThread]);

   UIWindowSwapLog( "window context (%p)", _context);

   if( _keepOSGraphicsContextActive && _context)
   {
      [_context setActive:YES];
      return( _context);
   }

   [_OSWindow os_activateGraphicsContext];

   if( ! _context)
   {
      cls = [[self class] osGraphicsContextClass];

      options = 0;
      if( _styleMask & UIWindowStyleAntiAlias)
      {
         if( [_OSWindow isAntiAliasing] == NO ||
             [cls supportsAntiAliasing] == NO)
            options |= UIGraphicsEdgeAntiAliasing;
         else
            options |= UIGraphicsUseMSAA;
      }

      options |= (_styleMask & UIWindowStyleForceEdgeAntiAlias) ? UIGraphicsEdgeAntiAliasing : 0;
      options |= (_styleMask & UIWindowStyleClearType)          ? UIGraphicsUseClearType : 0;
      options |= (_styleMask & UIWindowStyleStencilStrokes)     ? UIGraphicsUseStencilStrokes : 0;

      _context = [[cls alloc] initWithBackend:[_OSWindow backend]
                                      shareID:[_OSWindow shareID]
                                      options:options];
      if( ! _context)
      {
         MulleUILog( "Could not acquire a graphics context for backend: 0x%tx shareID: 0x%tx options: 0x%tx",
                           [_OSWindow backend],
                           [_OSWindow shareID],
                           options);
         abort();
      }
      [_context setOSWindow:_OSWindow];

      UIWindowSwapLog( "context %#@ created for OSWindow %#@", _context, _OSWindow);
   }
   [_context setActive:YES];

   return( _context);
}


// TODO: memo, maybe the context triggers os_activateGraphicsContext ?
- (id <UIGraphicsContext>) activateOffscreenGraphicsContext
{
   Class        cls;
   NSUInteger   options;

   assert( (! _windowThread && [NSThread mulleIsMainThread]) ||
           [NSThread currentThread] == _windowThread);

   // take renderlock here, relinquish later when wating for events
   // or when someone closes the window

   assert( _offscreenOSWindow);

   UIWindowSwapLog( "offscreen window context (%pp)", _offscreenContext);

   if( _keepOSGraphicsContextActive && _offscreenContext)
   {
      [_offscreenContext setActive:YES];
      return( _offscreenContext);
   }

   [_offscreenOSWindow os_activateGraphicsContext];
   if( ! _offscreenContext)
   {
      cls     = [[self class] osGraphicsContextClass];
      options = 0;

      //
      // If the window supports antiAliasing, we might still have a CGContext
      // that is just running GLES2.0, so we then still have to force
      // EdgeAntiAliasing.
      //
      if( _offscreenStyleMask & UIWindowStyleAntiAlias)
      {
         if( [_OSWindow isAntiAliasing] == NO ||
             [cls supportsAntiAliasing] == NO)
            options |= UIGraphicsEdgeAntiAliasing;
         else
            options |= UIGraphicsUseMSAA;
      }

      options |= (_offscreenStyleMask & UIWindowStyleForceEdgeAntiAlias) ? UIGraphicsEdgeAntiAliasing : 0;
      options |= (_offscreenStyleMask & UIWindowStyleClearType)          ? UIGraphicsUseClearType : 0;
      options |= (_offscreenStyleMask & UIWindowStyleStencilStrokes)     ? UIGraphicsUseStencilStrokes : 0;

      _offscreenContext = [[cls alloc] initWithBackend:[_offscreenOSWindow backend]
                                               shareID:[_offscreenOSWindow shareID]
                                               options:options];
      if( ! _offscreenContext)
      {
         MulleUILog( "Could not acquire an offscren context for backend: 0x%tx shareID: 0x%tx options: 0x%tx",
                           [_offscreenOSWindow backend],
                           [_offscreenOSWindow shareID],
                           options);
         abort();
      }
      [_offscreenContext setRendersOffScreen:YES];
      [_context setOSWindow:_offscreenOSWindow];

      UIWindowSwapLog( "context %#@ created for offscreen OSWindow %#@",
                     _offscreenContext, _offscreenOSWindow);
   }
   [_offscreenContext setActive:YES];                        // just a flag

   UIWindowSwapLog( "offscreen context");

   return( _offscreenContext);
}


// TODO: memo, maybe the context triggers os_activateGraphicsContext ?
- (void) deactivateGraphicsContext:(id <UIGraphicsContext>) context
{
   assert( context);

   [context setActive:NO];

   if( context == _offscreenContext)
   {
      UIWindowSwapLog( "offscreen context");
      assert( (! _windowThread && [NSThread mulleIsMainThread]) ||
              [NSThread currentThread] == _windowThread);

      if( ! _keepOSGraphicsContextActive)
         [_offscreenOSWindow os_deactivateGraphicsContext];
   }
   else
   {
      UIWindowSwapLog( "window context");

      assert( [NSThread mulleIsMainThread]);

      if( ! _keepOSGraphicsContextActive)
         [_OSWindow os_deactivateGraphicsContext];
   }
}


- (id <UIGraphicsContext>) renderGraphicsContext
{
   id <UIGraphicsContext>  context;

   // calling this method outside of rendering is an error
   context = _renderGraphicsContext;
   if( ! [context isActive])
      abort();
   return( context);
}


- (void) activateRenderGraphicsContext
{
   assert( ! _renderGraphicsContext);

   _renderGraphicsContext = ( _backingStore == UIWindowBackingStoreVolatile) 
                            ? [self activateWindowGraphicsContext]
                            : [self activateOffscreenGraphicsContext];
}


- (void) deactivateRenderGraphicsContext
{
   assert( _renderGraphicsContext);
   [self deactivateGraphicsContext:_renderGraphicsContext];
   _renderGraphicsContext = nil;
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

   info->window        = tmp.base;
   info->viewportFrame = MulleIntegerRectMake( 0,
                                               0,
                                               info->window.framebufferSize.width,
                                               info->window.framebufferSize.height);
   info->alpha         = 1.0;
   info->now           = mulle_absolutetime_now();
}


- (void) syncFrameInfo:(struct CGFrameInfo *) info
{
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

- (UIWindowDisplayBits) renderWithFrameInfo:(struct CGFrameInfo *) info
                                displayBits:(UIWindowDisplayBits) displayBits
{
   id <UIResponder>   responder;

   [self activateRenderGraphicsContext];

   @autoreleasepool // THIS IS IMPORTANT TO COLLECT CGLAYERS WHILE THE PROPER CONTEXT IS ALIVE
   {
      UIWindowRenderLog( "%s", CGFrameInfoUTF8String( info));

      // for demos
      [_renderGraphicsContext setInputState:_inputState];

      // if the window size changed, we need to relayout
      if( ! CGSizeEqualToSize( info->window.frame.size, [self frame].size))
      {
         [self _setFrame:info->window.frame]; // don't trigger property change
         displayBits |= UIWindowDisplayNeedsLayout;
      }

      if( ! _initialFirstResponderState)
      {
         responder = _initialFirstResponder;
         if( ! _initialFirstResponder)
            responder = [self nextFirstResponder];
         [responder becomeFirstResponder];
         _initialFirstResponderState = responder ? 1 : -1;
      }

      displayBits = (*self->_willRenderFrameCallback)( self, _renderGraphicsContext, info, displayBits);
      // This is usually UIWindowDefaultRawFrameCallback (UIWindow+Render.m)
      displayBits = (*self->_rawFrameCallback)( self, _renderGraphicsContext, info, displayBits);
      displayBits = (*self->_didRenderFrameCallback)( self, _renderGraphicsContext, info, displayBits);
   }
   [self deactivateRenderGraphicsContext];

   if( displayBits & UIWindowDisplayNeedsMouseEvent)
      UIWindowEventLogVerbose( nil, "requesting fake mouse motion event");

   _sendFakeMouseMotionEvent = (displayBits & UIWindowDisplayNeedsMouseEvent);
   displayBits              &= ~UIWindowDisplayNeedsMouseEvent;

   return( displayBits);
}


- (void) changeSwapIntervalIfNeeded
{
   NSUInteger   swapInterval;
   BOOL         changeSwapInterval;

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

   [_OSWindow os_setSwapInterval:_swapInterval];  // need 0 for smooth pointer/control sync
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
      return;

   UIWindowSwapLog( "swap");

   context = [self activateWindowGraphicsContext];
   {
      [self changeSwapIntervalIfNeeded];
      [_OSWindow os_swapBuffers];
   }
   [self deactivateGraphicsContext:context];

   //
   // from here on CGImages should be safe to be reaped by autorelease pool
   // or ?
   //
   if( _didSwapBuffersCallback)
      (*_didSwapBuffersCallback)( self);
}


- (void) swapBuffersImmediately
{
   id <UIGraphicsContext>   context;

   UIWindowSwapLog( "swap immediately");

   context = [self activateWindowGraphicsContext];
   {
      [_OSWindow os_setSwapInterval:0]; 
      [_OSWindow os_swapBuffers];
      [_OSWindow os_setSwapInterval:_swapInterval];  // need 0 for smooth pointer/control sync
   }
   [self deactivateGraphicsContext:context];
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
