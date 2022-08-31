#import "UIWindow.h"


@interface UIWindow( NSTimer) <UITimerReceiver>

- (void) discardPendingTimers;

// timer handling, fire timer immediately if this is a main thread window
// otherwise queue it and wake designated window thread
- (void) handleRetainedTimer:(NSTimer *) timer;

- (BOOL) willDiscardTimer:(NSTimer *) timer;
- (BOOL) willDiscardOverflowTimer:(NSTimer *) timer;
- (BOOL) willDiscardPendingTimer:(NSTimer *) timer;

- (NSUInteger) handleTimerQueue;

- (void) addTimer:(NSTimer *) timer;
- (void) resetTimer:(NSTimer *) timer;
- (void) removeTimer:(NSTimer *) timer;
- (void) removeAllTimers;

@end
