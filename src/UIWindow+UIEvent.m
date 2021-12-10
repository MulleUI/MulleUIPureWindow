#define _GNU_SOURCE

#import "UIWindow+UIEvent.h"

#import "import-private.h"

#import "UIWindow+Render.h"
#import "UIWindow+UIResponder.h"
#import "UIView+UIWindow.h"


//#define CALLBACK_DEBUG
//#define MOUSE_MOTION_CALLBACK_DEBUG
//#define MOUSE_BUTTON_CALLBACK_DEBUG
//#define RESIZE_CALLBACK_DEBUG
#define ABORT_ON_EVENT_OVERFLOW


@implementation UIWindow( UIEvent)

- (id) _firstResponder
{
   return( _firstResponder);
}


# pragma mark - tracking rects

- (void) addTrackingView:(UIView *) view
{
   assert( view);
   assert( [view isKindOfClass:[UIView class]]);
   assert( [view window] == self || ! [view window]);

   assert( _mulle_pointerarray_find( &_trackingViews, view) == mulle_not_found_e);
   [view retain];
   _mulle_pointerarray_add( &_trackingViews, view);
}


- (void) removeTrackingView:(UIView *) view
{
   assert( [view isKindOfClass:[UIView class]]);

   if( _mulle_pointerarray_find( &_trackingViews, view) != mulle_not_found_e)
   {
        abort();
      //mulle_pointerarray_remove( &_trackingViews, view);
      [view autorelease];
   }
}


- (void) addTrackingAreasOfView:(UIView *) view
{
   NSUInteger                 i;
   NSUInteger                 n;
   struct UITrackingArea   *area;
   CGRect                     rect;
   CGRect                     converted;

   assert( ! view || [view isKindOfClass:[UIView class]]);
   assert( [view window] == self || ! [view window]);

   // don't track hidden view ..
   if( [view mulleIsEffectivelyHidden])
      return;

   n = [view numberOfTrackingAreas];
   for( i = 0; i < n; i++)
   {
      area      = [view trackingAreaAtIndex:i];
      rect      = UITrackingAreaGetRect( area);
      converted = [self convertRect:rect
                           fromView:view];
      assert( _quadtree);
      mulle_quadtree_insert( _quadtree, converted, view);
   }
}


- (void) setupQuadtree
{
   CGRect                                rect;
   CGRect                                bounds;
   NSUInteger                            i;
   NSUInteger                            level;
   NSUInteger                            extent;
   struct mulle_pointerarrayenumerator   rover;
   UIView                                *view;

   bounds = [self bounds];
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

   rover = mulle_pointerarray_enumerate( &_trackingViews);
   while( _mulle_pointerarrayenumerator_next( &rover, (void **) &view))
      [self addTrackingAreasOfView:view];
   mulle_pointerarrayenumerator_done( &rover);
}


static void   collect_hit_views( CGRect rect, void *payload, void *userinfo)
{
   struct mulle_pointerarray   *array = userinfo;
   UIView                      *view = payload;

   _mulle_pointerarray_add( array, view);
}


- (UIEvent *) handleMouseMotionEvent:(UIMouseMotionEvent *) event
{
   CGRect                                rect;
   CGPoint                               point;
   struct mulle_pointerarray             views;
   struct mulle_pointerarray             remaining;
   struct mulle_pointerarrayenumerator   rover;
   UIView                                *view;
   unsigned int                          n;
   BOOL                                  isDrag;

   _mulle_pointerarray_init( &views, 16, NULL);

   point = [event locationInWindow];

   //
   // this could be a dragging event though, which needs to be handled
   // without tracking areas (...). But we only handle these events if
   // a button is pressed. We don't send mouseMoved: then though (useful ?)
   //
   isDrag = [(UIMouseMotionEvent *) event buttonStates] != 0;
   n      = mulle_quadtree_find_point( _quadtree,
                                       point,
                                       collect_hit_views,
                                       &views);
   //
   // if we have no entered views and nothing is hit, then there is nothing
   // to do
   //
   if( n || mulle_pointerarray_get_count( &_enteredViews))
   {
      // first remove all views from enteredViews which are not in views
      // and send them a MouseExited event
      // send MouseMoved: events to all remaining enteredViews

      _mulle_pointerarray_init( &remaining, 16, _mulle_pointerarray_get_allocator( &_enteredViews));

      rover = mulle_pointerarray_enumerate( &_enteredViews);
       while( _mulle_pointerarrayenumerator_next( &rover, (void **) &view))
      {
         if( _mulle_pointerarray_find( &views, view) == mulle_not_found_e)
         {
            [view mouseExited:event];
         }
         else
         {
            // will be sent later by regular event handling code anyway
            if( ! isDrag)
               [view mouseMoved:event];
            _mulle_pointerarray_add( &remaining, view);
         }
      }
      mulle_pointerarrayenumerator_done( &rover);

      // remaining are now the remaining active enteredViews

      rover = mulle_pointerarray_enumerate( &views);
      while( _mulle_pointerarrayenumerator_next( &rover, (void **) &view))
      {
         if( _mulle_pointerarray_find( &remaining, view) == mulle_not_found_e)
         {
            [view mouseEntered:event];
            _mulle_pointerarray_add( &remaining, view);
         }
      }
      mulle_pointerarrayenumerator_done( &rover);

      // now move remaining to _enteredViews and switch to remaining
      mulle_pointerarray_done( &_enteredViews);
      memcpy( &_enteredViews, &remaining, sizeof( struct mulle_pointerarray));
   }
   mulle_pointerarray_done( &views);

   if( ! isDrag)
      return( nil);

   return( event);
}

/*
 * Window events are special. They don't come in over the queue but are
 * dispatched directly. It's assumed that only the main window (not the
 * offscreen window) handles these events.
 */
- (UIEvent *) handleWindowEvent:(UIWindowEvent *) event
{
   CGRect  frame;

   switch( [event windowEventType])
   {
   case UIWindowEventTypeClose :
      _shouldClose = YES;
      return( nil);

   case UIWindowEventTypeFramebufferResize :
      // ignore size, polled during next redraw anyway
      // and we are getting a refresh anyway next
#ifdef RESIZE_CALLBACK_DEBUG
   fprintf( stderr, "%s %s handled UIWindowEventTypeFramebufferResize\n",
                     __PRETTY_FUNCTION__,
                     [self UTF8String]);
#endif
      _framebufferSize = [(UIWindowFramebufferResizeEvent *) event size];
      _isResizing      = YES;
      [self setNeedsDisplay];
      return( nil);

   case UIWindowEventTypeResize :
      _frame.size = CGBitmapSizeGetSize( [(UIWindowResizeEvent *) event size]);
      _isResizing = YES;

      [self setNeedsLayout:YES];
      [self setNeedsDisplay];
#ifdef RESIZE_CALLBACK_DEBUG
   fprintf( stderr, "%s %s handled UIWindowEventTypeResize\n",
                     __PRETTY_FUNCTION__,
                     [self UTF8String]);
#endif
      return( nil);

   // this necessitates a refresh on Linux, else flicker
   case UIWindowEventTypeMove :
      _frame.origin = CGBitmapPointGetPoint( [(UIWindowMoveEvent *) event origin]);
      _needsWindowRefresh = YES; // this preempts event processing
                                 // so we can react as fast as possible
      [self setNeedsDisplay];
      return( nil);

   // on linux we always get refresh event, so it's not necessary to
   // call this all the time for the other events (which could lead
   // to duplicate redraws)
   case UIWindowEventTypeRefresh :
      _needsWindowRefresh = YES; // this preempts event processing
                                 // so we can react as fast as possible
      [self setNeedsDisplay];

      // we react "fast" to incoming refresh request and swap buffers
      // immediately, so that window contents look fine.
      if( _backingStore == UIWindowBackingStoreBuffered)
         [self swapBuffers];
      return( nil);
   }

   return( event);
}




/*
 * Event handling of the window. Events undergo the following cycle
 * ----- [main thread]
 * glfw ->
 *    UIWindow C callback ->
 *       UIEvent alloc/reuse ->
 *          UIWindow queueEvent: ->
 * ----- [window thread]
 *             UIWindow pollEvents ->
 *                UIWindow handleEvent: ->
 *                   UIEvent release ->
 *                       UIEvent reuse/dealloc
 * -----
 */

- (BOOL) willDiscardEvent:(UIEvent *) event
{
   return( YES);
}


- (BOOL) willDiscardOverflowEvent:(UIEvent *) event
{
   fprintf( stderr, "*** windows %p (%p) discards event due to queue overflow\n", self, self->_thread);
#ifdef ABORT_ON_EVENT_OVERFLOW
   abort();
#endif
   return( [self willDiscardEvent:event]);
}


- (BOOL) willDiscardPendingEvent:(UIEvent *) event
{
   return( [self willDiscardEvent:event]);
}


- (void) queueRetainedEvent:(UIEvent *) event
{
   assert( [NSThread mulleIsMainThread]);

   assert( event);

   //
   // events that can not be queued will have to be discarded
   //
   if( ui_window_pointer_fifo_write( &_eventQueue, event))
   {
      if( [self willDiscardOverflowEvent:event]) // window can figure out something
      {                                          // for super important events
         [event autorelease];
      }
   }
}

- (void) queueEvent:(UIEvent *) event
{
   [self queueRetainedEvent:[event retain]];
}


//
// Discard events queue for the window. This has to be called by the window
// thread.
//
- (void) discardPendingEvents
{
   NSUInteger   old;

   assert( [self isWindowThread]);

   old = [_os_window discardEventsMask];
   [_os_window setDiscardEventsMask:~0];  // discard all
   {
      UIEvent   *event;

      @autoreleasepool
      {
         for(;;)
         {
            event = ui_window_pointer_fifo_read_barrier( &_eventQueue);
            if( ! event)
               break;

            if( [self willDiscardPendingEvent:event]) // window can figure out something
               [event autorelease];
         }
      }
   }
   [_os_window setDiscardEventsMask:old];
}

//
// Execute all events in the queue until empty. This has to be called by the
// Windows thread. Returns OR of eventType
//
- (NSUInteger) handleEventQueue
{
   UIEvent      *event;
   NSUInteger   mask;

   mask = 0;
   for(;;)
   {
      event = ui_window_pointer_fifo_read_barrier( &_eventQueue);
      if( ! event)
         break;

      @autoreleasepool
      {
         [event autorelease];
         // could time event time spent and then complain if it's too long
         [self handleEvent:event];
         mask |= [event eventType];
      }
   }
   return( mask);
}


- (NSUInteger) pollEvents
{
   if( [NSThread mulleIsMainThread])
      [UIEvent os_pollEvents];
   return( [self handleEventQueue]);
}


// in terms of rendering, we are hopefully say in the middle of the frame
// the frame as rendered and now we do the events. We want to do also events
// coming in in the second half of the frame, but we do not want to busy wait
// nor do we want to sleep long, because of latency.
//
#ifdef ns
# undef ns
#endif
#ifdef us
# undef us
#endif

#define us( x)    (long) ((x) * 1000)
#define ms( x)    (long) (us(x) * 1000)


- (NSUInteger) waitForEvents:(CARelativeTime) timeout
                         now:(CAAbsoluteTime) now
                returnsEarly:(BOOL) returnsEarly
{
   struct timespec   delay;
   CAAbsoluteTime    then;
   NSUInteger        mask;
   CARelativeTime    diff;

   then = now + timeout;
   mask = 0;

   //
   // set this now to NO, if a window refresh events is received we
   // preempt, even if returnsEarly is NO
   //
   _needsWindowRefresh = NO;  // need this be atomic ?

   for(;;)
   {
      mask |= [self pollEvents];
      if( mask && returnsEarly)
         break;

      if( _needsWindowRefresh)
         break;

      // could also check here, if events took too much time
      diff = CAAbsoluteTimeNow() - then;
      if( diff >= 0.0)
         break;

      delay.tv_sec  = 0;
      delay.tv_nsec = diff < ms( 0.5) ? diff : ms( 0.5);
      nanosleep( &delay, NULL);
   }
   return( mask);
}


- (UIEvent *) handleEvent:(UIEvent *) event
{
   CGRect                                rect;
   CGPoint                               point;
   struct mulle_pointerarray             views;
   struct mulle_pointerarray             remaining;
   struct mulle_pointerarrayenumerator   rover;
   UIView                                *view;
   unsigned int                          n;
   BOOL                                  isDrag;
   id <UIResponder>                      responder;

   assert( event);

   if( _eventCallback)
      event = (*_eventCallback)( self, event);

   switch( [event eventType])
   {
   case UIEventTypePresses :
#ifdef DEBUG
      if( [event eventType] == UIEventTypePresses)
      {
         UIKeyboardEvent   *keyEvent;

         keyEvent = (UIKeyboardEvent *) event;
         if( [keyEvent action] == GLFW_PRESS)
         {
            // F12 key: 301
            switch( [keyEvent key])
            {
            case 301 :
               if( [self respondsToSelector:@selector( dump)])
               {
                  [self performSelector:@selector( dump)];
                  return( nil);
               }
               break;

            case 300:
               if( [self respondsToSelector:@selector( dumpRenderQueue)])
               {
                  [self performSelector:@selector( dumpRenderQueue)
                             withObject:(id) &_renderQueue];
                  return( nil);
               }
               break;

            case 299:
               if( [self respondsToSelector:@selector( saveScreenshotToFileWithSystemRepresentation:)])
               {
                  if( [self performSelector:@selector( saveScreenshotToFileWithSystemRepresentation:)
                             withObject:(id) "screenshot.png"])
                     fprintf( stderr, "Saved \"screenshot.png\"\n");
                  return( nil);
               }
               break;
            }
         }
      }
#endif
      break;

   case UIEventTypeMotion :
      event = [self handleMouseMotionEvent:(UIMouseMotionEvent *) event];
      break;

   case UIEventTypeWindow :
      event = [self handleWindowEvent:(UIWindowEvent *) event];

   default:
      break;
   }


   if( ! event)
      return( event);

//   if( [event isKindOfClass:[UIMouseScrollEvent class]])
//      [self dump];

   responder = [self firstResponder];
   if( responder)
   {
      event = [self responder:responder
                  handleEvent:event];
      if( ! event)
      {
#ifdef EVENT_DEBUG
         fprintf( stderr, "First Responder handled event: %s\n",
                        (char *) [responder UTF8String]);
#endif
         return( event);
      }
   }

   event = [super handleEvent:event];
   return( event);
}



@end

