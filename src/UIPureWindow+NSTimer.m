//
//  UIPureWindow+NSTimer.m
//  MulleUIPureWindow
//
//  Copyright (c) 2025 Nat! - Mulle kybernetiK.
//  All rights reserved.
//
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  Redistributions of source code must retain the above copyright notice, this
//  list of conditions and the following disclaimer.
//
//  Redistributions in binary form must reproduce the above copyright notice,
//  this list of conditions and the following disclaimer in the documentation
//  and/or other materials provided with the distribution.
//
//  Neither the name of Mulle kybernetiK nor the names of its contributors
//  may be used to endorse or promote products derived from this software
//  without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//
#define _GNU_SOURCE

#import "UIPureWindow+NSTimer.h"

#import "import-private.h"

#import "UIPureWindow+Thread.h"



@implementation UIPureWindow( NSTimer)


- (BOOL) willDiscardOverflowTimer:(NSTimer *) timer
{
   assert( [NSThread mulleIsMainThread]);

   fprintf( stderr, "*** windows %p (%p) discards timer due to queue overflow\n", self, self->_windowThread);
#ifdef ABORT_ON_EVENT_OVERFLOW
   abort();
#endif
   return( YES);
}


- (BOOL) willDiscardPendingTimer:(NSTimer *) timer
{
   assert( [self isWindowThread]);

   return( YES);
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

   MulleWindowProfileBegin();

   //
   // the timer must be handled by the windowThread, if we have one
   //
   assert( [self isWindowThread]);

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

   MulleWindowProfileEnd();

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
