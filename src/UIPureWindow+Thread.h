//
// Copyright (c) 2022 Nat!, Mulle kybernetiK
//
// prefer a local UIWindow over one in import.h
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
