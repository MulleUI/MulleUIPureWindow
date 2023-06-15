//
// Copyright (c) 2023 Nat!, Mulle kybernetiK
//
// prefer a local UIWindow over one in import.h
#ifdef __has_include
# if __has_include( "UIWindow.h")
#  import "UIWindow.h"
# endif
#endif


// we want "import.h" always anyway
#import "import.h"

@class UITrackingArea;

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



@interface UIWindow( UITrackingArea)

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

@end
