#define _GNU_SOURCE

#import "UIWindow+NSTimer.h"

#import "import-private.h"

#import "UIWindow+Thread.h"



@implementation UIWindow( NSTimer)


- (BOOL) willDiscardTimer:(NSTimer *) timer
{
   return( YES);
}


- (BOOL) willDiscardOverflowTimer:(NSTimer *) timer
{
   fprintf( stderr, "*** windows %p (%p) discards timer due to queue overflow\n", self, self->_windowThread);
#ifdef ABORT_ON_EVENT_OVERFLOW
   abort();
#endif
   return( [self willDiscardTimer:timer]);
}


- (BOOL) willDiscardPendingTimer:(NSTimer *) timer
{
   return( [self willDiscardTimer:timer]);
}


- (void) handleRetainedTimer:(NSTimer *) timer
{
   assert( [NSThread mulleIsMainThread]);
   assert( timer);

   //
   // if this is a "bare" mainthread window handle the timer immediately
   // otherwise queue it up
   //
   if( ! _windowThread)
   {
       assert( _backingStore != UIWindowBackingStoreRetained);

       [timer autorelease];
       [timer fire];
       return;
   }

   //
   // events that can not be queued will have to be discarded
   //
   if( ui_window_pointer_fifo_write( &_timerQueue, timer))
   {
      if( [self willDiscardOverflowTimer:timer]) // window can figure out something
      {                                          // for super important events
         [timer autorelease];
      }
      return;
   }

   [self wakeupWindowThread];
}


//
// Discard events queue for the window. This has to be called by the window
// thread.
//
- (void) discardPendingTimers
{
   NSTimer   *timer;
   
   assert( [self isWindowThread]);

   @autoreleasepool
   {
      for(;;)
      {
         timer = ui_window_pointer_fifo_read_barrier( &_timerQueue);
         if( ! timer)
            break;

         if( [self willDiscardPendingTimer:timer]) // window can figure out something
            [timer autorelease];
      }
   }
}


//
// Execute all events in the queue until empty. This has to be called by the
// Windows thread. Returns OR of eventType
//
- (NSUInteger) executeTimerQueue
{
   NSTimer      *timer;
   NSUInteger   mask;

   //
   // the timer must be handled by the windowThread, if we have one
   //
   assert( ! _windowThread || [NSThread currentThread] == _windowThread);

   mask = 0;
   for(;;)
   {
      timer = ui_window_pointer_fifo_read_barrier( &_timerQueue);
      if( ! timer)
         break;

      @autoreleasepool
      {
         [timer autorelease];
         // could time timer time spent and then complain if it's too long
         [timer fire];
         mask |= _UIEventTypeTimer;
      }
   }
   return( mask);
}



- (void) addTimer:(NSTimer *) timer
{
   assert( _application);
   [_application addTimer:timer
         forTimerReceiver:self];
}


- (void) removeTimer:(NSTimer *) timer
{
   assert( _application);
   [_application removeTimer:timer
            forTimerReceiver:self];
}


- (void) resetTimer:(NSTimer *) timer
{
   assert( _application);
   [_application resetTimer:timer];
}


- (void) removeAllTimers
{
   assert( _application);
   [_application removeTimer:nil
            forTimerReceiver:self];
}

@end 
