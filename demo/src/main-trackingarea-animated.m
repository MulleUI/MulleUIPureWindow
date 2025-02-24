#import "import.h"

#import <string.h>

// The tracked view should change colors, when it passes over the mouse
// pointer.
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


- (void) mouseEntered:(UIMouseTrackingEvent *) event
{
#ifdef TRACKING_DEBUG
   MulleUILog( "*enter*");
#endif
   [self setBackgroundColor:[self selectColor]];
   [self setNeedsDisplay];
}


- (void) mouseMoved:(UIMouseTrackingEvent *) event
{
}


- (void) mouseExited:(UIMouseTrackingEvent *) event
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
   CGRect            frame;
   CGRect            rect;
   CGRect            contentRect;
   UITrackingArea    *area;
   CATransaction     *ta;
   CAAnimationGroup  *group;
   CAAnimator        *animator;

   contentView = [window contentView];
   contentRect = CGRectInset( [contentView contentRect], 10, 10);

   view  = [TrackingView object];
   [view setDebugNameUTF8String:"tracking"];
   [view setColors:CGColorMakeGreen()];
//   [view setAutoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight];

   [contentView addSubview:view];

   /*
    * now add an animation
    */

   frame.size = CGSizeMake( 200, 100);
   [view setFrame:CGSizePlaceInRect( frame.size, contentRect, CGContentModeLeft)];

   ta = [CATransaction object];
   [ta begin];
   {
      [ta setAnimationAutoreverses:YES];
      [ta setAnimationOffset:1.0];
      [ta setAnimationDuration:2.0];
      [ta setAnimationRepeatCount:INFINITY];
      [view setFrame:CGSizePlaceInRect( frame.size, contentRect, CGContentModeRight)];
   }
   group = [ta commit];

   //
   // You can't use the postLayoutAnimator, as it will not invalidate
   // the quadtree like -[UIWindow layout] does.
   //
   animator = [window preLayoutAnimator];
   assert( animator);
   [animator addAnimation:group];

   [view setFrame:CGSizePlaceInRect( frame.size, contentRect, CGContentModeCenterPoint)];

   area = [UITrackingArea trackingAreaWithRect:[view contentRect]
                                       options:0
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
   window = [UIWindow windowWithFrame:CGRectMake( 0.0, 0.0, 640, 400)];
   [window setBackgroundColor:CGColorMakeWhite()];

   setupSceneInWindow( window);

   [app addWindow:window];

   return( [app runApp]);
}
