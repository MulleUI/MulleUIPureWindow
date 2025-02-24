//
// Copyright (c) 2021 Nat!, Mulle kybernetiK
//
#define _GNU_SOURCE

#import "UIWindow+FrameInfo.h"

#import "import-private.h"

#import "UIWindow+DebugPrivate.h"
#import "UIWindow+Layout.h"
#import "UIWindow+UIResponder.h"
#import "UIWindow+UIEvent.h"
#import "UIView+UIFirstResponder.h"
#import "CGFrameInfo+UTF8String.h"


//#define RENDERINFO_DEBUG


@interface UIWindow( Private)

- (void) _setPosition:(CGPoint) position;
//- (void) _setSize:(CGSize) size;
- (void) _setFrame:(CGRect) rect;
//- (void) _setFramebufferSize:(CGPixelSize) size;

@end


@implementation UIWindow ( FrameInfo)

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


- (UIWindowDisplayBits) render_adjustFrameWithFrameInfo:(struct CGFrameInfo *) info
                                            displayBits:(UIWindowDisplayBits) displayBits

{
   // if the window size changed, we need to relayout
   if( ! CGSizeEqualToSize( info->window.frame.size, [self frame].size))
   {
      [self _setFrame:info->window.frame]; // don't trigger property change
      displayBits |= UIWindowDisplayNeedsLayout;
   }
   return( displayBits);
}


- (void) render_setupInitialFirstResponderIfNeeded
{
   id <UIResponder>   responder;

   if( ! _initialFirstResponderState)
   {
      responder = _initialFirstResponder;
      if( ! _initialFirstResponder)
         responder = [[self contentView] nextFirstResponder];
      [responder becomeFirstResponder];
      _initialFirstResponderState = responder ? 1 : -1;
   }
}


//
// Assume the user does not move the mouse, but the view is animating the
// view may slide under the mouse pointer and we want highlighting to occur.
// We do this by sending a fake mouse event, which will trigger the tracking.
//
// Assume we are implementing "hover", now the fake mouse events destroys the
// hover as there is movement of the mouse implied. How to fix this ?
// We only want to hover if there is no physical movement of the mouse.
//
- (void) render_requestFakeMouseEventIfNeeded:(UIWindowDisplayBits) displayBits
{
   if( displayBits & UIWindowDisplayNeedsMouseEvent)
      UIWindowEventLogVerbose( nil, "requesting fake mouse motion event");

   _sendFakeMouseMotionEvent = (displayBits & UIWindowDisplayNeedsMouseEvent);
}


UIWindowDisplayBits
   UIWindowDefaultPrepareRenderQueue( UIWindow *self,
                                      struct CGFrameInfo *info,
                                      UIWindowDisplayBits displayBits)
{
   //
   // create the renderQueue. This will set the transforms for all
   // the layer and calculate the actual opacity, which is then stored
   // in layer transform and layer alpha.
   //
   [self createDrawingQueueForFrame:info];

   //
   // this animateFrame: runs unconditonally over the displayQueue
   // that will be then also be used by drawFrame:
   //
   displayBits = [self animateFrame:info
                       displayBits:displayBits];

   UIWindowDisplayBitsLog( "returns (0x%tx)", displayBits);
   return( displayBits);
}


- (UIWindowDisplayBits) renderWithFrameInfo:(struct CGFrameInfo *) info
                                displayBits:(UIWindowDisplayBits) displayBits
{

   UIWindowDisplayBits   returnBits;

   [self render_setupInitialFirstResponderIfNeeded];

   _isRendering = YES;

   MulleWindowProfileBegin();
   {
      //
      // the display bits are possibly expanded by
      // render_adjustFrameWithFrameInfo:displayBits:
      //
      UIWindowDisplayBitsLog( "starts with (0x%tx)", displayBits);
      displayBits = [self render_adjustFrameWithFrameInfo:info
                                              displayBits:displayBits];
      UIWindowDisplayBitsLog( "render_adjustFrameWithFrameInfo:displayBits: augmented to (0x%tx)", displayBits);

      // takes displayBits, returns zero unless animations happened + some user
      // bits
      returnBits = [self render_frameWithFrameInfo:info
                                      displayBits:displayBits];
      UIWindowDisplayBitsLog( "render_frameWithFrameInfo:displayBits: returned (0x%tx)", returnBits);
   }
   MulleWindowProfileEnd();

   _isRendering = NO;

   [self render_requestFakeMouseEventIfNeeded:returnBits];

   // do not kill UIWindowDisplayDidAnimate
   returnBits &= ~UIWindowDisplayNeedsMouseEvent;
   UIWindowDisplayBitsLog( "returns (0x%tx)", returnBits);
   return( returnBits);
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
