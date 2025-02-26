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
