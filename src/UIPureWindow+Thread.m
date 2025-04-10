//
// Copyright (c) 2022 Nat!, Mulle kybernetiK
//
#define _GNU_SOURCE

#import "UIPureWindow+Thread.h"

#import "import-private.h"

#import "UIPureWindow+DebugPrivate.h"
#import "UIPureWindow+FrameInfo.h"
#import "UIPureWindow+InvocationQueue.h"
#import "UIPureWindow+NSTimer.h"
#import "UIPureWindow+Render.h"
#import "UIPureWindow+ThreadRefresh.h"
#import "UIPureWindow+UIEvent.h"

// #define THREAD_DEBUG

// catch race conditions (only works if picture drawn is not empty)
// #define RANDOM_SLEEP_DURING_DRAW



@implementation UIPureWindow ( Thread)

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

   assert( ! _windowPropertyLock);
   assert( ! _windowThreadLock);
   assert( ! _windowThread);

   _windowPropertyLock = [NSLock new];
   _windowThreadLock   = [[NSConditionLock alloc] initWithCondition:0];

   // the _windowThreadLock needs to **unlock** this lock, when it's going
   // down, idiotically POSIX requires the unlock to be from
   // the same thread as the lock came from (ARGH!!!!) so we lock it first
   // the _windowThread will block. We unlock and then retryLock until
   // we fail...

   // ok: from now on the main thread can only do thread safe stuff with
   //     the window as it will be transferred to the thread now.
   //     Because its part of the invocation, the window will be called
   //     with `-mulleRelinquishAccess` and `-mulleGainAccess` to transfer
   //     over. On return when we do a `-mulleJoin` we get everything back
   //     into our mainthread (or whoever joins). This means the CGContext
   //     will also change the thread affinity for all its resources. As
   //     a result of this, everything should still be fully function,
   //     when the windowthread is cancelled.
   //
   _windowThread = [[NSThread alloc] initWithTarget:self
                                           selector:@selector( windowThreadMain:)
                                             object:_windowThreadLock];

   // running undetached, so we can join it later
   [_windowThread mulleStart];

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
   MulleUICLog( "\033[1mwindow thread started\033[0m");
#endif
   //
   // the window thread is now "somewhat" blocking, waiting for events
   //
}


- (void) finalizeWindowThread
{
   NSTimeInterval   timeout;

   assert( [NSThread mulleIsMainThread]);

   if( ! _windowThread)
      return;

   timeout = RENDER_THREAD_GRACE_PERIOD;

   UIWindowThreadLog( "trying to lock with 1 (%@ = %td, %s) (%.3f)",
                       _windowThreadLock, [_windowThreadLock condition],
                       [_windowThreadLock mulleIsLocked] ? "*LOCKED*" : "UNLOCKED",
                       timeout);

   if( [_windowThreadLock mulleLockWhenCondition:1
                                         timeout:timeout])
   {
      UIWindowThreadLog( "locked with 1, unlocking with 2 (%@ = %td, %s)",
                  _windowThreadLock, [_windowThreadLock condition],
                  [_windowThreadLock mulleIsLocked] ? "*LOCKED*" : "UNLOCKED");

      // at this time we return a loaned framebuffer back to the offscreen
      // context keeping our nose clean

      [self setLastOffscreenFramebuffer:nil];
      // or place a shutdown event into the event pipe ? We are the only one
      // who cancel the thread. This means a thread could possibly have gone
      // down somehow or is in an endless loop if it doesn't catch this
      [_windowThread cancel];
      [_windowThreadLock unlockWithCondition:2];

      UIWindowThreadLog( "waiting for unlock to 1 (%@ = %td)",
                         _windowThreadLock, [_windowThreadLock condition]);

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
   UIWindowThreadLog( "\033[1mwindow thread stopped\033[0m");

   // MEMO: when we got condition 1, it means the thread is shutting down
   //       but it may not be done yet. With the join, we know the finalizers
   //       have run.
   //
   [_windowThread mulleJoin];

   UIWindowThreadLog( "Window now owned by main thread again");

   [_windowThreadLock autorelease];
   _windowThreadLock = nil;
   [_windowPropertyLock autorelease];
   _windowPropertyLock = nil;
   [_windowThread autorelease];
   _windowThread = nil;
}


//
// When the window thread is idle, it's 1. If we set to 2 the window thread
// should notice immediately, do something and then return to 1, when it's
// done. If there is no windowThread, _windowThreadLock is nil and this
// method does nothing.
//
- (void) wakeupWindowThread
{
   UIWindowThreadLog( "(%@ = %td, %s)",
               _windowThreadLock, [_windowThreadLock condition],
               [_windowThreadLock mulleIsLocked] ? "*LOCKED*" : "UNLOCKED");
   if( [_windowThreadLock tryLockWhenCondition:1])
   {
      UIWindowThreadLogVerbose( "unlocking %#@", _windowThread);
      [_windowThreadLock unlockWithCondition:2];
   }
   else
   {
      UIWindowThreadLog( "window thread is running it seems");
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


- (UIWindowDisplayBits) windowThreadDraw:(NSUInteger) displayBits
                              windowInfo:(struct UIOSWindowInfo *) windowInfo
                                     now:(mulle_absolutetime_t) now
{
   NSUInteger           returnBits;
   struct CGFrameInfo   frameInfo;

   MulleWindowProfileBegin();

   frameInfo     = CGFrameInfoSFMake( windowInfo->base.frame,
                                      windowInfo->base.framebufferSize,
                                      windowInfo->base.pixelRatio);
   frameInfo.now = now;
   returnBits    = [self renderWithFrameInfo:&frameInfo
                                 displayBits:displayBits];
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

   MulleWindowProfileEnd();

   return( returnBits);
}


- (MulleObjCTAOStrategy) taoStrategy
{
   return( MulleObjCTAOKnownThreadSafeMethods);
}


- (void) windowThreadMain:(NSLock *) windowThreadLock
{
   BOOL                    haveLock;
   BOOL                    wantsMouseMotionEvents;
   mulle_absolutetime_t    now;
   mulle_relativetime_t    remainingFrameTime;
   NSAutoreleasePool       *pool;
   NSThread                *thread;
   NSTimeInterval          timeout;
   NSUInteger              displayBits;
   NSUInteger              mask;
   struct UIOSWindowInfo   windowInfo;

   thread = [NSThread currentThread];
   [thread mulleSetNameUTF8String:"UIWindowThread"];

   UIWindowThreadLog( "coming up (%@ = %td, %s)",
                     _windowThreadLock, [_windowThreadLock condition],
                     [_windowThreadLock mulleIsLocked] ? "*LOCKED*" : "UNLOCKED");

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
   pool     = [NSAutoreleasePool new];

   if( self->_willStartDrawingInThreadCallback)
      (*self->_willStartDrawingInThreadCallback)( self, thread);

   assert( [self needsDisplay]);

   for(;;)
   {
      UIWindowThreadLogVerbose( "locking and waiting for condition 2 (%@ = %td, %s) timeout=%.3f",
                  _windowThreadLock, [_windowThreadLock condition],
                  [_windowThreadLock mulleIsLocked] ? "*LOCKED*" : "UNLOCKED",
                  timeout);
      [pool mulleReleaseAllPoolObjects];
      haveLock = [_windowThreadLock mulleLockWhenCondition:2
                                                   timeout:timeout];
      MulleWindowProfileBegin();
      do
      {
         if( [thread isCancelled])
         {
            if( haveLock)
            {
               // TODO: ensure no events are queued from now on
               if( self->_didStopDrawingInThreadCallback)
                  (*self->_didStopDrawingInThreadCallback)( self, thread);
               [pool release];

               [_windowThreadLock unlockWithCondition:1];
               UIWindowThreadLog( "going down (%#@ = %td, %s)",
                        _windowThreadLock, [_windowThreadLock condition],
                        [_windowThreadLock mulleIsLocked] ? "*LOCKED*" : "UNLOCKED");
               MulleWindowProfileEnd();
               return;
            }

            // if we don't have the lock (curious), we can't clearly
            // communicate with the main thread, so we just redo the wait
            // for lock. The cancel flag sticks
            UIWindowThreadLog( "waiting for final lock (%#@ = %td, %s)",
                        _windowThreadLock, [_windowThreadLock condition],
                        [_windowThreadLock mulleIsLocked] ? "*LOCKED*" : "UNLOCKED");
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

         now                = mulle_absolutetime_now();
         remainingFrameTime = [self remainingFrameTime:now
                                             frameRate:windowInfo.frameRate
                                         animationRate:windowInfo.refreshRate
                                       frameStatistics:&_windowThreadStatistics
                                      frameRateLimiter:windowInfo.frameRateLimiter];

         // do not clear displayBits yet, as we don't want to lose the
         // animationNeeded bits, if not ready for redraw yet
         displayBits = [self needsDisplay];
         if( remainingFrameTime == 0.0)
            displayBits |= UIWindowDisplayNeedsRedraw;

         // if we are animating, we want to wait until remainingFrameTime
         // is down to 0.0 too or ?
         if( displayBits & UIWindowDisplayNeedsRedraw)
         {
            // not 100% sure if this is needed, since we will overwrite displayBits
            // in windowThreadDraw:
            //displayBits = [self needsDisplayBitsClearIfSet] | UIWindowDisplayNeedsRedraw;
            UIWindowThreadLogVerbose( "start rendering: displayBits=0x%tx mask=0x%tx",
                                       displayBits,
                                       mask);

            displayBits = [self windowThreadDraw:displayBits
                                      windowInfo:&windowInfo
                                             now:now];
            // if there is an animation going, set our animation displayBit
            // we set it when going into idle (otherwise, we redraw too much)
            [self setNeedsDisplayBits:displayBits];

            UIWindowDisplayBitsLog( "=====================================");

            UIWindowThreadLogVerbose( "Send empty event to wake up main thread to refresh");

            wantsMouseMotionEvents = [self receivesMouseMotionEvents];
            [self setMouseMotionEventsEnabled:wantsMouseMotionEvents];
            [UIEvent sendEmptyEvent];
         }

         [self pollInvocationQueues];

         mask  = [self executeTimerQueue];
         mask |= [self executeEventQueue];
      }
      while( mask);
      MulleWindowProfileEnd();

      // When there is nothing to do avoid busy looping.
      // nothing to do, wait for something to happen
      if( haveLock)
      {
         [_windowThreadLock unlockWithCondition:1];
         UIWindowThreadLogVerbose( "unlockWithCondition 1 (%@ = %td, %s)",
                        _windowThreadLock, [_windowThreadLock condition],
                        [_windowThreadLock mulleIsLocked] ? "*LOCKED*" : "UNLOCKED");
      }
      else
      {
         UIWindowThreadLogVerbose( "haveNoLock (%@ = %td, %s)",
                        _windowThreadLock, [_windowThreadLock condition],
                        [_windowThreadLock mulleIsLocked] ? "*LOCKED*" : "UNLOCKED");
      }

      // MEMO: the window thread doesn't need to lock indefinitely, the
      //       condition lock is there to conserve energy and cycles, so
      //       it doesn't busy loop.
      timeout = [self windowThreadTimeoutIsAnimating:(displayBits & UIWindowDisplayNeedsAnimation) ? YES : NO];
      UIWindowThreadLogVerbose( "done handling events: remainingFrameTime=%.6f proposed timeout=%.6f frameRate=%.6f",
                                 remainingFrameTime,
                                 timeout,
                                 windowInfo.frameRate);

      if( timeout > remainingFrameTime)
         timeout = remainingFrameTime;
   }
}


//
// Moved to MulleUIGraphicsWindow project
//
// The refresh is called during event window refresh and in the main
// loop when a refresh is needed for thread windows.
// The main loop redraw does not refresh.
// The actual caller is usually -displayFrameIfNeeded: which does:
//
//  if( needsRefresh)
//  {
//     [self refresh];
//     [self swapBuffers];
//  }
//

@end
