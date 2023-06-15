#include "import.h"


@class UIView;

// TODO: rename to NSTrackingArea ?
typedef NS_OPTIONS( NSUInteger, UITrackingAreaOptions)
{
   UITrackingIgnoreMouseEnteredAndExited = 0x1,
   UITrackingMouseMoved                  = 0x2,
   UITrackingSetCursor                   = 0x8,
   UITrackingInVisibleRect               = 0x10,
   UITrackingAssignUserInfo              = 0x20  // does not retain/release
//   UITrackingCursorUpdate               = 0x4, // not supported
//   UITrackingEnabledDuringMouseDrag      = 0x4,  // not supported
//   UITrackingAreaReceivesObscuredEvents  = 0x100,  // 1: get event if view lies on top
};


// mulle addition
@interface UITrackingArea : NSObject

@property( assign) id           owner;
@property( assign) UICursor     *cursor;
@property( assign) CGRect       rect;
@property( retain) id           userInfo;
@property( assign) NSUInteger   options;


+ (instancetype) trackingAreaWithRect:(CGRect) rect;
+ (instancetype) trackingAreaWithRect:(CGRect) rect
                                owner:(id) owner 
                               cursor:(UICursor *) cursor
                             userInfo:(id) userInfo
                              options:(NSUInteger) options;

- (instancetype) initWithRect:(CGRect) rect 
                        owner:(id) owner 
                       cursor:(UICursor *) cursor
                     userInfo:(id) userInfo
                      options:(NSUInteger) options;

// backwards compatible, sort of
- (instancetype) initWithRect:(CGRect) rect 
                      options:(NSUInteger) options
                        owner:(id) owner 
                     userInfo:(id) userInfo;

@end 


