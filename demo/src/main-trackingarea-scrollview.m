#import "import.h"

#import <string.h>

//
// The tracked view should change colors, when it passes over the mouse
// pointer. The tracking view can be moved around in the scrollview, it
// should only track when "visibly" hit.
//
#define TRACKING_DEBUG

@interface TrackingView : UIView

@property CGColor  selectColor;
@property CGColor  deselectColor;

- (void) setColors:(CGColor) color;

@end



@implementation TrackingView

- (void) setColors:(CGColor) color
{
   float   components[ 4];

   [self setDeselectColor:color];
   [self setBackgroundColor:color];
   CGColorGetHSLAComponents( color, components);
   components[ 2] = 0.7;
   [self setSelectColor:CGColorMakeWithHSLAComponents( components)];
}


- (void) mouseEntered:(UIMouseMotionEvent *) event
{
#ifdef TRACKING_DEBUG
   MulleUILog( "*enter*");
#endif
   [self setBackgroundColor:[self selectColor]];
   [self setNeedsDisplay];
}


- (void) mouseExited:(UIMouseMotionEvent *) event
{
#ifdef TRACKING_DEBUG
   MulleUILog( "*exit*");
#endif
   [self setBackgroundColor:[self deselectColor]];
   [self setNeedsDisplay];
}

@end


void   setupSceneInWindow( UIWindow *window)
{
   UIView            *contentView;
   TrackingView      *view;
   UIView            *childView;
   CGRect            frame;
   CGRect            rect;
   CGRect            contentRect;
   UIScrollView      *scrollView;
   UITrackingArea    *area;
   CGSize            contentSize;

   contentView = [window contentView];
   contentRect = [contentView contentRect];

   frame = CGSizePlaceInRect( CGSizeMake( 400, 300),
                              contentRect,
                              CGContentModeCenterPoint);
   scrollView = [UIScrollView viewWithFrame:frame];
   [scrollView setBorderWidth:1.0];
   [scrollView setBorderColor:CGColorMakeBlack()];
   contentSize = CGSizeMake( 800, 600);
   [scrollView setContentOffset:CGPointMake( 200, 150)];
   [scrollView setContentSize:contentSize];
   [contentView addSubview:scrollView];

   frame = CGSizePlaceInRect( CGSizeMake( 200, 100),
                              CGRectMakeWithOriginAndSize( CGPointZero, [scrollView contentSize]),
                              CGContentModeCenterPoint);
   view  = [TrackingView viewWithFrame:frame];
   [view setDebugNameUTF8String:"tracking"];
   [view setColors:CGColorMakeBlue()];

   [[scrollView contentView] addSubview:view];


   frame = CGSizePlaceInRect( CGSizeMake( 20, 10),
                              [view contentRect],
                              CGContentModeCenterPoint);

   childView = [UIView viewWithFrame:frame];
   [childView setBackgroundColor:CGColorMakeYellow()];
   [view addSubview:childView];

   area = [UITrackingArea trackingAreaWithRect:[view contentRect]
                                       options:UITrackingVisibleRectOnly
                                         owner:view
                                      userInfo:nil];
   [area setCursor:[UIApp cursorWithStandardShape:UICursorDrag]];
   [view addTrackingArea:area];
}


int   main()
{
   CGContext       *context;
   UIWindow        *window;
   UIApplication   *app;

   app = [UIApplication sharedInstance];
   /*
    * window and app
    */
   window = [UIWindow windowWithFrame:CGRectMake( 0.0, 0.0, 600, 400)];
   [window setBackgroundColor:CGColorMakeWhite()];

   setupSceneInWindow( window);

   [app addWindow:window];

   return( [app run]);
}
