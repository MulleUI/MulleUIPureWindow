#import "import.h"

#import <string.h>


@interface SensitiveView : UIView

@property CGColor  selectColor;
@property CGColor  deselectColor;

- (void) setColors:(CGColor) color;

@end



@implementation SensitiveView

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
   [self setBackgroundColor:[self selectColor]];
   [self setNeedsDisplay];
}


- (void) mouseMoved:(UIMouseMotionEvent *) event
{
}


- (void) mouseExited:(UIMouseMotionEvent *) event
{
   [self setBackgroundColor:[self deselectColor]];
   [self setNeedsDisplay];
}

@end


void   setupTrackingRectangles( UIView *view, UIWindow *window, BOOL reverse)
{
   CGRect           rect1;
   CGRect           rect2;
   UITrackingArea   *area;
   CALayer          *layer;

   // we use a tracking area in for whole view
   // and one for the center

   if( reverse)
   {
      rect2 = [view contentRect];
      rect1 = CGRectInset( rect2, 10, 10);
   }
   else
   {
      rect1 = [view contentRect];
      rect2 = CGRectInset( rect1, 10, 10);
   }

   area = [UITrackingArea trackingAreaWithRect:rect1
                                         owner:view
                                         cursor:[UIApp cursorWithStandardShape:UICursorDrag]
                                       userInfo:nil
                                        options:0];
   [view addTrackingArea:area 
                toWindow:window];


   layer = [CALayer layerWithFrame:rect1];
   [layer setBorderWidth:1.0];
   [layer setBorderColor:CGColorMakeGray()];
   [view addLayer:layer];

   area = [UITrackingArea trackingAreaWithRect:rect2
                                         owner:view
                                        cursor:[UIApp cursorWithStandardShape:UICursorTextInput]
                                      userInfo:nil
                                       options:0];
   [view addTrackingArea:area 
                toWindow:window];

   layer = [CALayer layerWithFrame:rect2];
   [layer setBorderWidth:1.0];
   [layer setBorderColor:CGColorMakeGray()];
   [view addLayer:layer];
}


void   setupScene( UIWindow *window)
{
   UIWindowPlane  *contentPlane;
   UIView         *view;
   SensitiveView  *subview;
   CGRect         frame;
   CGRect         bounds;
   UIEdgeInsets   insets;
   CALayer        *layer;

   contentPlane = [window contentPlane];

   frame  = [contentPlane contentRect];
   insets = UIEdgeInsetsMake( 8, 8, 8, 8);
   frame  = UIEdgeInsetsInsetRect( frame, insets);

   view  = [UIView viewWithFrame:frame];
   [view setDebugNameUTF8String:"parent"];
   [view setAutoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight];
   [view setBackgroundColor:CGColorMakeYellow()];
   [view setPadding:UIEdgeInsetsMake( 4.0, 4.0, 4.0, 4.0)];

   [contentPlane addSubview:view];

   frame   = CGRectMake( 20, 40, 200, 200);
   subview = [SensitiveView viewWithFrame:frame];
   [subview setDebugNameUTF8String:"green"];
   [subview setColors:CGColorMakeGreen()];
   setupTrackingRectangles( subview, window, NO);
   [view addSubview:subview];

   frame   = CGRectMake( 120, 20, 50, 300);
   subview = [SensitiveView viewWithFrame:frame];
   [subview setDebugNameUTF8String:"blue"];
   [subview setColors:CGColorMakeBlue()];
   setupTrackingRectangles( subview, window, NO);
   [view addSubview:subview];

   frame   = CGRectMake( 50, 120, 200, 50);
   subview = [SensitiveView viewWithFrame:frame];
   [subview setDebugNameUTF8String:"red"];
   [subview setColors:CGColorMakeRed()];
   setupTrackingRectangles( subview, window, NO);
   [view addSubview:subview];

   // now the same setup just reverse
   frame   = CGRectMake( 400, 120, 200, 50);
   subview = [SensitiveView viewWithFrame:frame];
   [subview setDebugNameUTF8String:"red"];
   [subview setColors:CGColorMakeRed()];
   setupTrackingRectangles( subview, window, YES);
   [view addSubview:subview];

   frame   = CGRectMake( 470, 20, 50, 300);
   subview = [SensitiveView viewWithFrame:frame];
   [subview setDebugNameUTF8String:"blue"];
   [subview setColors:CGColorMakeBlue()];
   setupTrackingRectangles( subview, window, YES);
   [view addSubview:subview];


   frame   = CGRectMake( 370, 40, 200, 200);
   subview = [SensitiveView viewWithFrame:frame];
   [subview setDebugNameUTF8String:"green"];
   [subview setColors:CGColorMakeGreen()];
   setupTrackingRectangles( subview, window, YES);
   [view addSubview:subview];
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

   setupScene( window);

   [app addWindow:window];

   return( [app run]);
}
