//
// Copyright (c) 2023 Nat!, Mulle kybernetiK
//
#import "UIView+UITrackingArea.h"

#import "import-private.h"

#import "UIWindow+UITrackingArea.h"
#import "UITrackingArea.h"


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

   if( ! [item owner])
      [item setOwner:self];
   [item retain];
   mulle_pointerarray_add( &_trackingAreas, item);
}


- (void) addTrackingArea:(UITrackingArea *) item
{
   return( [self addTrackingArea:item
                        toWindow:(UIWindow *) [self window]]);
}


- (void) removeTrackingArea:(UITrackingArea *) item
{
   // UIWindow   *window;
   uintptr_t  index;

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

   mulle_pointerarray_autorelease_all( &_trackingAreas);
   mulle_pointerarray_reset( &_trackingAreas);

   // not necessarily wanted though
   // window = (UIWindow *) [self window];
   // assert( window);
   // [window removeTrackingView:self];
}


- (void) updateTrackingAreas
{
   UITrackingArea   *area;
   CGRect           rect;

   //
   // go through tracking areas, if we have autoresize ones treat them
   //
   mulle_pointerarray_for( &_trackingAreas, area)
   {
      // gotta keep them alive (can't toss it, if NULL)
      rect = CGRectZero;
      if( [area options] & UITrackingInVisibleRect)
         rect = [self visibleRect];
      [area setRect:rect];
   }
}

@end
