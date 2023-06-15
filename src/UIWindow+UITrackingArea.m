//
// Copyright (c) 2023 Nat!, Mulle kybernetiK
//
#import "UIWindow+UITrackingArea.h"

#import "import-private.h"

#import "UIView+UITrackingArea.h"
#import "UIView+UIWindow.h"
#import "UITrackingArea.h"



@implementation UIMouseTrackingEvent

- (void) updateTrackingArea:(UITrackingArea *) area
                       type:(NSUInteger) type
{
   _area = area;
   _type = type;
}


- (void) updateWithInputEvent:(UIInputEvent *) event
{
   memcpy( self, event, sizeof( UIInputEvent));
}

@end



@implementation UIWindow ( UITrackingArea)


# pragma mark - tracking rects

- (void) addTrackingView:(UIView *) view
{
   assert( view);
   assert( [view isKindOfClass:[UIView class]]);
   assert( [view window] == (id <UIWindow>) self || ! [view window]);

   // adding a view a second time is OK, but it won't stak
   if( _mulle_pointerarray_find( &_trackingViews, view) != mulle_not_found_e)
      return;

   [view retain];
   _mulle_pointerarray_add( &_trackingViews, view);

   _quadtreeNeedsSetup = YES;
}


- (void) removeTrackingView:(UIView *) view
{
   uintptr_t   i;

   assert( [view isKindOfClass:[UIView class]]);

   i = mulle_pointerarray_find( &_trackingViews, view);
   if( i == mulle_not_found_e)
      return;

   mulle_pointerarray_remove_in_range( &_trackingViews, mulle_range_make( i, 1));
   [view autorelease];

   _quadtreeNeedsSetup = YES;
}


- (void) invalidateTrackingAreasForView:(UIView *) view
{
   UITrackingArea              *area;
   struct mulle_pointerarray   areas;
   unsigned int                n;

   if( ! view)
      return;

   [view setNeedsTrackingAreaUpdate:YES];

   n = mulle_pointerarray_get_count( &_enteredAreas);
   if( ! n)
      return;

   mulle_pointerarray_init( &areas,
                            n,
                            MulleObjCInstanceGetAllocator( self));

   mulle_pointerarray_for( &_enteredAreas, area)
   {
      if( [area owner] == view)
         [area autorelease];
      else
         mulle_pointerarray_add( &areas, area);
   }

   mulle_pointerarray_reset( &_enteredAreas);
   mulle_pointerarray_absorb( &_enteredAreas, &areas);
   mulle_pointerarray_done( &areas);
}


- (void) addTrackingAreasOfView:(UIView *) view
{
   NSUInteger              i;
   NSUInteger              n;
   UITrackingArea          *area;
   CGRect                  rect;
   CGRect                  converted;

   assert( ! view || [view isKindOfClass:[UIView class]]);
   assert( [view window] == (id <UIWindow>) self || ! [view window]);

   // do this as a "service" for the UIView
   if( [view needsTrackingAreaUpdate])
   {
      [view updateTrackingAreas];
      [view setNeedsTrackingAreaUpdate:NO];
   }

   n = [view numberOfTrackingAreas];
   for( i = 0; i < n; i++)
   {
      area = [view trackingAreaAtIndex:i];
      rect = [area rect];
      // if the rect is zero sized, there is nothing to track
      if( CGRectGetArea( rect) == 0.0)
         continue;

      converted = [self convertRect:rect
                           fromView:view];

      assert( _quadtree);
      mulle_quadtree_insert( _quadtree, converted, area);
   }
}


- (void) setupQuadtree
{
   CGRect       bounds;
   NSUInteger   level;
   NSUInteger   extent;
   UIView       *view;

   bounds = [self bounds];

   // TODO: not used, as limits are hardcoded
   extent = round( bounds.size.width < bounds.size.height ? bounds.size.width : bounds.size.height);
   level  = 0;
   while( extent > 2)
   {
      level++;
      extent >>= 1;
   }

   //
   // 1. create quadtree only, when we get an event ?
   // 2. create quadtree for every frame ?
   // 3. create quadtree only when scene (views with tracking rects change ?)
   // 4. do not create quadtree when scrolling ?
   // 5. cache freed quadtree nodes in a mulle_pointerarray ?
   //
   if( ! _quadtree)
      _quadtree = mulle_quadtree_create( bounds, 10, 10, MulleObjCInstanceGetAllocator( self));
   else
      mulle_quadtree_reset( _quadtree, bounds);

   mulle_pointerarray_for( &_trackingViews, view)
   {
      [self addTrackingAreasOfView:view];
   }
}


- (void *) quadtree
{
   if( ! _quadtree || _quadtreeNeedsSetup)
   {
     [self setupQuadtree];
     _quadtreeNeedsSetup = NO;
   }
   return( _quadtree);
}


static void   collect_hit_areas( CGRect rect, void *payload, void *userinfo)
{
   struct mulle_pointerarray   *array = userinfo;
   UITrackingArea              *area = payload;

   _mulle_pointerarray_add( array, area);
}


//
// Cursors: We don't stack cursors. We have in our quadtree for each area,
// the cursor, which should be in effect. So we don't have to stack anything
// we just ask again.
//
// Global cursor changes (like for drag and drop)
//
- (void) handleTrackingAreaForInputEvent:(UIInputEvent *) event
                                  inDrag:(BOOL) inDrag
{
   CGPoint                     point;
   NSUInteger                  oldCursorGenerationCount;
   NSUInteger                  options;
   struct mulle_allocator      *allocator;
   struct mulle_pointerarray   areas;
   struct mulle_pointerarray   remaining;
   UICursor                    *cursor;
   UITrackingArea              *area;
   unsigned int                n;
   void                        *quadtree;

   point = [event locationInWindow];

   //
   // this could be a dragging event though, which needs to be handled
   // without tracking areas (...). But we only handle these events if
   // a button is pressed. We don't send mouseMoved: then though (useful ?)
   //
   _mulle_pointerarray_init( &areas, 16, NULL);
   quadtree = [self quadtree];
   n        = mulle_quadtree_find_point( quadtree,
                                         point,
                                         collect_hit_areas,
                                         &areas);

#ifdef TRACKING_DEBUG
   MulleUILog( "handle tracking areas %u of %u", n, mulle_quadtree_count( quadtree));
#endif

   // we set the cursor shape for the tracking rectangle now, so that
   // mouseEntered: mouseExited: can override later
   oldCursorGenerationCount = _cursorGenerationCount;
   cursor                   = NULL;

   //
   // if we have *no* entered views and *nothing* is hit, then there is nothing
   // to do
   //
   if( n || mulle_pointerarray_get_count( &_enteredAreas))
   {
      if( !_reusableTrackingEvent)
         _reusableTrackingEvent = [UIMouseTrackingEvent new];
      [_reusableTrackingEvent updateWithInputEvent:event];

      // first remove all views from enteredViews which are not in views
      // and send them a MouseExited event
      // send MouseMoved: events to all remaining enteredViews

      allocator = _mulle_pointerarray_get_allocator( &_enteredAreas);
      _mulle_pointerarray_init( &remaining, 16, allocator);

      mulle_pointerarray_for( &_enteredAreas, area)
      {
         options = [area options];
         if( _mulle_pointerarray_find( &areas, area) == mulle_not_found_e)
         {
            if( ! (options & UITrackingIgnoreMouseEnteredAndExited))
            {
               [_reusableTrackingEvent updateTrackingArea:area
                                                   type:UIMouseTrackingExitedEventType];
               [[area owner] mouseExited:_reusableTrackingEvent];
            }
         }
         else
         {
            // will be sent later by regular event handling code anyway
            if( ! inDrag)
            {
               if( options & UITrackingMouseMoved)
               {
                  [_reusableTrackingEvent updateTrackingArea:area
                                                        type:UIMouseTrackingExitedEventType];
                  [[area owner] mouseMoved:_reusableTrackingEvent];
               }
            }

            // need to get cursors of active regions
            if( options & UITrackingSetCursor)
               cursor = [area cursor];

            // this tracking area is already retained by _enteredAreas
            _mulle_pointerarray_add( &remaining, area);
         }
      }

      //
      // remaining are now the remaining active enteredAreas, where we don't
      // need to do anything really, because we already sent "entered",
      // all others get an event
      //
      mulle_pointerarray_for( &areas, area)
      {
         if( _mulle_pointerarray_find( &remaining, area) != mulle_not_found_e)
            continue;

         options = [area options];
         if( ! (options & UITrackingIgnoreMouseEnteredAndExited))
         {
            // prefer recently entered regions
            if( options & UITrackingSetCursor)
               cursor = [area cursor];
            [_reusableTrackingEvent updateTrackingArea:area
                                                  type:UIMouseTrackingEnteredEventType];
            [[area owner] mouseEntered:_reusableTrackingEvent];
         }

         _mulle_pointerarray_add( &remaining, area);
      }

      // release old ones, retain new ones
      mulle_pointerarray_autorelease_all( &_enteredAreas);
      mulle_pointerarray_retain_all( &remaining);

      mulle_pointerarray_reset( &_enteredAreas);
      mulle_pointerarray_absorb( &_enteredAreas, &remaining);
   }

   mulle_pointerarray_done( &areas);

   // if we have no cursor changes due to callbacks
   // then we set the cursor
   if( oldCursorGenerationCount == _cursorGenerationCount)
   {
      if( cursor == NULL)
         cursor = [self defaultCursor];
      [self setCursor:cursor];
   }
}

@end
