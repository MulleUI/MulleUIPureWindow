#import "UIWindow.h"


//
// A window _receives_ and event the event is then _handled_ which means
// the views and other recipients are sought out, the recipient then
// accepts this event. If nil is returned the event was consumed, otherwise
// the event is forwarded to the next in line.
//

@interface UIWindow( UIEvent) < UIEventReceiver>

- (void) discardPendingEvents;

// hardcore event handling, must be called from MainThread
- (void) receiveRetainedEvent:(UIEvent *) event                MULLE_UI_MAIN_THREAD_ONLY;
- (UIWindowEvent *) handleWindowEvent:(UIWindowEvent *) event  MULLE_UI_MAIN_THREAD_ONLY;


- (BOOL) willDiscardEvent:(UIEvent *) event;
- (BOOL) willDiscardOverflowEvent:(UIEvent *) event;
- (BOOL) willDiscardPendingEvent:(UIEvent *) event;

- (NSUInteger) executeEventQueue;

- (void) sendWindowFramebufferGeometryEvent:(struct CGWindowInfo *) info   MULLE_OBJC_THREADSAFE_METHOD;

- (BOOL) isMouseMotionEventsEnabled;
- (void) setMouseMotionEventsEnabled:(BOOL) flag;


@end


@interface UIWindow( OSInputEvents)

- (void) _charCallback:(unsigned int) codepoint;
- (void) _keyCallback:(int) key
             scancode:(int) scancode
               action:(int) action
            modifiers:(int) mods;

- (void) _mouseMotionCallback:(CGPoint) pos;
- (void) _mouseButtonCallback:(int) button
                       action:(int) action
                    modifiers:(int) mods;
- (void) _mouseScrollCallback:(CGPoint) offset;

@end
