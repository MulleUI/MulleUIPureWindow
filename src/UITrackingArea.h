#include "import.h"


@class UIView;
@class UIWindow;

/*
NSTrackingMouseEnteredAndExited
   Receives mouseEntered: and mouseExited: events

NSTrackingMouseMoved
   Receives mouseMoved: messages while the mouse cursor is within the area.

NSTrackingCursorUpdate
   Receives cursorUpdate: messages when the mouse cursor enters the area.

NSTrackingActiveWhenFirstResponder
   Receives messages when the view is the first responder.

NSTrackingActiveInKeyWindow
   Receives messages when the view is in the key window.

NSTrackingActiveInActiveApp
   The owner receives messages when the application is active.

NSTrackingActiveAlways
   The owner receives messages regardless of first-responder status,
   window status, or application status.
   The cursorUpdate: message is not sent when the NSTrackingCursorUpdate option
   is specified along with this constant.

NSTrackingAssumeInside
   The first event is generated when the cursor leaves the tracking area,
   regardless if the cursor is inside the area when the NSTrackingArea is
   added to a view. If this option is not specified, the first event is
   generated when the cursor leaves the tracking area if the cursor is
   initially inside the area, or when the cursor enters the area if the cursor
   is initially outside it. Generally, you do not want to request this
   behavior.

NSTrackingInVisibleRect
   Mouse tracking occurs only in the visible rectangle of the view—in other
   words, that region of the tracking rectangle that is unobscured. Otherwise,
   the entire tracking area is active regardless of overlapping views.
   The NSTrackingArea object is automatically synchronized with changes in the
   view’s visible area (visibleRect) and the value returned from rect is
   ignored.

NSTrackingEnabledDuringMouseDrag
   The owner receives NSMouseEntered events when the mouse cursor is dragged
   into the tracking area. If this option is not specified, the owner receives
   mouse-entered events when the mouse is moved (no buttons pressed) into the
   tracking area and on NSLeftMouseUp events after a mouse drag.
*/


typedef NS_OPTIONS( NSUInteger, UITrackingAreaOptions)
{
   UITrackingIgnoreMouseEnteredAndExited = 0x1,
   UITrackingMouseMoved                  = 0x2,
   UITrackingSetCursor                   = 0x8,
   UITrackingVisibleRectOnly             = 0x10,
   UITrackingAssignUserInfo              = 0x20, // does not retain/release
//   UITrackingCursorUpdate               = 0x4, // not supported
//   UITrackingEnabledDuringMouseDrag      = 0x4,  // not supported
   UITrackingAreaReceivesObscuredEvents  = 0x100,
   UITrackingActiveWhenFirstResponder    = 0x200
};


// mulle addition
@interface UITrackingArea : NSObject <UIAutoresizing>

@property( assign) id           owner;
@property( assign) UICursor     *cursor;
@property( assign) CGRect       rect;
@property( retain) id           userInfo;
@property( assign) NSUInteger   options;
@property( assign) UIView       *view;

// autoresizing helpers
UIAutoresizingProperties;

@property( assign) NSUInteger   autoresizingMask;


+ (instancetype) trackingAreaWithRect:(CGRect) rect;

+ (instancetype) trackingAreaWithRect:(CGRect) rect
                              options:(NSUInteger) options
                                owner:(id) owner 
                             userInfo:(id) userInfo;

// backwards compatible, sort of
// wily argument order for historic reasons
// https://developer.apple.com/documentation/appkit/nstrackingarea/1524488-initwithrect?language=objc
// Set other values with properties.
- (instancetype) initWithRect:(CGRect) rect 
                      options:(NSUInteger) options
                        owner:(id) owner 
                     userInfo:(id) userInfo;



// returns YES always if UITrackingVisibleRectOnly is not set, otherwise
// determines "inside" "outside"

- (BOOL) isTrackingActiveAtLocation:(CGPoint) location
                           inWindow:(UIWindow *) window;
@end 


