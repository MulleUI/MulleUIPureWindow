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
   UIApplication         *app;
   UIWindow              *window;
   id <UIScreen>         screen;
   struct UIScreenInfo   info;

   memset( &info, 0, sizeof( info));
   screen = [[self window] screenOrPrimaryScreen:YES];
   [screen getScreenInfo:&info];

   // UIScreenInfoGetPPI will return 72.0 if info is zero
   return( UIScreenInfoGetPPI( &info));
}



# pragma mark - tracking rectangles

- (void) addTrackingArea:(UITrackingArea *) item
                toWindow:(UIWindow *) window
{
   assert( window);

   if( mulle_pointerarray_get_count( &_trackingAreas) == 0)
   {
      // if window does not exist, then a late add would not be noticed
      // and tracking fails...
      [window addTrackingView:self];
   }

   [item retain];
   mulle_pointerarray_add( &_trackingAreas, item);
}


- (void) addTrackingArea:(UITrackingArea *) item
{
   if( ! [item owner])
      [item setOwner:self];
   return( [self addTrackingArea:item 
                        toWindow:[self window]]);
}


- (void) removeTrackingArea:(UITrackingArea *) item
{
   UIWindow   *window;
   uintptr_t  index;

   index = mulle_pointerarray_find( &_trackingAreas, item);
   if( index == mulle_not_found_e)
      return;

   [item autorelease];
   mulle_pointerarray_remove_in_range( &_trackingAreas, mulle_range_make( index, 1));
//   if( mulle_pointerarray_get_count( &_trackingAreas) == 0)
//   {
//      window = [self window];
//      assert( window);
//      [window removeTrackingView:self];
//   }
}


- (void) removeAllTrackingAreas
{
   UIWindow   *window;

   mulle_pointerarray_autorelease_all( &_trackingAreas);
   mulle_pointerarray_reset( &_trackingAreas);

   // not necessarily wanted though
   // window = [self window];
   // assert( window);
   // [window removeTrackingView:self];
}


- (void) updateTrackingAreas
{
   struct mulle_pointerarrayenumerator   rover;
   UITrackingArea                        *area;
   CGRect                                rect;

   //
   // go through tracking areas, if we have autoresize ones treat them
   // 
   rover = mulle_pointerarray_enumerate( &_trackingAreas);
   while( _mulle__pointerarrayenumerator_next( &rover, (void **) area))
   {
      // gotta keep them alive (can't toss it if NULL)
      rect = CGRectZero;
      if( [area options] & UITrackingInVisibleRect)
         rect = [self visibleRect];
      [area setRect:rect];
   }
}


- (void) setNeedsDisplay
{
   UIWindow   *window;

   window = [self window];
#ifdef DEBUG
   if( ! window)
      MulleUILog( @"%@ has no window, so setNeedsDisplay does nothing");
#endif
   [window setNeedsDisplay];
}



- (BOOL) needsLayout
{
   UIWindow   *window;

   window = [self window];
   assert( window);
   return( [window needsLayout]);
}

//
// propagate up, but stop if already marked
//
- (void) setNeedsLayout
{
   UIWindow   *window;

   window = [self window];
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
