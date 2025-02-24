#import "import.h"

#import <string.h>

#import <MulleUIView/UIView+DebugPrivate.h>

@interface TrackingView : UIView

@property CGColor  selectColor;
@property CGColor  deselectColor;
@property CGColor  hoverColor;

- (void) setColors:(CGColor) color;

@end



@implementation TrackingView

- (void) setColors:(CGColor) color
{
   float   components[ 4];

   [self setDeselectColor:color];
   [self setBackgroundColor:color];
   CGColorGetHSLAComponents( color, components);
   components[ 2] = fmod( components[ 2] + 0.2, 1.0);
   [self setSelectColor:CGColorMakeWithHSLAComponents( components)];

   components[ 0] = fmod( components[ 0] + 0.3, 1.0);
   [self setHoverColor:CGColorMakeWithHSLAComponents( components)];
}


- (void) mouseEntered:(UIMouseTrackingEvent *) event
{
   [super mouseEntered:event];

   MulleUILog( self, "%#@", event);

   [self setBackgroundColor:[self selectColor]];
   [self setNeedsDisplay];
}


- (void) mouseHoverStarted:(UIMouseTrackingEvent *) event
{
//   [super mouseHoverStarted:event];

   MulleUILog( self, "%#@", event);

   [self setBackgroundColor:[self hoverColor]];
   [self setNeedsDisplay];
}


- (void) mouseHoverEnded:(UIMouseTrackingEvent *) event
{
// [super mouseHoverEnded:event];

   MulleUILog( self, "%#@", event);

   [self setBackgroundColor:[self selectColor]];
   [self setNeedsDisplay];
}


- (void) mouseMoved:(UIMouseTrackingEvent *) event
{
   [super mouseMoved:event];

   MulleUILog( self, "%#@", event);
}


- (void) mouseExited:(UIMouseTrackingEvent *) event
{
   [super mouseExited:event];

   MulleUILog( self, "%#@", event);

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

   frame   = CGSizeCenterInRect( CGSizeMake( 200, 200), [contentView contentRect]);
   subview = [TrackingView viewWithFrame:frame];
   [subview setDebuggingFlags:[window debuggingFlags]];
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
                                      options:UITrackingMouseHover
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

   return( [app runApp]);
}
