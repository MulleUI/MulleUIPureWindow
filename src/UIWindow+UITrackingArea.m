//
// Copyright (c) 2023 Nat!, Mulle kybernetiK
//
#import "UIWindow+UITrackingArea.h"

#import "import-private.h"

#import "UIWindow+DebugPrivate.h"
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


- (UIEventType) eventType
{
   return( UIEventTypeTracking);
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

   [self invalidateTrackingAreasForView:view];

   mulle_pointerarray_remove_in_range( &_trackingViews, mulle_range_make( i, 1));
   [view autorelease];

   _quadtreeNeedsSetup = YES;
}


- (BOOL) _hasEnteredAreasForView:(UIView *) view
{
   UITrackingArea   *area;

   // don't want to copy stuff, if there is no entered area
   mulle_pointerarray_for( &_enteredAreas, area)
   {
      if( [area view] == view)
         return( YES);
   }
   return( NO);
}


- (void) _removeEnteredAreasForView:(UIView *) view
{
   UITrackingArea              *area;
   struct mulle_pointerarray   areas;
   unsigned int                n;   

   n = mulle_pointerarray_get_count( &_enteredAreas);

   mulle_pointerarray_init( &areas,
                            n,
                            MulleObjCInstanceGetAllocator( self));

   mulle_pointerarray_for( &_enteredAreas, area)
   {
      if( [area view] == view)
         [area autorelease];
      else
         mulle_pointerarray_add( &areas, area);
   }

   mulle_pointerarray_reset( &_enteredAreas);
   mulle_pointerarray_absorb( &_enteredAreas, &areas);
   mulle_pointerarray_done( &areas);   
}


- (void) invalidateTrackingAreasForView:(UIView *) view
{
   // TODO: tie tracking areas definitetly to views
   assert( view);

   UIWindowMouseMotionEventLog( nil, "Invalidate areas of %@", view);

   if( [self _hasEnteredAreasForView:view])
      [self _removeEnteredAreasForView:view];
}


//
// this will be called when the quadtree gets set up
//
- (void) addTrackingAreasOfView:(UIView *) view
{
   NSUInteger       i;
   NSUInteger       n;
   UITrackingArea   *area;
   CGRect           rect;
   CGRect           converted;

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
      {
         UIWindowMouseMotionEventLog( nil, "ignored area %@ with empty rect %s", area, CGRectUTF8String( rect));
         continue;
      }

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
   level  = 0;
   extent = round( bounds.size.width < bounds.size.height
                   ? bounds.size.width
                   : bounds.size.height);
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
   // easy shortcut
   if( mulle_pointerarray_get_count( &_trackingViews) == 0)
      return( NULL);

   if( ! _quadtree || _quadtreeNeedsSetup)
   {
     [self setupQuadtree];
     _quadtreeNeedsSetup = NO;
   }
   return( _quadtree);
}


- (void) invalidateQuadTree
{
   _quadtreeNeedsSetup = YES;
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

- (UICursor *) handleTrackingAreaPointerArray:(struct mulle_pointerarray *) areas
                                   inputEvent:(UIInputEvent *) event
                                       inDrag:(BOOL) inDrag
{
   NSUInteger                  options;
   struct mulle_allocator      *allocator;
   struct mulle_pointerarray   remaining;
   UITrackingArea              *area;
   UICursor                    *cursor;
   BOOL                        isOutside;

   cursor = NULL;

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
      assert( area);

      options   = [area options];
      isOutside = _mulle_pointerarray_find( areas, area) == mulle_not_found_e;

      if( isOutside)
      {
         if( ! (options & UITrackingIgnoreMouseEnteredAndExited))
         {
            [_reusableTrackingEvent updateTrackingArea:area
                                                  type:UIMouseTrackingExitedEventType];
            [[area owner] mouseExited:_reusableTrackingEvent];
         }
         continue;
      }

      // will be sent later by regular event handling code anyway
      if( ! inDrag)
      {
         if( options & UITrackingMouseMoved)
         {
            [_reusableTrackingEvent updateTrackingArea:area
                                                  type:UIMouseTrackingMovedEventType];
            [[area owner] mouseMoved:_reusableTrackingEvent];
         }
      }

      // need to get cursors of active regions
      if( options & UITrackingSetCursor)
         cursor = [area cursor];

      // this tracking area is already retained by _enteredAreas
      _mulle_pointerarray_add( &remaining, area);
   }

   //
   // In "remaining" are now the remaining active enteredAreas, where we don't
   // need to do anything, as they already received "entered",
   // all others get an enter. event
   //
   mulle_pointerarray_for( areas, area)
   {
      // can have NULLs
      if( ! area)
         continue;

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

   return( cursor);
}


- (void) handleTrackingAreaForInputEvent:(UIInputEvent *) event
                                  inDrag:(BOOL) inDrag
{
   CGPoint                     point;
   NSUInteger                  oldCursorGenerationCount;
   struct mulle_pointerarray   areas;
   UICursor                    *cursor;
   unsigned int                n;
   void                        *quadtree;
   void                        *storage[ 16];
   UITrackingArea              **p;
   UITrackingArea              **sentinel;

   //
   // this could be a dragging event though, which needs to be handled
   // without tracking areas (...). But we only handle these events if
   // a button is pressed. We don't send mouseMoved: then though (though
   // there is an option for it, where it might)
   // MEMO: quit waffling about
   //
   quadtree                 = [self quadtree];
   point                    = [event locationInWindow];
   cursor                   = NULL;
   oldCursorGenerationCount = (NSUInteger) -1;  //

   mulle_pointerarray_init_with_static_pointer( &areas,
                                                storage,
                                                sizeof( storage) / sizeof( storage[ 0]),
                                                NULL);
   {
      n = mulle_quadtree_find_point( quadtree,
                                     point,
                                     collect_hit_areas,
                                     &areas);
      UIWindowMouseMotionEventLog( nil, "handle %u tracking areas (of %u total)",
                        n, mulle_quadtree_count( quadtree));

      //
      // we set the cursor shape for the tracking rectangle now, so that
      // mouseEntered: mouseExited: can override later
      //
      // we want to do this reasonably efficiently, here...
      // so we NULL out those areas that are not really hit due to a
      // visibility test, instead of copying..
      //
      if( n)
      {
         p        = (UITrackingArea **) _mulle__pointerarray_get_address( (struct mulle__pointerarray *) &areas, 0);
         sentinel = &p[ n];
         while( p < sentinel)
         {
            if( ! [*p isTrackingActiveAtLocation:point
                                        inWindow:self])
            {
               *p = NULL;
               --n;
            }
            ++p;
         }
      }
      //
      // if we have *no* entered views and *nothing* is hit, then there is nothing
      // to do
      //
      if( n || mulle_pointerarray_get_count( &_enteredAreas))
      {
         /*
          * Need to check that only a visible piece of tracking area is hit
          * for some tracking areas...
          */

         oldCursorGenerationCount = _cursorGenerationCount;
         cursor = [self handleTrackingAreaPointerArray:&areas
                                            inputEvent:event
                                                inDrag:inDrag];
      }
   }
   mulle_pointerarray_done( &areas);

   //
   // if we have no cursor changes due to callbacks
   // then we set the cursor. We don't set the cursor, if
   // oldCursorGenerationCount is -1, as then there can have been no changes
   // due to any tracking areas
   //
   if( oldCursorGenerationCount == _cursorGenerationCount)
   {
      if( cursor == NULL)
         cursor = [self defaultCursor];
      [self setCursor:cursor];
   }
}

@end
