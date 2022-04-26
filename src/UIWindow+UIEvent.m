#define _GNU_SOURCE

#import "UIWindow+UIEvent.h"

#import "import-private.h"

#import "UIWindow+Frame.h"
#import "UIWindow+Thread.h"
#import "UIWindow+UIResponder.h"
#import "UIView+UIWindow.h"


//#define MOUSE_MOTION_CALLBACK_DEBUG
//#define MOUSE_BUTTON_CALLBACK_DEBUG
//#define RESIZE_CALLBACK_DEBUG
#define ABORT_ON_EVENT_OVERFLOW
#define HANDLE_EVENT_DEBUG
//#define PROCESS_EVENT_DEBUG
#define WINDOW_EVENT_CALLBACK_DEBUG


#define UIEventTypeWindowFramebufferGeometry  1001


@interface UIWindowFramebufferGeometryEvent : UIUserEvent

- (instancetype) initWithWindowInfo:(struct CGWindowInfo *) windowInfo;

@property( assign, readonly) struct CGWindowInfo   windowInfo;

@end


@implementation UIWindowFramebufferGeometryEvent

- (instancetype) initWithWindowInfo:(struct CGWindowInfo *) windowInfo
{
   assert( windowInfo);

   [self initWithEventIdentifier:UIEventTypeWindowFramebufferGeometry];
   _windowInfo = *windowInfo;
   return( self);
}


- (char *) _payloadUTF8String
{
   return( MulleObjC_asprintf( "eventIdentifier=%td frame=%.2f %.2f %.2f %.2f frameBuffer=%td %td",
                                 _eventIdentifier,
                                 _windowInfo.frame.origin.x,
                                 _windowInfo.frame.origin.y,
                                 _windowInfo.frame.size.width,
                                 _windowInfo.frame.size.height,
                                 _windowInfo.framebufferSize.width,
                                 _windowInfo.framebufferSize.height));
}

@end


@interface UIWindow( Private)

//- (void) _setPosition:(CGPoint) position;
//- (void) _setSize:(CGSize) size;
- (void) _setFrame:(CGRect) rect;
//- (void) _setFramebufferSize:(struct CGBitmapSize) size;

@end


@implementation UIWindow( UIEvent)

- (id) _firstResponder
{
   return( _firstResponder);
}


/*
 * Window events are special. They don't come in over the queue but are
 * dispatched directly. It's assumed that only the main window (not the
 * offscreen window) sends these events. In a multi-thread configuration
 * these events come in and are handled by the mainThread. The regular
 * evens also come in over the mainThread put are then queued for the
 * window thread.
 */
- (UIWindowEvent *) handleWindowEvent:(UIWindowEvent *) event
{
   CGRect  frame;

   event = (*_windowEventCallback)( self, event);
   if( ! event)
      return( event);

   assert( [NSThread mulleIsMainThread]);

#ifdef WINDOW_EVENT_CALLBACK_DEBUG
   MulleUILog( "handle %#@", event);
#endif

   switch( [event windowEventType])
   {
   case UIWindowEventTypeClose :
      // this will be polled by the main loop, which will then
      // finalize the window
      //
      _shouldClose = YES;
      return( nil);

   case UIWindowEventTypeFramebufferResize :
      // [self _setFramebufferSize:[(UIWindowFramebufferResizeEvent *) event size]];
      [self setNeedsDisplayBit:~0];
      return( nil);

   case UIWindowEventTypeResize :
      // [self _setSize:CGBitmapSizeGetSize( [(UIWindowResizeEvent *) event size])];
      _isResizing = YES;

      [self setNeedsDisplayBit:~0];
      return( nil);

   //
   // this necessitates a refresh on Linux, else flicker
   // but we always get a refresh afterwards, so don't do it twice
   // But how sure is that ?
   case UIWindowEventTypeMove :
      // [self _setPosition:CGBitmapPointGetPoint( [(UIWindowMoveEvent *) event origin])];
      return( nil);
      // fall thru

   // on linux we always get refresh event, so it's not necessary to
   // call this all the time for the other events (which could lead
   // to duplicate redraws)
   case UIWindowEventTypeRefresh :
      // we react "fast" to incoming refresh request and swap buffers
      // immediately, so that window contents look fine.
      if( _backingStore == UIWindowBackingStoreVolatile)
      {
         [self setNeedsRefresh];  // forward to OS_Window
         [UIEvent sendEmptyEvent];
         return( nil);
      }

#ifdef WINDOW_EVENT_CALLBACK_DEBUG
      MulleUILog( "%s short circuits refresh and swap",
                  UIWindowEventTypeUTF8String( [event windowEventType]));
#endif
      // immediately refresh framebuffer
      [self setNeedsRefresh:NO];
      [self refresh];
      [self swapBuffers];

      // window thread may want to check if geometry has changed and
      // redraw if needed
      [self wakeupWindowThread];

      return( nil);
   }

   return( event);
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
   NSUInteger              i;
   NSUInteger              n;
   struct UITrackingArea   *area;
   CGRect                  rect;
   CGRect                  converted;

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


- (void) handleRetainedEvent:(UIEvent *) event
{
   assert( [NSThread mulleIsMainThread]);
   assert( event);

   //
   // if this is a "bare" mainthread window handle the event immediately
   // otherwise queue it up
   //
   if( ! _windowThread)
   {
       assert( _backingStore != UIWindowBackingStoreRetained);

       [self handleEvent:[event autorelease]];
       return;
   }

   //
   // events that can not be queued will have to be discarded
   //
   if( ui_window_pointer_fifo_write( &_eventQueue, event))
   {
      if( [self willDiscardOverflowEvent:event]) // window can figure out something
      {                                          // for super important events
         [event autorelease];
      }
      return;
   }

   [self wakeupWindowThread];
}



//
// Discard events queue for the window. This has to be called by the window
// thread.
//
- (void) discardPendingEvents
{
   NSUInteger   old;

   assert( [self isWindowThread]);

   old = [_OSWindow discardEventsMask];
   [_OSWindow setDiscardEventsMask:~0];  // discard all
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
   [_OSWindow setDiscardEventsMask:old];
}



- (UIEvent *) responder:(id <UIResponder>) responder
            handleEvent:(UIEvent *) event
{
#ifdef EVENT_DEBUG
   fprintf( stderr, "%s %s\n", __PRETTY_FUNCTION__, (char *) [responder UTF8String]);
#endif

   while( responder)
   {
      // TODO: translate positions
      //       UIViewController could also be the responder here
      if( responder != (id <UIResponder>) self)
      {
         event = [responder handleEvent:event];
         if( ! event)
         {
#ifdef EVENT_DEBUG
            fprintf( stderr, "Responder %s consumed event\n", (char *) [responder UTF8String]);
#endif
            break;
         }
#ifdef EVENT_DEBUG
         fprintf( stderr, "Responder %s did not consume event, try next\n", (char *) [responder UTF8String]);
#endif
      }
      responder = [responder nextResponder];
   }

   return( event);
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
   struct CGWindowInfo                   windowInfo;

   assert( event);

#ifdef HANDLE_EVENT_DEBUG
   MulleUILog( "handle %#@ event", event);
#endif
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
                             withObject:(id) &_drawingQueue];
                  return( nil);
               }
               break;

            case 299:
               if( [self respondsToSelector:@selector( writeScreenshotToPNGUTF8String:)])
               {
                  if( [self performSelector:@selector( writeScreenshotToPNGUTF8String:)
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

   case UIEventTypeUser :
      switch( [(UIUserEvent *) event eventIdentifier])
      {
      case UIEventTypeWindowFramebufferGeometry :
         [self setNeedsLayout];
         event = nil;
         break;
      }
      break;

   default:
      break;
   }


   if( ! event)
      return( event);

//   if( [event isKindOfClass:[UIMouseScrollEvent class]])
//      [self dump];

   event = [self responder:[self firstResponder]
               handleEvent:event];
   if( ! event)
   {
#ifdef EVENT_DEBUG
      fprintf( stderr, "First Responder handled event: %s\n",
                     (char *) [responder UTF8String]);
#endif
      return( event);
   }

   //
   // pass down input events to the views
   //
   if( [event isInputEvent])
      event = [self handleInputEvent:(UIInputEvent *) event];
   return( event);
}


//
// Execute all events in the queue until empty. This has to be called by the
// Windows thread. Returns OR of eventType
//
- (NSUInteger) handleEventQueue
{
   UIEvent      *event;
   NSUInteger   mask;

   //
   // the event must be handled by the windowThread, if we have one
   //
   assert( ! _windowThread || [NSThread currentThread] == _windowThread);

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

- (void) sendRetainedEvent:(UIEvent *) event
{
#ifdef WINDOW_EVENT_CALLBACK_DEBUG
   MulleUILog( "send %@", event);
#endif

   [self handleRetainedEvent:event];
   [self wakeupWindowThread];
}


- (void) sendWindowFramebufferGeometryEvent:(struct CGWindowInfo *) info
{
   UIEvent   *event;

   event = [[UIWindowFramebufferGeometryEvent alloc] initWithWindowInfo:info];
   [self sendRetainedEvent:event];
}

@end
