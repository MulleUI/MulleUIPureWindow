#import "import.h"

#import <string.h>


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



void   setupScene( UIWindow *window)
{
   UIView           *contentView;
   UIView           *helperView;
   TrackingView     *subview;
   CGRect           frame;
   CGRect           rect;
   UITrackingArea   *area;

   contentView = [window contentView];

   frame   = CGSizeCenterInRect( CGSizeMake( 200, 200), [window contentRect]);
   subview = [TrackingView viewWithFrame:frame];
   [subview setDebugNameUTF8String:"tracking"];
   [subview setColors:CGColorMakeGreen()];
   [subview setAutoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight];

   rect = CGRectMake( 20, 20, frame.size.width - 40, frame.size.height - 40);
   helperView = [UIView viewWithFrame:rect];
   [helperView setBorderColor:CGColorMakeWhite()];
   [helperView setBorderWidth:1.0];
   [helperView setAutoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight];
//   [helperView setUIInteractionEnabled:NO];
   [subview addSubview:helperView];

   area = [UITrackingArea trackingAreaWithRect:rect
                                        options:0
                                          owner:subview
                                       userInfo:nil];
   [area setCursor:[UIApp cursorWithStandardShape:UICursorDrag]];
   [area setAutoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight];
   [subview addTrackingArea:area];

   [contentView addSubview:subview];
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
