#import "UIWindow.h"


enum 
{
   UIMouseTrackingEnteredEventType  = 0,
   UIMouseTrackingExitedEventType   = 1,
   UIMouseTrackingMovedEventType    = 2
};

@interface UIMouseTrackingEvent : UIInputEvent

@property( assign) NSUInteger       type;
@property( assign) UITrackingArea   *area;

- (void) updateWithInputEvent:(UIInputEvent *) event;
- (void) updateTrackingArea:(UITrackingArea *) area
                       type:(NSUInteger) type;

@end


@interface UIWindow( UIEvent) <UIEventReceiver>

- (void) setupQuadtree;

// Use -[UIView addTrackingAreaWithRect:toWindow:userInfo:]. It will call
// -[UIWindow addTrackingView:] eventually
- (void) addTrackingView:(UIView *) view;
- (void) removeTrackingView:(UIView *) view;

// this forgets previously recognized "entered" rectangles, so you will
// likely get mouseEntered: if cursor is in area fairly soon after this 
- (void) invalidateTrackingAreasForView:(UIView *) view;

- (void) handleTrackingAreaForInputEvent:(UIInputEvent *) event
                                  inDrag:(BOOL) inDrag;

//                             

- (void) discardPendingEvents;

// hardcore event handling
- (void) receiveRetainedEvent:(UIEvent *) event;


- (BOOL) willDiscardEvent:(UIEvent *) event;
- (BOOL) willDiscardOverflowEvent:(UIEvent *) event;
- (BOOL) willDiscardPendingEvent:(UIEvent *) event;

- (NSUInteger) executeEventQueue;

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
