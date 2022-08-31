//
// Copyright (c) 2021 Nat!, Mulle kybernetiK
//
#define _GNU_SOURCE

#import "UIWindow+UIWindow.h"

#import "import-private.h"

#import "UIWindow+Frame.h"
#import "UIWindow+Thread.h"

//#define DISPLAY_DEBUG


//
// This is called by UIApplication. The main thread is responsible for
// refreshing windows. The displayFrameIfNeeded:nextCallSchedule:
// is also implemented by GLFWOSWindow...
//
@implementation UIWindow( UIWindow)

- (void) writeOSWindowPropertyChangesIfNeeded
{
   NSUInteger   changes;
   CGRect       frame;
   char         *title;
   void         *cursor;

   changes = (NSUInteger) _mulle_atomic_pointer_read( &_propertyChanges);
   if( ! changes)
      return;

   // if this fails sporadically, it's no biggy, but zeroing out nilly, willy
   // might lose a change
   _mulle_atomic_pointer_cas( &_propertyChanges, (void *) 0, (void *) changes);

   if( changes & UIWindowPropertyChangeFrame)
   {
      frame = [self frame];
#ifdef DEBUG
      MulleUILog( "push frame %.2f %.2f %.2f %.2f",
                              frame.origin.x, frame.origin.y,
                              frame.size.width, frame.size.height);
#endif
      [_OSWindow os_setWindowFrame:frame];
   }

   if( changes & UIWindowPropertyChangeTitle)
   {
      title = [self titleUTF8String];
#ifdef DEBUG
      MulleUILog( "push title %s",
                              title);
#endif
      [_OSWindow os_setTitleUTF8String:title];
   }

   if( changes & UIWindowPropertyChangeCursor)
   {
      cursor = [self cursor];
#ifdef DEBUG
      MulleUILog( "change cursor %p", cursor);
#endif
      [_OSWindow os_setCursor:cursor];
   }
}


- (mulle_relativetime_t) displayFrameIfNeeded:(mulle_absolutetime_t) now
{
   BOOL                    frameRateLimiter;
   BOOL                    frameTimeReached;
   BOOL                    needsDisplay;
   BOOL                    needsRefresh;
   double                  fastestFrameRate;
   double                  slowestFrameRate;
   mulle_absolutetime_t    lastFramebufferSwapTimestamp;
   mulle_relativetime_t    remainingFrameTime;
   NSUInteger              displayBits;
   struct CGFrameInfo      frameInfo;
   struct UIOSWindowInfo   windowInfo;

   assert( [NSThread mulleIsMainThread]);

   needsRefresh = [self needsRefreshClearIfSet];
#ifdef DISPLAY_DEBUG
   MulleUILog( "needsRefresh=%s", needsRefresh ? "YES" : "NO");
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
         MulleUILog( "refresh and swap");
#endif
         if( _backingStore == UIWindowBackingStoreRetainedOnMainThread)
         {
            displayBits = [self needsDisplayClearIfSet];
            [self getFrameInfo:&frameInfo];  // retrieve newest geometry
            [self renderWithFrameInfo:&frameInfo
                          displayBits:displayBits];
         }
         [self refresh];
         [self swapBuffers];
      }
#ifdef DISPLAY_DEBUG
      MulleUILog( "wait inf");
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

   [_OSWindow getOSWindowInfo:&windowInfo];
   fastestFrameRate   = UIOSWindowInfoGetFastestFrameRate( &windowInfo);
   remainingFrameTime = [self remainingFrameTime:now
                                       frameRate:fastestFrameRate
                                   animationRate:windowInfo.refreshRate
                                 frameStatistics:&_mainThreadStatistics
                                frameRateLimiter:windowInfo.frameRateLimiter];

   if( ! needsRefresh && remainingFrameTime != 0.0)
   {
#ifdef DISPLAY_DEBUG
      MulleUILog( "wait %.6f s", remainingFrameTime);
#endif
      return( remainingFrameTime);
   }

#ifdef DISPLAY_DEBUG
   MulleUILog( "UIWindowBackingStoreVolatile -> renderFrame and swapBuffers (%.6f)",
                         remainingFrameTime);
#endif

   displayBits  = [self needsDisplayClearIfSet];
   displayBits |= UIWindowNeedsRedraw;
   [self getFrameInfo:&frameInfo];  // retrieve newest geometry
   [self renderWithFrameInfo:&frameInfo
                displayBits:displayBits];

   // no refresh in UIWindowBackingStoreVolatile
   [self swapBuffers];

   // now is the old now...
   UIWindowDisplayFrameStatisticsUpdate( &_mainThreadStatistics, now, mulle_absolutetime_now());

   //
   // the UIApplication will notice the time spent and reduce remainingFrameTime
   // If we hard sync, we don't
   //
   slowestFrameRate = 0.0;
   if( ! _swapInterval)
      slowestFrameRate = UIOSWindowInfoGetSlowestFrameRate( &windowInfo);

#ifdef DISPLAY_DEBUG
   MulleUILog( "wait %.6fs", slowestFrameRate);
#endif

   return( slowestFrameRate);
}

@end
