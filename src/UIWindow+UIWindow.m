//
// Copyright (c) 2021 Nat!, Mulle kybernetiK
//
#define _GNU_SOURCE

#import "UIWindow+UIWindow.h"

#import "import-private.h"

#import "UIWindow+Frame.h"
#import "UIWindow+Thread.h"

#define DISPLAY_DEBUG


//
// This is called by UIApplication. The main thread is responsible for
// refreshing windows. The displayFrameIfNeeded:nextCallSchedule:
// is also implemented by GLFWOSWindow...
//
@implementation UIWindow( UIWindow)

- (mulle_relativetime_t) displayAndRefreshRate
{
   return( _lastDidFramebufferSwapTimestamp - _lastDisplayStartTimestamp);
}
//
// returns 0.0 : means refresh/redraw now
// otherwise the remainingFrameTime before paint
//
- (mulle_relativetime_t) remainingFrameTime:(double) fastestFrameRate
                                        now:(mulle_absolutetime_t) now
{
   mulle_relativetime_t   diff;
   mulle_relativetime_t   elapsed;
   mulle_relativetime_t   minElapsed;
   mulle_relativetime_t   maxElapsed;
   mulle_relativetime_t   avgElapsed;

   BOOL                   frameTimeReached;
   double                 remainingFrameTime;
   unsigned int           i;

   // first run always draw
   if( _lastDidFramebufferSwapTimestamp == 0.0)
      return( 0.0);

   if( _frameRate == UIWindowFrameRateUnsynced)
      return( 0.0);

   if( _frameRate == UIWindowFrameRateAsync)
   {
      if( ! [self needsDisplay])
         return( INFINITY);
      return( 0.0);
   }

   avgElapsed = 0.0;
   maxElapsed = 0.0;

   for( i = 0; i < UIWINDOW_S_ELAPSED_HISTORY; i++)
      avgElapsed += _elapsedHistory[ i];
   avgElapsed /= UIWINDOW_S_ELAPSED_HISTORY;

   // time passed since last display
   diff    = now - _lastDidFramebufferSwapTimestamp;
   assert( now > _lastDidFramebufferSwapTimestamp);
   remainingFrameTime = fastestFrameRate - diff - avgElapsed;

#ifdef DISPLAY_DEBUG
   mulle_fprintf( stderr, "%#@: %#@ %s frameRate: %.3f now: %.6f last: %.6f remaining: %.6f\n",
                                [NSThread currentThread], self, __PRETTY_FUNCTION__,
                                fastestFrameRate,
                                now,
                                _lastDidFramebufferSwapTimestamp,
                                remainingFrameTime);
#endif

   if( remainingFrameTime <= 0.0)
      return( 0.0);

   if( _frameRateLimiter)
   {
      if( ! [self needsDisplay])
         return( INFINITY);
   }

   return( remainingFrameTime);
}


- (mulle_relativetime_t) displayFrameIfNeeded:(mulle_absolutetime_t) now
{
   BOOL                    needsRefresh;
   BOOL                    needsDisplay;
   BOOL                    frameTimeReached;
   mulle_relativetime_t    remainingFrameTime;
   double                  slowestFrameRate;
   double                  fastestFrameRate;
   double                  diff;
   mulle_absolutetime_t    lastFramebufferSwapTimestamp;
   NSUInteger              displayBits;
   struct CGFrameInfo      info;

   assert( [NSThread mulleIsMainThread]);

   needsRefresh = [self needsRefreshClearIfSet];
#ifdef DISPLAY_DEBUG
   mulle_fprintf( stderr, "%#@: %#@ needsRefresh=%s\n",
                                [NSThread currentThread], self, needsRefresh ? "YES" : "NO");
#endif
   // We get called, but do we really need to do something already ?
   //
   // ## **UIWindowBackingStoreRetained**
   //
   // The UIWindow backing store polls, the "needsDisplay" is handled by the
   // drawThread. So the frameTime is tied to redraw and not handled here. If
   // an events hits in an async configuration, it will set the needsRedraw
   // flag. When the thread is done drawing it will hit us here with
   // needsRefresh.
   //
   if( _backingStore != UIWindowBackingStoreVolatile)
   {
      // main thread: handle refresh request
      if( needsRefresh)
      {
#ifdef DISPLAY_DEBUG
         mulle_fprintf( stderr, "%#@: %#@ refresh and swap\n",
                                [NSThread currentThread], self);
#endif
         if( _backingStore == UIWindowBackingStoreRetainedOnMainThread)
         {
            displayBits = [self needsDisplayClearIfSet];
            [self getFrameInfo:&info];  // retrieve newest geometry
            [self renderWithFrameInfo:&info
                  displayBits:displayBits];
         }
         [self refresh];
         [self swapBuffers];
      }
#ifdef DISPLAY_DEBUG
         mulle_fprintf( stderr, "%#@: %#@ wait inf\n",
                                [NSThread currentThread], self);
#endif
      return( INFINITY);  // call me for events only ?
   }

   //
   // ## **UIWindowBackingStoreVolatile**
   //
   // In the volatile arrangement, we have to redraw/refresh, except if
   // frameTime is not reached yet. If we need to refresh we need to do it
   // immediately, if we need to redraw only, we can wait until the frameTime.
   //

   fastestFrameRate   = [self fastestFrameRate];
   remainingFrameTime = [self remainingFrameTime:fastestFrameRate
                                             now:now];
   if( ! needsRefresh && remainingFrameTime != 0.0)
   {
#ifdef DISPLAY_DEBUG
      mulle_fprintf( stderr, "%#@: %#@ %s wait %.4f s\n",
                             [NSThread currentThread], self, __PRETTY_FUNCTION__, remainingFrameTime);
#endif
      return( remainingFrameTime);
   }

   slowestFrameRate   = [self slowestFrameRate];

#ifdef DISPLAY_DEBUG
   mulle_fprintf( stderr, "%#@: %#@ UIWindowBackingStoreVolatile:: renderFrame and swapBuffers (%.3f)\n",
                          [NSThread currentThread], self, remainingFrameTime);
#endif

   displayBits = [self needsDisplayClearIfSet];
   displayBits |= UIWindowNeedsRedraw;
   [self getFrameInfo:&info];  // retrieve newest geometry
   [self renderWithFrameInfo:&info
         displayBits:displayBits];

   // no refresh in UIWindowBackingStoreVolatile
   [self swapBuffers];

   // no atomics for double

   _lastDidFramebufferSwapTimestamp = mulle_absolutetime_now();
   _lastDisplayStartTimestamp       = now;
   diff                             = _lastDidFramebufferSwapTimestamp - _lastDisplayStartTimestamp;

   // time spent for display last time
   _elapsedHistory[ _elapsedHistoryIndex] = diff;
   _elapsedHistoryIndex                   = (_elapsedHistoryIndex + 1) & (UIWINDOW_S_ELAPSED_HISTORY - 1);

   //
   // the UIApplication will notice the time spent and reduce remainingFrameTime
   //
#ifdef DISPLAY_DEBUG
   mulle_fprintf( stderr, "%#@: %#@ wait %.4fs\n",
                           [NSThread currentThread], self, remainingFrameTime);
#endif

   return( remainingFrameTime);
}

@end
