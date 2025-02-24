//
// Copyright (c) 2021 Nat!, Mulle kybernetiK
//
#import "UIView+UIWindow.h"

#import "import-private.h"

#import "UIWindow+UIEvent.h"
#import "UIWindow+UITrackingArea.h"
#import "UIView+UIFirstResponder.h"
#import "UIView+UITrackingArea.h"

#import <MulleUIView/UIView+DebugPrivate.h>


@interface NSObject ( UIWindow)

- (BOOL) __isUIWindow     MULLE_OBJC_THREADSAFE_METHOD;

@end


@implementation UIView ( UIWindow)


//
// if window changes, remove ourselves from old window tracking and move
// to new window tracking. Also resign as firstResponder, if we are
//
// If you change code here, also change it in UIView.m -setWindow:
//
- (void) setWindow:(id <UIWindow>) newWindow
{
   UIView   *view;
   BOOL     flag;

   NSCParameterAssert( ! newWindow || [newWindow isKindOfClass:[UIWindow class]]);

   if( _window == newWindow)
      return;

   [self willMoveToWindow:newWindow];
   [(UIWindow *) self->_window removeTrackingView:self];

   flag = [self resignFirstResponder];
   if( ! flag)
   {
      MulleUILog( "View won't -resignFirstResponder but gets removed from superview");
      abort();
   }

   self->_window = newWindow;

   UIViewSubviewsFor( self, view)
      [view setWindow:newWindow];

   if( mulle_pointerarray_get_count( &_trackingAreas))
      [(UIWindow *) self->_window addTrackingView:self];

   [self didMoveToWindow:newWindow];
}


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

   if( [view __isUIWindow] && [(UIWindow *) view isWindowPlane:before])
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

   UIViewDisplayBitsLog( "");

   window = (UIWindow *) [self window];
   if( ! window)
      UIViewLog( "view has no window, so setNeedsDisplay does nothing");
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

   // MEMO: if we manually setFrame: on a UIView we want to reset the
   //       _originalFrame so that sizeChanges are noticed. (otherwise on
   //       legacy autoresizing we would use a cached version). Because
   //       setFrame: as called from layouting code and setFrame: as called
   //       "manually" is indistinguishable, we force manual code to issue
   //       setNeedsLayout: (by convention), when using legacy bits...
   _originalFrame.size.width = 0.0;

// FIX: ugly hackage
//   if( self->_superview)
//      self->_superview->_lastBounds.size.width = 0.0;
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


@end
