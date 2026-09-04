//
//  UIPureWindow+Thread.h
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
#ifdef __has_include
# if __has_include( "UIPureWindow.h")
#  import "UIPureWindow.h"
# endif
#endif

// we want "import.h" always anyway
#import "import.h"


enum UIWindowThreadLockCondition
{
   UIWindowThreadLockConditionStarting = 0,  // thread not yet ready
   UIWindowThreadLockConditionIdle     = 1,  // thread ready, waiting for work
   UIWindowThreadLockConditionRunning  = 2   // thread has work, running
};

//
// just a self documentating bit, that tells the user that the method is
// technically thread-safe, as it can only be accessed by the main thread
// that being asserted, there is no need for locking code
//
@interface UIPureWindow( Thread)

- (void) startWindowThreadMainIfNeeded;
- (void) finalizeWindowThread    MULLE_UI_MAIN_THREAD_ONLY;
- (void) wakeupWindowThread      MULLE_UI_MAIN_THREAD_ONLY;

- (void) windowThreadMain:(NSLock *) windowThreadLock MULLE_OBJC_THREADSAFE_METHOD;

- (mulle_relativetime_t) windowThreadTimeoutIsAnimating:(BOOL) flag;

@end


@interface UIPureWindow( ThreadFuture) < MulleObjCFuture>

- (BOOL) refresh     MULLE_UI_MAIN_THREAD_ONLY;

@end
