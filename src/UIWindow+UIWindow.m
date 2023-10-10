//
// Copyright (c) 2021 Nat!, Mulle kybernetiK
//
#define _GNU_SOURCE

#import "UIWindow+UIWindow.h"

#import "import-private.h"

#import "UIWindow+Frame.h"
#import "UIWindow+Render.h"
#import "UIWindow+Thread.h"
#import "UIWindow+DebugPrivate.h"
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
   BOOL                    needsRefresh;
   double                  fastestFrameRate;
   double                  desiredFrameRate;
   mulle_relativetime_t    remainingFrameTime;
   struct CGFrameInfo      frameInfo;
   struct UIOSWindowInfo   windowInfo;
   UIWindowDisplayBits     displayBits;

   assert( [NSThread mulleIsMainThread]);

   displayBits  = 0;
   needsRefresh = [self needsRefreshClearIfSet];

   // this checks "refresh" events only, it can be NO, but still "display"
   // may be set. The user usually never touches the refresh flag
   UIWindowRenderLogVerbose( "needsRefresh=%s", needsRefresh ? "YES" : "NO");

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
         UIWindowRenderLog( "refresh and swap");

         if( _backingStore == UIWindowBackingStoreRetainedOnMainThread)
         {
            displayBits = [self needsDisplayBitsClearIfSet];
            [self getFrameInfo:&frameInfo];  // retrieve newest geometry
            displayBits = [self renderWithFrameInfo:&frameInfo
                                        displayBits:displayBits];
         }
         [self refresh];
         [self swapBuffers];
         [self setNeedsDisplayBits:displayBits];
      }

      if( displayBits & UIWindowDisplayNeedsAnimation)
      {
         desiredFrameRate = UIWindowGetAnimationRate( self);         

         UIWindowRenderLogVerbose( "wait %.6fs", desiredFrameRate);
         return( desiredFrameRate);  // call me for events only ?
      }

      UIWindowRenderLog( "wait inf");
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
      UIWindowRenderLogVerbose( "wait %.6f s", remainingFrameTime);
      return( remainingFrameTime);
   }

   UIWindowRenderLog( "UIWindowBackingStoreVolatile -> renderFrame and swapBuffers (%.6f)",
                         remainingFrameTime);

   //
   // After swapBuffers we can safely release the CGLayers that were
   // possibly generated during the render. But not earlier, except if
   // one diligently calls flushRender
   //
   displayBits  = [self needsDisplayBitsClearIfSet];
   displayBits |= UIWindowDisplayNeedsRedraw;
   [self getFrameInfo:&frameInfo];  // retrieve newest geometry
   displayBits  = [self renderWithFrameInfo:&frameInfo
                                displayBits:displayBits];

   // no refresh in UIWindowBackingStoreVolatile
   [self swapBuffers];
   [self setNeedsDisplayBits:displayBits];

   // now is the old now...
   UIWindowDisplayFrameStatisticsUpdate( &_mainThreadStatistics, now, mulle_absolutetime_now());

   //
   // the UIApplication will notice the time spent and reduce remainingFrameTime
   // If we hard sync, we don't
   //
   desiredFrameRate = 0.0;
   if( ! _swapInterval)
   {
      if( displayBits & UIWindowDisplayNeedsAnimation)
         desiredFrameRate = UIWindowGetAnimationRate( self);
      else
         desiredFrameRate = UIOSWindowInfoGetSlowestFrameRate( &windowInfo);
   }

   UIWindowRenderLogVerbose( "wait %.6fs", desiredFrameRate);

   return( desiredFrameRate);
}

@end
