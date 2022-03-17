//
// Copyright (c) 2022 Nat!, Mulle kybernetiK
//
#define _GNU_SOURCE

#import "UIWindow+Thread.h"

#import "import-private.h"

#import "UIWindow+Frame.h"
#import "UIWindow+Render.h"
#import "UIWindow+UIEvent.h"
#import "UIView+RenderQueue.h"

// #define LAYOUT_ANIMATIONS
#define THREAD_DEBUG
//#define THREAD_DEBUG_VERBOSE



@implementation UIWindow ( Thread)

/*
 * UIWindowBackingStoreRetained :: threaded drawing
 */

#define RENDER_THREAD_GRACE_PERIOD  2.0 // seconds

- (void) initWindowThreadMainIfNeeded
{
   if( _backingStore != UIWindowBackingStoreRetained)
      return;

   _windowPropertyLock = [NSLock new];

   _windowThreadLock = [[NSConditionLock alloc] initWithCondition:0];

   // the _windowThreadLock needs to **unlock** this lock, when it's going
   // down, idiotically POSIX requires the unlock to be from
   // the same thread as the lock came from (ARGH!!!!) so we lock it first
   // the _windowThread will block. We unlock and then retryLock until
   // we fail...
   _windowThread = [[NSThread alloc] initWithTarget:self
                                           selector:@selector( windowThreadMain:)
                                             object:_windowThreadLock];

   [_windowThread start];

   // condition will be set to 1 by _windowThread
   if( ! [_windowThreadLock mulleLockWhenCondition:1
                                             timeout:RENDER_THREAD_GRACE_PERIOD])
   {
      fprintf( stderr, "Could not spin off render thread in %.f seconds\n", RENDER_THREAD_GRACE_PERIOD);
      abort();
   }

   // now give the 2 to windows thread
   [_windowThreadLock unlockWithCondition:2];

#ifdef THREAD_DEBUG
   mulle_fprintf( stderr, "%@: %@ window thread started\n",
                           [NSThread currentThread], self);
#endif
   // the window thread is now "somewhat" blocking, waiting for events
   //
}

- (void) finalizeWindowThread
{
   NSTimeInterval   timeout;

   if( ! _windowThread)
      return;

#ifdef THREAD_DEBUG
   mulle_fprintf( stderr, "%@: %@ %s\n",
                        [NSThread currentThread], self, __PRETTY_FUNCTION__);
#endif

   timeout = RENDER_THREAD_GRACE_PERIOD;

#ifdef THREAD_DEBUG
   mulle_fprintf( stderr, "%@: %@ trying to lock with 1 (%@ = %td, %s) (%.3f)\n",
                           [NSThread currentThread], self,
                           _windowThreadLock, [_windowThreadLock condition],
                           [_windowThreadLock mulleIsLocked] ? "*LOCKED*" : "UNLOCKED",
                           timeout);
#endif

   if( [_windowThreadLock mulleLockWhenCondition:1
                                          timeout:timeout])
   {
#ifdef THREAD_DEBUG
      mulle_fprintf( stderr, "%@: %@ locked with 1, unlocking with 2 (%@ = %td, %s)\n",
                              [NSThread currentThread], self,
                           _windowThreadLock, [_windowThreadLock condition],
                           [_windowThreadLock mulleIsLocked] ? "*LOCKED*" : "UNLOCKED");
#endif
      // or place a shutdown event into the event pipe ? We are the only one
      // who cancel the thread. This means a thread could possibly have gone
      // down somehow or is in an endless loop if it doesn't catch this
      [_windowThread cancel];

      [_windowThreadLock unlockWithCondition:2];

#ifdef THREAD_DEBUG
      mulle_fprintf( stderr, "%@: %@ waiting for unlock to 1 (%@ = %td)\n",
                              [NSThread currentThread], self,
                              _windowThreadLock, [_windowThreadLock condition]);
#endif

      if( [_windowThreadLock mulleLockWhenCondition:1
                                             timeout:timeout])
      {
         // windows thread is nicely gone
      }
      else
      {
         mulle_fprintf( stderr, "%@: %@ main draw thread still very busy (%@ = %td)\n",
                              [NSThread currentThread], self,
                              _windowThreadLock, [_windowThreadLock condition]);
      }
   }
   else
   {
      mulle_fprintf( stderr, "%@: %@ could not cancel the main draw thread in due time %@\n",
                              [NSThread currentThread], self, _windowThreadLock);
   }


   // we have to wait for the thread to come down though, tricky problems
   // how do we know the thread is not hung ? (not sure)
   // how do we know the thread hasn't exited yet ? If it exited normally
   // the lock can be locked, and we can pass througjh
   // we can't touch anything here until the thread is down

   // wait for lock to be acquirable
   // if we need to wait for more than 0.25s,
   [_windowThreadLock autorelease];
   _windowThreadLock = nil;
   [_windowThread autorelease];
   _windowThread = nil;
   [_windowPropertyLock autorelease];
   _windowPropertyLock = nil;
}

//
// When the window thread is idle, it's 1. If we set to 2 the window thread
// should notice immediately, do something and then return to 1, when it's
// done. If there is no windowThread, _windowThreadLock is nil and this
// method does nothing.
//
- (void) wakeupWindowThread
{
#ifdef THREAD_DEBUG
   mulle_fprintf( stderr, "%@: %s (%@ = %td, %s)\n",
                        [NSThread currentThread], __PRETTY_FUNCTION__,
                        _windowThreadLock, [_windowThreadLock condition],
                        [_windowThreadLock mulleIsLocked] ? "*LOCKED*" : "UNLOCKED");
#endif
   if( [_windowThreadLock tryLockWhenCondition:1])
      [_windowThreadLock unlockWithCondition:2];
}


- (mulle_relativetime_t) windowThreadTimeout
{
   mulle_relativetime_t   timeout;
   //
   // framerate can dynamically change, this could be precomputed on
   // frameRate change though
   //
   // UIWindowFrameRateAsync is INFINITY
   // UIWindowFrameRateSynced is -INFINITY
   // UIWindowFrameRateUnSynced is 0.0

   // In async, we need to be woken up by the main thread with
   // -wakeWindowsThread. This is the most energy saving mode
   return( INFINITY);

   if( _frameRate == UIWindowFrameRateAsync || _frameRateLimiter)
      return( INFINITY);

   timeout = _frameRate / 2.0;
   if( timeout < 1 / 8192.0)  // 8000 Hz
      timeout = 1 / 8192.0;
   if( timeout > 0.1)
      timeout = 0.1;
   return( timeout);
}


- (void) windowThreadMain:(NSLock *) windowThreadLock
{
   mulle_absolutetime_t   lastRedraw;
   NSUInteger             mask;
   BOOL                   haveLock;
   NSTimeInterval         timeout;
   NSThread               *thread;
   NSUInteger             displayBits;
   struct CGFrameInfo     info;

   thread = [NSThread currentThread];
   [thread mulleSetNameUTF8String:"UIWindowThread"];

#ifdef THREAD_DEBUG
   mulle_fprintf( stderr, "%@: %s coming up (%@ = %td, %s)\n",
                        [NSThread currentThread], __PRETTY_FUNCTION__,
                     _windowThreadLock, [_windowThreadLock condition],
                     [_windowThreadLock mulleIsLocked] ? "*LOCKED*" : "UNLOCKED");
#endif

   //
   // state machine
   //  idle (0) -> running 1 -> (2) wakeup
   //

   // if we really block here forever, so be it. The main thread must have
   // some real problems
   [_windowThreadLock lockWhenCondition:0];
   [_windowThreadLock unlockWithCondition:1];

   //
   // The first time around we wait infinitely. This ensures that we don't
   // draw a blank so to speak.
   //
   haveLock = YES;
   timeout  = INFINITY;

   assert( [self needsDisplay]);

   for(;;)
   {
#ifdef THREAD_DEBUG_VERBOSE
      mulle_fprintf( stderr, "%@: %s waiting for condition 2 (%@ = %td, %s) (%.3f)\n",
                     [NSThread currentThread], __PRETTY_FUNCTION__,
                     _windowThreadLock, [_windowThreadLock condition],
                     [_windowThreadLock mulleIsLocked] ? "*LOCKED*" : "UNLOCKED",
                     timeout);
#endif

      haveLock = [_windowThreadLock mulleLockWhenCondition:2
                                                   timeout:timeout];

      do
      {
         if( [thread isCancelled])
         {
            if( haveLock)
            {
               [_windowThreadLock unlockWithCondition:1];
#ifdef THREAD_DEBUG
               mulle_fprintf( stderr, "%@: %s going down (%@ = %td, %s)\n",
                        [NSThread currentThread], __PRETTY_FUNCTION__,
                        _windowThreadLock, [_windowThreadLock condition],
                        [_windowThreadLock mulleIsLocked] ? "*LOCKED*" : "UNLOCKED");
#endif
               return;
            }

            // if we don't have the lock (curious), we can't clearly
            // communicate with the main thread, so we just redo the wait
            // for lock. The cancel flag sticks
#ifdef THREAD_DEBUG
            mulle_fprintf( stderr, "%@: %s waiting for final lock (%@ = %td, %s)\n",
                        [NSThread currentThread], __PRETTY_FUNCTION__,
                        _windowThreadLock, [_windowThreadLock condition],
                        [_windowThreadLock mulleIsLocked] ? "*LOCKED*" : "UNLOCKED");
#endif
            break;
         }

         // as long as we don't have valid framebuffer info there is nothing
         // to render
         assert( _currentWindowInfo.framebufferSize.width);
         assert( _currentWindowInfo.pixelRatio);

         {
            displayBits = [self needsDisplayClearIfSet];
#ifdef THREAD_DEBUG
            mulle_fprintf( stderr, "%@: %s displayBits = 0x%tx\n",
                           [NSThread currentThread], __PRETTY_FUNCTION__,
                           displayBits);
#endif
            if( displayBits)
            {
               info     = CGFrameInfoSFMake( [self frame], _currentWindowInfo.framebufferSize, _currentWindowInfo.pixelRatio);
               info.now = mulle_absolutetime_now();
               [self renderWithFrameInfo:&info
                             displayBits:displayBits];

               [self setNeedsRefresh];
               [UIEvent sendEmptyEvent];
            }
         }

         mask = [self handleEventQueue];
      }
      while( mask);

      // nothing to do, wait for something to happen
      if( haveLock)
      {
         [_windowThreadLock unlockWithCondition:1];
#ifdef THREAD_DEBUG
         mulle_fprintf( stderr, "%@: %s unlockWithCondition 1 (%@ = %td, %s)\n",
                        [NSThread currentThread], __PRETTY_FUNCTION__,
                        _windowThreadLock, [_windowThreadLock condition],
                        [_windowThreadLock mulleIsLocked] ? "*LOCKED*" : "UNLOCKED");
#endif
      }
      else
      {
#ifdef THREAD_DEBUG_VERBOSE
         mulle_fprintf( stderr, "%@: %s haveNoLock (%@ = %td, %s)\n",
                        [NSThread currentThread], __PRETTY_FUNCTION__,
                        _windowThreadLock, [_windowThreadLock condition],
                        [_windowThreadLock mulleIsLocked] ? "*LOCKED*" : "UNLOCKED");
#endif
      }

      // MEMO: the window thread doesn't need to lock indefinitely, the
      //       condition lock is there to conserve energy and cycles, so
      //       it doesn't busy loop.
      timeout = [self windowThreadTimeout];
   }
}


// ** THIS PART IS RUNNING IN THE MAIN THREAD ***
// The refresh is called during event window refresh and in the main
// loop when a refresh is needed for thread windows.
// The main loop redraw does not refresh
//
- (void) refresh
{
   CGRect                   rect;
   CGRect                   imageFrame;
   id <UIGraphicsContext>   context;
   id <UILayer>             layer;
   struct CGFrameInfo       info;
   id <UIImage>             image;
   BOOL                     isScaling;
   CGSize                   imageSize;
   CGColor                  color;
   NSUInteger               refreshContentMode;

   assert( [NSThread mulleIsMainThread]);
   assert( _backingStore != UIWindowBackingStoreVolatile);


   layer = [_offscreenContext acquireOffscreenFramebuffer];
   if( ! layer)
   {
      // if we still have a layer, use it
      layer = _lastLayer;
      if( ! layer)
      {
         mulle_fprintf( stderr, "%@ has nothing to display (yet ?)\n", self);
         return;
      }
   }
   else
   {
      // recycle our old framebuffer
      [_offscreenContext recycleFramebuffer:_lastLayer];
      [_lastLayer autorelease];

      _lastLayer = [layer retain];
   }

#ifdef SWAP_DEBUG
   mulle_fprintf( stderr, "%@: %s %@ (layer %@)\n",
            [NSThread currentThread], __PRETTY_FUNCTION__, self, layer);
#endif

//  // hack, because render thread could be active
//  context = [self activateRenderGraphicsContext];
//  {
//     static int   nr;
//     char         *s;
//
//     s = MulleObjC_asprintf( "layer-%d.png", ++nr);
//     [[layer bitmapImage] writeToPNGFileWithSystemRepresentation:s];
//  }
//  [self deactivateContext:context];

   context = [self activateWindowGraphicsContext];
   {
      [self getFrameInfo:&info];

      [context beginRender:&info];

      refreshContentMode = [self refreshContentMode];
      isScaling          = CGContentModeIsScaling( refreshContentMode);
      if( ! isScaling)
      {
         color = [self backgroundColor];
         [context clearFramebufferWithColor:color];
      }

      rect.origin = CGPointZero;
      rect.size   = info.window.frame.size;

      image       = [_offscreenContext shareImage:layer
                                      withContext:context];

      imageSize   = [image size];
      imageFrame  = CGSizePlaceInRect( imageSize, rect, refreshContentMode);

#ifdef SWAP_DEBUG
      // [[image bitmapImage] writeToPNGFileWithSystemRepresentation:"swap.png"];
      mulle_fprintf( stderr, "%@: UIWindow %@ draws image %.1f %.1f into %.1f %.1f %.1f %.1f for refresh\n",
                        [NSThread currentThread], self,
                        imageSize.width, imageSize.height,
                        imageFrame.origin.x, imageFrame.origin.y,
                        imageFrame.size.width, imageFrame.size.height);
#endif

      [context drawRect:imageFrame
                  image:image
                  scale:isScaling];
#if DEBUG
      [context strokeRect:CGRectInset( rect, 20, 20)
                    color:CGColorMakeWithHexColor( 0x20A080FF)
                    width:4.0];
#endif
      [context endRender];
   }
   [self deactivateContext:context];
}

@end
