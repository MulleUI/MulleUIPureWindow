//
// Copyright (c) 2023 Nat!, Mulle kybernetiK
//
#import "UIView+UITrackingArea.h"

#import "import-private.h"

#import <MulleUIView/UIView+DebugPrivate.h>
#import "UIWindow+UITrackingArea.h"
#import "UIWindow+NSTimer.h"
#import "UITrackingArea.h"


//#define TRACKING_AREA_DEBUG


@implementation UIView ( UITrackingArea)

// adding/removing tracking rectangles is done in UIView+UIWindow.m

- (NSUInteger) numberOfTrackingAreas
{
   return( mulle_pointerarray_get_count( &_trackingAreas));
}


- (UITrackingArea *) trackingAreaAtIndex:(NSUInteger) i
{
   UITrackingArea   *item;

// TODO: // need to throw exception here
//   if( i >=  mulle_pointerarray_get_count( &_trackingAreas))
//      abort();

   item = mulle_pointerarray_get( &_trackingAreas, i);
   return( item);
}


- (void) addRetainedTrackingArea:(UITrackingArea *) item
                       toWindow:(UIWindow *) window
{
   UIViewMouseTrackingEventLog( nil, "%#@ to %#@", item, window);

   // adding empty item is OK, because UITrackingArea init removes
   // self on empty rect
   if( ! item)
      return;

   if( mulle_pointerarray_get_count( &_trackingAreas) == 0)
   {
      [window addTrackingView:self];
   }

   if( ! [item owner])
      [item setOwner:self];
   [item setView:self]; // we need this for visibleRect calculations
   mulle_pointerarray_add( &_trackingAreas, item);
}


- (void) addTrackingArea:(UITrackingArea *) item
{
   return( [self addRetainedTrackingArea:[item retain]
                                toWindow:(UIWindow *) [self window]]);
}


- (void) addRetainedTrackingArea:(UITrackingArea *) item
{
   return( [self addRetainedTrackingArea:item
                                toWindow:(UIWindow *) [self window]]);
}


- (void) removeTrackingArea:(UITrackingArea *) item
{
   // UIWindow   *window;
   uintptr_t  index;

   UIViewMouseTrackingEventLog( nil, "%#@", item);

   index = mulle_pointerarray_find( &_trackingAreas, item);
   if( index == mulle_not_found_e)
      return;

   [item autorelease];
   mulle_pointerarray_remove_in_range( &_trackingAreas, mulle_range_make( index, 1));
//   if( mulle_pointerarray_get_count( &_trackingAreas) == 0)
//   {
//      window = (UIWindow *) [self window];
//      assert( window);
//      [window removeTrackingView:self];
//   }
}


- (void) removeAllTrackingAreas
{
   // UIWindow   *window;

   mulle_idarray_autorelease_all( &_trackingAreas);
   mulle_pointerarray_reset( &_trackingAreas);

   // not necessarily wanted though
   // window = (UIWindow *) [self window];
   // assert( window);
   // [window removeTrackingView:self];
}


- (void) updateTrackingArea:(UITrackingArea *) area
                     inRect:(CGRect) rect
           autoresizingMask:(UIViewAutoresizing) autoresizingMask
{
   CGRect                   frame;
   struct UILayoutContext   context;

   if( ! autoresizingMask)
   {
      UIViewEventLogVerbose( nil, "Keep area %@ as is, not autoresizing", area);
      return;
   }

   context = UILayoutContextMake( rect, UIEdgeInsetsZero);
   frame   = [area autoresizeWithContext:&context
                        autoresizingMask:autoresizingMask];

   UIViewEventLogVerbose( nil, "Updating area %@ for rect %s to %s",
                                 area,
                                 CGRectUTF8String( rect),
                                 CGRectUTF8String( frame));
   [area setRect:frame];
}


- (void) updateTrackingAreas
{
   UITrackingArea   *area;
   CGRect           contentRect;
   CGRect           visibleRect;

   //
   // go through tracking areas, if we have autoresize ones treat them
   //
   visibleRect = [self visibleRect];
   contentRect = [self contentRect];

   mulle_pointerarray_for( &_trackingAreas, area)
   {
      if( [area trackingAreaOptions] & UITrackingVisibleRectOnly)
      {
         UIViewEventLogVerbose( nil, "set to %s", CGRectUTF8String( visibleRect));
         [area setRect:visibleRect];
      }
      else
      {
         [self updateTrackingArea:area
                           inRect:contentRect
                 autoresizingMask:[area autoresizingMask]];
      }
   }
}


- (mulle_relativetime_t) hoverTimeInterval
{
   return( 1.0);
}


- (void) mouseEntered:(UIMouseTrackingEvent *) event
{
   UIViewMouseTrackingEventLog( event, "%#@", event);
}


- (void) mouseMoved:(UIMouseTrackingEvent *) event
{
   UIViewMouseTrackingEventLog( event, "%#@", event);
}


- (void) mouseExited:(UIMouseTrackingEvent *) event
{
   UIViewMouseTrackingEventLog( event, "%#@", event);
}


- (void) mouseHoverStarted:(UIMouseTrackingEvent *) event
{
   UIViewMouseTrackingEventLog( event, "%#@", event);
}


- (void) mouseHoverEnded:(UIMouseTrackingEvent *) event
{
   UIViewMouseTrackingEventLog( event, "%#@", event);
}

@end
