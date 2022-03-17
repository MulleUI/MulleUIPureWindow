#import "UIWindow.h"


@interface UIWindow( UIEvent) <UIEventReceiver>

- (id) _firstResponder;

- (void) setupQuadtree;

// Use -[UIView addTrackingAreaWithRect:toWindow:userInfo:]. It will call
// -[UIWindow addTrackingView:] eventually
- (void) addTrackingView:(UIView *) view;
- (void) removeTrackingView:(UIView *) view;

- (void) discardPendingEvents;

// hardcore event handling
- (void) handleRetainedEvent:(UIEvent *) event;


- (BOOL) willDiscardEvent:(UIEvent *) event;
- (BOOL) willDiscardOverflowEvent:(UIEvent *) event;
- (BOOL) willDiscardPendingEvent:(UIEvent *) event;

- (NSUInteger) handleEventQueue;

- (void) sendWindowFramebufferGeometryEvent:(struct CGWindowInfo *) info;

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
