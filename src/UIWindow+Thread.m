//
// Copyright (c) 2022 Nat!, Mulle kybernetiK
//
#define _GNU_SOURCE

#import "UIWindow+Thread.h"

#import "import-private.h"

#import "UIWindow+Frame.h"
#import "UIWindow+Render.h"
#import "UIWindow+NSTimer.h"
#import "UIWindow+UIEvent.h"
#import "UIView+RenderQueue.h"

#define THREAD_DEBUG
//#define THREAD_DEBUG_VERBOSE
#define SWAP_DEBUG

// this writes out a PNG for each frame
// #define REFRESH_IMAGE_DEBUG
// catch race conditions (only works if picture drawn is not empty)
//#define MISSING_BARRIER_DEBUG
//#define RANDOM_SLEEP_DURING_DRAW


//#define DRAW_FRAMEBUFFER_ID_RECT



@implementation UIWindow ( Thread)

/*
 * UIWindowBackingStoreRetained :: threaded drawing
 */
#ifdef DEBUG
# define RENDER_THREAD_GRACE_PERIOD  240.0 // seconds
#else
# define RENDER_THREAD_GRACE_PERIOD  2.0 // seconds
#endif


- (void) startWindowThreadMainIfNeeded
{
   if( _backingStore != UIWindowBackingStoreRetained)
      return;

   _windowPropertyLock = [NSLock new];
   _windowThreadLock   = [[NSConditionLock alloc] initWithCondition:0];

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
   MulleUILog( "\033[1mwindow thread started\033[0m");
#endif
   // the window thread is now "somewhat" blocking, waiting for events
   //
}


- (void) finalizeWindowThread
{
   NSTimeInterval   timeout;

   assert( _windowThread && [NSThread mulleIsMainThread]);

#ifdef THREAD_DEBUG
   MulleUILogThisMethod();
#endif

   timeout = RENDER_THREAD_GRACE_PERIOD;

#ifdef THREAD_DEBUG
   MulleUILog( "trying to lock with 1 (%@ = %td, %s) (%.3f)",
               _windowThreadLock, [_windowThreadLock condition],
               [_windowThreadLock mulleIsLocked] ? "*LOCKED*" : "UNLOCKED",
               timeout);
#endif

   if( [_windowThreadLock mulleLockWhenCondition:1
                                         timeout:timeout])
   {
#ifdef THREAD_DEBUG
      MulleUILog( "locked with 1, unlocking with 2 (%@ = %td, %s)",
                  _windowThreadLock, [_windowThreadLock condition],
                  [_windowThreadLock mulleIsLocked] ? "*LOCKED*" : "UNLOCKED");
#endif
      // or place a shutdown event into the event pipe ? We are the only one
      // who cancel the thread. This means a thread could possibly have gone
      // down somehow or is in an endless loop if it doesn't catch this
      [_windowThread cancel];

      [_windowThreadLock unlockWithCondition:2];

#ifdef THREAD_DEBUG
      MulleUILog( "waiting for unlock to 1 (%@ = %td)",
                  _windowThreadLock, [_windowThreadLock condition]);
#endif

      if( [_windowThreadLock mulleLockWhenCondition:1
                                             timeout:timeout])
      {
         // windows thread is nicely gone
      }
      else
      {
         MulleUILog( "main draw thread still very busy (%@ = %td)",
                     _windowThreadLock, [_windowThreadLock condition]);
      }
   }
   else
   {
      MulleUILog( "Could not cancel the main draw thread in due time %@",
                  _windowThreadLock);
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

#ifdef THREAD_DEBUG
   MulleUILog( "\033[1mwindow thread stopped\033[0m");
#endif
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
   MulleUILog( "(%@ = %td, %s)",
               _windowThreadLock, [_windowThreadLock condition],
               [_windowThreadLock mulleIsLocked] ? "*LOCKED*" : "UNLOCKED");
#endif
   if( [_windowThreadLock tryLockWhenCondition:1])
   {
#ifdef THREAD_DEBUG
      MulleUILog( "unlocking %#@", _windowThread);
#endif
      [_windowThreadLock unlockWithCondition:2];
   }
   else
   {
#ifdef THREAD_DEBUG
      MulleUILog( "window thread is running it seems");
#endif
   }
}


- (mulle_relativetime_t) windowThreadTimeoutIsAnimating:(BOOL) isAnimating
{
   mulle_relativetime_t    timeout;
   struct UIOSWindowInfo   info;
   //
   // framerate can dynamically change, this could be precomputed on
   // frameRate change though
   //
   // UIWindowFrameRateAsync is INFINITY
   // UIWindowFrameRateSynced is -INFINITY
   // UIWindowFrameRateUnSynced is 0.0

   // In async, we need to be woken up by the main thread with
   // -wakeWindowsThread. This is the most energy saving mode
   //
   [_OSWindow getOSWindowInfo:&info];
   if( info.frameRateLimiter)
      return( INFINITY);

   if( info.frameRate == UIWindowFrameRateAsync)
   {
      if( ! isAnimating)
        return( INFINITY);

      timeout = info.refreshRate / 2.0;
   }
   else
      timeout = info.frameRate / 2.0;

   if( timeout < 1 / 8192.0)  // 8000 Hz
      timeout = 1 / 8192.0;
   if( timeout > 0.1)
      timeout = 0.1;
   return( timeout);
}


- (void) windowThreadMain:(NSLock *) windowThreadLock
{
   NSUInteger             mask;
   BOOL                   haveLock;
   BOOL                   didAnimate;
   NSTimeInterval         timeout;
   NSThread               *thread;
   NSUInteger             displayBits;
   struct CGFrameInfo     frameInfo;
   struct UIOSWindowInfo  windowInfo;
   mulle_absolutetime_t   now;
   mulle_relativetime_t   remainingFrameTime;
   double                 frameRate;
   NSAutoreleasePool      *pool;
   
   thread = [NSThread currentThread];
   [thread mulleSetNameUTF8String:"UIWindowThread"];

#ifdef THREAD_DEBUG
   MulleUILog( "coming up (%@ = %td, %s)",
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
   haveLock   = YES;
   timeout    = INFINITY;
   didAnimate = NO;
   pool       = [NSAutoreleasePool new];

   assert( [self needsDisplay]);

   for(;;)
   {
#ifdef THREAD_DEBUG_VERBOSE
      MulleUILog( "locking and waiting for condition 2 (%@ = %td, %s) timeout=%.3f",
                  _windowThreadLock, [_windowThreadLock condition],
                  [_windowThreadLock mulleIsLocked] ? "*LOCKED*" : "UNLOCKED",
                  timeout);
#endif
      [pool mulleReleaseAllObjects];
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
               MulleUILog( "going down (%#@ = %td, %s)",
                        _windowThreadLock, [_windowThreadLock condition],
                        [_windowThreadLock mulleIsLocked] ? "*LOCKED*" : "UNLOCKED");
#endif
               goto done;
            }

            // if we don't have the lock (curious), we can't clearly
            // communicate with the main thread, so we just redo the wait
            // for lock. The cancel flag sticks
#ifdef THREAD_DEBUG
            MulleUILog( "waiting for final lock (%#@ = %td, %s)",
                        _windowThreadLock, [_windowThreadLock condition],
                        [_windowThreadLock mulleIsLocked] ? "*LOCKED*" : "UNLOCKED");
#endif
            break;
         }

         //
         // same code really as UIWindow( UIWindow) #159
         // check that in a frequency dependent mode, we draw stuff
         //
         [_OSWindow getOSWindowInfo:&windowInfo];

         // as long as we don't have valid framebuffer info there is nothing
         // to render
         assert( windowInfo.base.framebufferSize.width);
         assert( windowInfo.base.pixelRatio);

         now = mulle_absolutetime_now();

         remainingFrameTime = [self remainingFrameTime:now
                                             frameRate:windowInfo.frameRate
                                         animationRate:windowInfo.refreshRate
                                       frameStatistics:&_windowThreadStatistics
                                      frameRateLimiter:windowInfo.frameRateLimiter];

         displayBits = [self needsDisplayClearIfSet];
         if( remainingFrameTime == 0.0)
            displayBits |= UIWindowNeedsRedraw;

#ifdef THREAD_DEBUG
         MulleUILog( "displayBits = 0x%tx frameRate=%.6f remainingFrameTime=%.6f didAnimate=%btd, mask=0x%tx)",
                     displayBits,
                     windowInfo.frameRate,
                     remainingFrameTime,
                     didAnimate,
                     mask);
#endif

         if( displayBits)
         {
            frameInfo     = CGFrameInfoSFMake( windowInfo.base.frame,
                                               windowInfo.base.framebufferSize,
                                               windowInfo.base.pixelRatio);
            frameInfo.now = now;
            didAnimate    = [self renderWithFrameInfo:&frameInfo
                                          displayBits:displayBits];


#ifdef THREAD_DEBUG_VERBOSE
            MulleUILog( "done rendering");
#endif
            UIWindowDisplayFrameStatisticsUpdate( &_windowThreadStatistics,
                                                  now,
                                                  mulle_absolutetime_now());

            // do an inconvenient sleep to slow consumer down a bit
            #ifdef RANDOM_SLEEP_DURING_DRAW
            {
               struct timespec   sleep;

               sleep.tv_sec  = 0;
               sleep.tv_nsec = rand() % (1000 * 1000 * 1000); // up to 1  s
               nanosleep( &sleep, NULL) ;
            }
            #endif

            [self setNeedsRefresh];
            [UIEvent sendEmptyEvent];

            // if there is an animation going, set our animation displayBit
            // right back
            if( didAnimate)
                [self setNeedsAnimation];
         }

         [self pollInvocationQueues];

         mask  = [self executeTimerQueue];
         mask |= [self executeEventQueue];
      }
      while( mask);

      // nothing to do, wait for something to happen
      if( haveLock)
      {
         [_windowThreadLock unlockWithCondition:1];
#ifdef THREAD_DEBUG
         MulleUILog( "unlockWithCondition 1 (%@ = %td, %s)",
                        _windowThreadLock, [_windowThreadLock condition],
                        [_windowThreadLock mulleIsLocked] ? "*LOCKED*" : "UNLOCKED");
#endif
      }
      else
      {
#ifdef THREAD_DEBUG_VERBOSE
         MulleUILog( "haveNoLock (%@ = %td, %s)",
                        _windowThreadLock, [_windowThreadLock condition],
                        [_windowThreadLock mulleIsLocked] ? "*LOCKED*" : "UNLOCKED");
#endif
      }

      // MEMO: the window thread doesn't need to lock indefinitely, the
      //       condition lock is there to conserve energy and cycles, so
      //       it doesn't busy loop.
      timeout = [self windowThreadTimeoutIsAnimating:didAnimate];
      if( timeout > remainingFrameTime)
         timeout = remainingFrameTime;
   }

done:
   [pool release];
}


// ** THIS PART IS RUNNING IN THE MAIN THREAD ***
// The refresh is called during event window refresh and in the main
// loop when a refresh is needed for thread windows.
// The main loop redraw does not refresh
//
- (void) refresh
{
   BOOL                     isScaling;
   CGColor                  color;
   CGRect                   imageFrame;
   CGRect                   rect;
   CGSize                   imageSize;
   id <UIGraphicsContext>   context;
   id <UIImage>             image;
   id <UILayer>             layer;
   CGContentMode            refreshContentMode;
   struct CGFrameInfo       frameInfo;

   assert( [NSThread mulleIsMainThread]);
   assert( _backingStore != UIWindowBackingStoreVolatile);

   @autoreleasepool
   {
      // TODO: voodoo barrier, should be useless
      // [_offscreenContext barrier];
      layer = [_offscreenContext acquireOffscreenFramebuffer];
      if( ! layer)
      {
         // if we still have a layer, use it
         layer = _lastOffscreenFramebuffer;
         if( ! layer)
         {
            mulle_fprintf( stderr, "%#@ has nothing to display (yet ?)\n", self);
            return;
         }
#ifdef SWAP_DEBUG
         MulleUILog( "Reuse previously acquired offscreen framebuffer layer %#@", layer);
#endif
      }
      else
      {
#ifdef SWAP_DEBUG
         MulleUILog( "Acquired freshly drawn layer %#@, recycling layer %#@", layer, _lastOffscreenFramebuffer);
#endif
         // recycle our old framebuffer
         assert( _lastOffscreenFramebuffer != layer);

         [_offscreenContext recycleFramebuffer:_lastOffscreenFramebuffer];
         [_lastOffscreenFramebuffer autorelease];

         _lastOffscreenFramebuffer = [layer retain];
      }

//  // hack, because render thread could be active
//  context = [self activateRenderGraphicsContext];
//  {
//     static int   nr;
//     char         *s;
//
//     s = MulleObjC_asprintf( "layer-%d.png", ++nr);
//     [[layer bitmapImage] writeToPNGUTF8String:s];
//  }
//  [self deactivateGraphicsContext:context];

      context = [self activateWindowGraphicsContext];
      {
         [self getFrameInfo:&frameInfo];

#ifdef SWAP_DEBUG
         MulleUILog( "Begin render");
#endif
         // TODO: voodoo barrier, possibly useless
         // [context barrier];
         [context beginRender:&frameInfo];

         refreshContentMode = [self refreshContentMode];
         isScaling          = CGContentModeIsScaling( refreshContentMode);
         if( ! isScaling)
         {
            color = [self backgroundColor];
            [context clearFramebufferWithColor:color];
         }

         rect.origin = CGPointZero;
         rect.size   = frameInfo.window.frame.size;

#ifdef SWAP_DEBUG
         MulleUILog( "Acquire image");
#endif
         image       = [_offscreenContext shareImage:layer
                                         withContext:context];
         assert( image);

         imageSize   = [image size];
         imageFrame  = CGSizePlaceInRect( imageSize, rect, refreshContentMode);

#ifdef MISSING_BARRIER_DEBUG
         {
            id   bitmapImage;

            bitmapImage = [image bitmapImage];
            if( [bitmapImage isFullyTransparent])
            {
               fprintf( stderr, "missing barrier ?\n");
               abort();
            }
         }
#endif
#ifdef SWAP_DEBUG
         MulleUILog( "Refresh with image %#@", image);
#endif
         [context drawRect:imageFrame
                     image:image
                     scale:isScaling];

         if( _debugEnabled & UIWindowDrawFramebufferIdRect)
         {
            [context strokeRect:CGRectInset( rect, 20, 20)
                        color:CGColorMakeWithHexColor( 0x20A080FF)
                        width:4.0];
         }

#ifdef REFRESH_IMAGE_DEBUG
         MulleUIWriteImageToPNGFileSequenceAsync( image, "refresh-image");
#endif

#ifdef SWAP_DEBUG
         MulleUILog( "Drew image %#@ of size %.1f %.1f into %.1f %.1f %.1f %.1f for refresh",
                           image,
                           imageSize.width, imageSize.height,
                           imageFrame.origin.x, imageFrame.origin.y,
                           imageFrame.size.width, imageFrame.size.height);
#endif
         [context endRender];
      }
      [self deactivateGraphicsContext:context]; 
   }
}

@end
