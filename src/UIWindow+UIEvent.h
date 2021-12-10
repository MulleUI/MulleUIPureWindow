#import "UIWindow.h"


@interface UIWindow( UIEvent) <UIEventReceiver>

- (id) _firstResponder;

- (void) setupQuadtree;

// Use -[UIView addTrackingAreaWithRect:toWindow:userInfo:]. It will call
// -[UIWindow addTrackingView:] eventually
- (void) addTrackingView:(UIView *) view;
- (void) removeTrackingView:(UIView *) view;

- (NSUInteger) pollEvents;
- (void) discardPendingEvents;

// hardcore event handling
- (void) queueRetainedEvent:(UIEvent *) event;
- (void) queueEvent:(UIEvent *) event;

// returns ored bits of handled events
- (NSUInteger) waitForEvents:(CARelativeTime) timeout
                         now:(CAAbsoluteTime) now
                returnsEarly:(BOOL) returnsEarly;

- (BOOL) willDiscardEvent:(UIEvent *) event;
- (BOOL) willDiscardOverflowEvent:(UIEvent *) event;
- (BOOL) willDiscardPendingEvent:(UIEvent *) event;

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
