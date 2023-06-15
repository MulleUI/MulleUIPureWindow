//
// Copyright (c) 2021 Nat!, Mulle kybernetiK
//
#import "UIView+UIWindow.h"

#import "import-private.h"

#import "UIWindow+UIEvent.h"


@interface NSObject ( UIWindow)

- (BOOL) __isUIWindow;

@end


@implementation UIView ( UIWindow)

/*
- (UIWindow *) window
{
   UIView   *view;
   UIView   *parent;

   for( view = self; (parent = view->_superview); view = parent)
   {
   }

   if( [view __isUIWindow])
      return( (UIWindow *) view);
   return( nil);
}
*/

// this is really quite conservative, maybe too conservative
- (UIWindowPlane *) windowPlane
{
   UIView   *view;
   UIView   *parent;
   UIView   *before;

   before = nil;
   for( view = self; (parent = view->_superview); before = view, view = parent)
   {
   }

   if( [view __isUIWindow] && [(UIWindow *) view isWindowPlane:self])
      return( (UIWindowPlane *) before);
   return( nil);
}


# pragma mark - screen

- (CGFloat) pixelsPerInchOfCurrentScreen
{
   id <UIScreen>         screen;
   struct UIScreenInfo   info;

   memset( &info, 0, sizeof( info));
   screen = [(UIWindow *) [self window] screenOrPrimaryScreen:YES];
   [screen getScreenInfo:&info];

   // UIScreenInfoGetPPI will return 72.0 if info is zero
   return( UIScreenInfoGetPPI( &info));
}


- (void) setNeedsDisplay
{
   UIWindow   *window;

   window = (UIWindow *) [self window];
#ifdef DEBUG
   if( ! window)
      MulleUILog( @"%@ has no window, so setNeedsDisplay does nothing");
#endif
   [window setNeedsDisplay];
}


- (BOOL) needsLayout
{
   UIWindow   *window;

   window = (UIWindow *) [self window];
   assert( window);
   return( [window needsLayout]);
}

//
// propagate up, but stop if already marked
//
- (void) setNeedsLayout
{
   UIWindow   *window;

   window = (UIWindow *) [self window];
   assert( window);
//   UIView   *view;
//   UIView   *next;

   [window setNeedsLayout];
//
//   next = self;
//   for(;;)
//   {
//      view = next;
//      // if( view->_needsLayout)
//      //    break;
//
//      next = view->_superview;
//      if( ! next)  // we are the window
//      {
//         // window may use special atomic flag, so don't ignore accessor
//         return;
//      }
//
//      // view->_needsLayout = YES;  // quick mark and unto next
//   }
}

- (CGSize) sizeThatFits:(CGSize) size
{
   id <UIGraphicsContext>   context;
   id <UIWindow>            window;

   window  = [self window];
   context = [window renderGraphicsContext];
   return( [self sizeThatFits:size
                      context:context]);
}


- (void) mouseEntered:(UIMouseTrackingEvent *) event
{
} 

- (void) mouseMoved:(UIMouseTrackingEvent *) event
{
}

- (void) mouseExited:(UIMouseTrackingEvent *) event
{
}

@end
