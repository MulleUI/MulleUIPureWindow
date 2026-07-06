#define _GNU_SOURCE

#import "UIPureWindow+OneFrame.h"

#import "import-private.h"

#import "UIPureWindow+FrameInfo.h"
#import "UIPureWindow+Frame.h"
#import "UIPureWindow+Render.h"
#import "UIPureWindow+Thread.h"
#import "UIPureWindow+InvocationQueue.h"
#import "UIPureWindow+NSTimer.h"
#import "UIPureWindow+UIEvent.h"
#import "UIPureWindow+UIResponder.h"
#import "UIPureWindow+UIWindow.h"


//#define MOUSE_MOTION_CALLBACK_DEBUG
//#define MOUSE_BUTTON_CALLBACK_DEBUG
//#define RESIZE_CALLBACK_DEBUG
//#define HANDLE_EVENT_DEBUG
//#define PROCESS_EVENT_DEBUG


@implementation UIPureWindow( OneFrame)


// In terms of the frame, we are hopefully,say, in the middle of the monitor
// frame. The render is done and now we do the events. We want to do also events
// coming in in the second half of the frame, but we do not want to busy wait
// nor do we want to sleep long, because of latency.
//
#ifdef ns
# undef ns
#endif
#ifdef us
# undef us
#endif

#define us( x)    (long) ((x) * 1000)
#define ms( x)    (long) (us(x) * 1000)

#define THREAD_WAIT_PERIOD  ms( 0.5)


- (NSUInteger) waitForEventsUntil:(mulle_absolutetime_t) then
                     returnsEarly:(BOOL) returnsEarly
{
   NSUInteger             mask;
   mulle_absolutetime_t   now;
   mulle_relativetime_t   diff;
   BOOL                   isMainThread;

   mask          = 0;
   diff          = 0.0;

#ifdef PROCESS_EVENT_DEBUG
   MulleUILog( "is waiting for events until %.4fs", then);
#endif
   //
   // set this now to NO, if a window refresh events is received we
   // preempt, even if returnsEarly is NO
   //
   isMainThread = [NSThread mulleIsMainThread];

   // first loop we just quick poll
   // then we run a wait if we are on the main thread otherwise we nanosleep

   for(;;)
   {
      //
      // if we are in the main thread, we can use wait
      //
      if( isMainThread)
      {
         assert( _application);
         [_application os_waitEventsWithTimeout:diff];
      }

      [self pollInvocationQueues];

      // mask |= [self executeTimerQueue];
      mask |= [self executeEventQueue];
      if( mask && returnsEarly)
      {
#ifdef PROCESS_EVENT_DEBUG
         MulleUILog( "returns early");
#endif
         break;
      }

      now  = mulle_absolutetime_now();
      diff = now - then;

      if( ! isMainThread)
      {
         // if we need an immediate redraw, quit
         if( [self needsDisplay])
         {
#ifdef PROCESS_EVENT_DEBUG
            MulleUILog("stop processing events, needs redraw");
#endif
            break;
         }
         // In a worker thread it's nanosleep, to time
         // sleep time must be less then the GRACE_PERIOD
         // Change this to some better code...
         {
            mulle_relativetime_t   sleep_time;

            sleep_time = diff < (mulle_relativetime_t) THREAD_WAIT_PERIOD / 1e9
                       ? diff
                       : (mulle_relativetime_t) THREAD_WAIT_PERIOD / 1e9;
            if( sleep_time > 0.0)
               mulle_relativetime_sleep( sleep_time);
         }
      }
      else
      {
         if( [self needsRefresh])
         {
#ifdef PROCESS_EVENT_DEBUG
            MulleUILog( "stop processing events, needs redraw");
#endif
            break;
         }
      }

      if( diff >= 0.0)
      {
#ifdef PROCESS_EVENT_DEBUG
         MulleUILog( "stop processing events, timeout reached (setNeedsDisplay)");
#endif
         if( ! [_OSWindow frameRateLimiter])
            [self setNeedsDisplay];
         break;
      }
   }
   return( mask);
}


- (NSUInteger) processEvents:(mulle_absolutetime_t) now
                   frameRate:(mulle_relativetime_t) frameRate
{
   mulle_relativetime_t   timeout;

   // Four cases:
   // UIWindowFrameRateUnsynced (0.0), UIWindowFrameRateAsync (INFINITE)
   // UIWindowFrameRateSynced (which is the primary monitor refresh rate)
   // or a framerate like 1/60.0 for 60 Hz
   //
   // UIWindowFrameRateAsynced:  timout == INFINITE, returnsEarly: YES
   // UIWindowFrameRateUnsynced: timout == 0.0  returnsEarly: YES
   // Else timeout: returnsEarly: NO
   if( frameRate == UIWindowFrameRateSynced)
      timeout = [[_application primaryScreen] refreshRate];
   else
      timeout = fabs( frameRate); // deal with softframerate

   return( [self waitForEventsUntil:now + timeout
                       returnsEarly:frameRate == UIWindowFrameRateUnsynced ||
                                    frameRate == UIWindowFrameRateAsync]);
}


- (void) eventHandlingWithFrameRate:(mulle_relativetime_t) frameRate
{
   mulle_absolutetime_t   timestamp;
   mulle_relativetime_t   usedFrameRate;

   assert( [NSThread mulleIsMainThread]);
   assert( _backingStore != UIWindowBackingStoreRetained && "Don't call eventHandlingWithFrameRate on a UIWindowStyleRetained window");


   /*
    * Event handling.
    */
   @autoreleasepool
   {
      // we can get to 29.98 fps when we feed it the last timestamp
      // but is it desirable ?
      timestamp = _lastDidProcessEventsTimestamp
                     ? _lastDidProcessEventsTimestamp
                     : _mainThreadStatistics.lastEndTimestamp;

      // just push next one through ASAP or ?
      usedFrameRate = frameRate;
      if( _isResizing)
      {
         _isResizing   = NO;
         usedFrameRate = UIWindowFrameRateUnsynced;
      }
#ifdef PROCESS_EVENT_DEBUG
      fprintf( stderr, "processEvents frameRate: %.4f -> %.4f\n", frameRate, usedFrameRate);
#endif
      [self processEvents:timestamp
                frameRate:usedFrameRate];

      _lastDidProcessEventsTimestamp = mulle_absolutetime_now();
   }
}


- (void) renderAndSwapOneFrame
{
   UIWindowDisplayBits     displayBits;
   struct CGFrameInfo      frameInfo;

   assert( _backingStore != UIWindowBackingStoreRetained && "Don't call processOneFrame on a UIWindowStyleRetained window");

   displayBits  = [self needsDisplayBitsClearIfSet];
   displayBits |= UIWindowDisplayNeedsDisplay;
   [self getFrameInfo:&frameInfo];  // retrieve newest geometry
   displayBits  = [self renderWithFrameInfo:&frameInfo
                                displayBits:displayBits];
   [self setNeedsRefresh:NO];
   [self swapBuffers];
   [self setNeedsDisplayBits:displayBits];
   [self setMouseMotionEventsEnabled:[self receivesMouseMotionEvents]];
}


- (BOOL) processOneFrame:(CGFloat) frameRate
{
   struct UIOSWindowInfo   windowInfo;

   @autoreleasepool
   {
      [self renderAndSwapOneFrame];

      // now no openGL or CGContext calls should happen
      // as the context has been detached from this thread
      [_OSWindow getOSWindowInfo:&windowInfo];

      // MEMO: used to to do this, but its now out of scope here
      //    [self setupQuadtree];
      [self eventHandlingWithFrameRate:frameRate];
      [self syncOSWindowPropertyChangesIfNeeded];
   }

   return( [self shouldClose] ? NO : YES);
}

- (BOOL) processOneFrame
{
   return( [self processOneFrame:UIWindowFrameRateUnsynced]);
}

@end
