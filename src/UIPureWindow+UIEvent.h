#ifdef __has_include
# if __has_include( "UIPureWindow.h")
#  import "UIPureWindow.h"
# endif
#endif

#import "import.h"


//
// A window _receives_ and event the event is then _handled_ which means
// the views and other recipients are sought out, the recipient then
// accepts this event. If nil is returned the event was consumed, otherwise
// the event is forwarded to the next in line.
//

@interface UIPureWindow( UIEvent) < UIEventReceiver>

- (void) discardPendingEvents;

// hardcore event handling, must be called from MainThread
- (void) receiveRetainedEvent:(UIEvent *) event                MULLE_UI_MAIN_THREAD_ONLY;
- (UIWindowEvent *) handleWindowEvent:(UIWindowEvent *) event  MULLE_UI_MAIN_THREAD_ONLY;


//
// These event methods are special, you may not necessarily be in an 
// autoreleasepool as this time! Discard event with -retain and return NO if
// you must. Otherwise return YES and let UIPureWindow deal with it.
//
// The -willDiscardEvent: method must be thread safe as it can be called from 
// -willDiscardOverflowEvent: (Main thread) or -willDiscardPendingEvent:
// (Window thread). The default implementation just returns YES, indicating
// approval. 
//
- (BOOL) willDiscardEvent:(UIEvent *) event                    MULLE_OBJC_THREADSAFE_METHOD;
- (BOOL) willDiscardOverflowEvent:(UIEvent *) event            MULLE_UI_MAIN_THREAD_ONLY;
- (BOOL) willDiscardPendingEvent:(UIEvent *) event;

- (NSUInteger) executeEventQueue;

- (void) sendWindowFramebufferGeometryEvent:(struct CGWindowInfo *) info   MULLE_OBJC_THREADSAFE_METHOD;

- (BOOL) isMouseMotionEventsEnabled;
- (void) setMouseMotionEventsEnabled:(BOOL) flag;


@end


@interface UIPureWindow( OSInputEvents)

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
