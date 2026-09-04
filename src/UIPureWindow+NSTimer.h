//
//  UIPureWindow+NSTimer.h
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
#import "UIPureWindow.h"


@interface UIPureWindow( NSTimer) <UITimerReceiver>

// can only be called in window thread
- (void) discardPendingTimers                         MULLE_UI_PURE_WINDOW_THREAD_ONLY;

// timer handling, fire timer immediately if this is a main thread window
// otherwise queue it and wake designated window thread
- (void) handleRetainedTimer:(NSTimer *) timer        MULLE_UI_MAIN_THREAD_ONLY;

- (BOOL) willDiscardOverflowTimer:(NSTimer *) timer   MULLE_UI_MAIN_THREAD_ONLY;
- (BOOL) willDiscardPendingTimer:(NSTimer *) timer    MULLE_UI_PURE_WINDOW_THREAD_ONLY;

- (NSUInteger) executeTimerQueue                      MULLE_UI_PURE_WINDOW_THREAD_ONLY;

// the window must have been added to the UIApplication before you can
// add timers.
- (void) addTimer:(NSTimer *) timer       MULLE_OBJC_THREADSAFE_METHOD;
- (void) resetTimer:(NSTimer *) timer     MULLE_OBJC_THREADSAFE_METHOD;
- (void) removeTimer:(NSTimer *) timer    MULLE_OBJC_THREADSAFE_METHOD;
- (void) removeAllTimers                  MULLE_OBJC_THREADSAFE_METHOD;

@end
