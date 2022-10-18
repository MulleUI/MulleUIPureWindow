#define _GNU_SOURCE

#import "UIWindow+UIEvent.h"

#import "import-private.h"

#import "UIWindow+Frame.h"
#import "UIWindow+Thread.h"
#import "UIWindow+UIResponder.h"
#import "UIView+UIResponder.h"
#import "UIView+UIWindow.h"


//#define MOUSE_MOTION_CALLBACK_DEBUG
//#define MOUSE_BUTTON_CALLBACK_DEBUG
//#define RESIZE_CALLBACK_DEBUG
//#define ABORT_ON_EVENT_OVERFLOW
#define RECEIVE_EVENT_DEBUG
//#define PROCESS_EVENT_DEBUG
#define WINDOW_EVENT_CALLBACK_DEBUG
//#define FIRST_RESPONDER_DEBUG
//#define TRACKING_DEBUG
//#define EVENT_DEBUG


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
//- (void) _setFramebufferSize:(struct MulleIntegerSize) size;

@end


@implementation UIWindow( UIEvent)

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
   struct CGFrameInfo   info;

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
      // [self _setSize:CGSizeMakeWithIntegerSize( [(UIWindowResizeEvent *) event size])];
      _isResizing = YES;

      [self setNeedsDisplayBit:~0];
      return( nil);

   //
   // this necessitates a refresh on Linux, else flicker
   // but we always get a refresh afterwards, so don't do it twice
   // But how sure is that ?
   case UIWindowEventTypeMove :
      // [self _setPosition:CGPointMakeWithIntegerPoint( [(UIWindowMoveEvent *) event origin])];
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

      @autoreleasepool
      {
#ifdef WINDOW_EVENT_CALLBACK_DEBUG
      MulleUILog( "%s short circuits refresh and swap",
                  UIWindowEventTypeUTF8String( [event windowEventType]));
#endif
//      // immediately refresh framebuffer
//      [self setNeedsRefresh:NO];
//      [self refresh];
//      [self swapBuffersImmediately];

      // window thread may want to check if geometry has changed and
      // redraw if needed
         [self getFrameInfo:&info];
         [self syncFrameInfo:&info];
      }
      return( nil);
   }

   return( event);
}


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
   CGRect                                bounds;
   NSUInteger                            level;
   NSUInteger                            extent;
   struct mulle_pointerarrayenumerator   rover;
   UIView                                *view;

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

   rover = mulle_pointerarray_enumerate( &_trackingViews);
   while( _mulle_pointerarrayenumerator_next( &rover, (void **) &view))
      [self addTrackingAreasOfView:view];
   mulle_pointerarrayenumerator_done( &rover);
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
   CGPoint                               point;
   struct mulle_pointerarray             areas;
   struct mulle_pointerarray             remaining;
   UITrackingArea                        *area;
   unsigned int                          n;
   struct mulle_allocator                *allocator;
   UICursor                              *cursor;
   NSUInteger                            oldCursorGenerationCount;
   NSUInteger                            options;
   void                                  *quadtree;

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


- (UIInputEvent *) handleMouseMotionEvent:(UIMouseMotionEvent *) event
{
   BOOL   inDrag;

   if( _trackingAreasEnabled)
   {
      inDrag = [event buttonStates] != 0;
      [self handleTrackingAreaForInputEvent:event
                                     inDrag:inDrag];

   }

   return( event);
}


- (UIInputEvent *) handleDebugKeyboardEvent:(UIKeyboardEvent *) keyEvent
{
   if( [keyEvent action] == UIEventButtonActionDown)
   {
      // F12 key: 301
      switch( [keyEvent key])
      {
      case UIEventKeyF12 :
         if( [self respondsToSelector:@selector( dump)])
         {
            [self performSelector:@selector( dump)];
            return( nil);
         }
         break;

      case UIEventKeyF11 :
         if( [self respondsToSelector:@selector( dumpRenderQueue)])
         {
            [self performSelector:@selector( dumpRenderQueue)
                        withObject:(id) &_drawingQueue];
            return( nil);
         }
         break;

      case UIEventKeyF10 :
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
   return( keyEvent);
}


- (UIEvent *) responder:(id <UIResponder>) responder
            handleEvent:(UIEvent *) event
{
   UIEvent   *newEvent;

#ifdef EVENT_DEBUG
# if ! defined( MOUSE_MOTION_CALLBACK_DEBUG)
   if( [event eventType] != UIEventTypeMotion)
# endif
      MulleUILog( "%#@", responder);
#endif

   while( responder)
   {
      // TODO: translate positions
      //       UIViewController could also be the responder here
      if( responder != (id <UIResponder>) self)
      {
         newEvent = [responder handleEvent:event];
         if( ! newEvent)
         {
#if defined( EVENT_DEBUG) || defined( FIRST_RESPONDER_DEBUG)
# if ! defined( MOUSE_MOTION_CALLBACK_DEBUG)
            if( [event eventType] != UIEventTypeMotion)
# endif
               MulleUILog( "Responder %#@ consumed event", responder);
#endif
            return( newEvent);
         }

#if defined( EVENT_DEBUG) || defined( FIRST_RESPONDER_DEBUG)
         if( newEvent != event)
         {
# if ! defined( MOUSE_MOTION_CALLBACK_DEBUG)
            if( [event eventType] != UIEventTypeMotion)
# endif
               MulleUILog( "Responder %#@ changed event to %#@", responder, newEvent);
         }
#endif

#if defined( EVENT_DEBUG) || defined( FIRST_RESPONDER_DEBUG)
# if ! defined( MOUSE_MOTION_CALLBACK_DEBUG)
         if( [event eventType] != UIEventTypeMotion)
# endif
            MulleUILog( "Responder %#@ did not consume event, try next", responder);
#endif
         event = newEvent;
      }
      responder = [responder nextResponder];
   }

   return( event);
}

- (UIEvent *) receiveInputEvent:(UIInputEvent *) event
{
   CGPoint       location;
   CGPoint       contentLocation;
   UIView        *view;
   UIView        *firstView;
   UIInputEvent  *newEvent;

// from UIView+CGGeometry
   location        = [(UIInputEvent *) event locationInWindow];
   contentLocation = [self contentLocationForLocation:location];
#ifdef EVENT_DEBUG_VERBOSE
# if ! defined( MOUSE_MOTION_CALLBACK_DEBUG)
   if( [event eventType] != UIEventTypeMotion)
# endif
      MulleUILog( "translated: %s -> %s [c=%s]\n",
                  CGPointUTF8String( location),
                  CGPointUTF8String( contentLocation),
                  CGRectUTF8String( [self contentRect]));
#endif

   /*
    * Walk down UIView hierarchy. Let interactive UIViews that are
    * below the mouse pointer get first crack at the event,
    * if not consumed (or modified) pass downwards toward subviews.
    */
   firstView = [self firstUserInteractionEnabledViewAtPoint:contentLocation
                                             withInputEvent:event];
   for( view = firstView;
        view;
        view = [view nextUserInteractionEnabledViewAtPoint:[event locationInView:view]
                                            withInputEvent:event])
   {
      newEvent = (UIInputEvent *) [view handleEvent:event];
      if( ! newEvent)
         return( newEvent);

      event = newEvent;
      if( ! [newEvent isInputEvent])
         break;
   }

   //
   // The first view that was hit will then be the start of 
   // the responder chain, going up.
   //
   event = [self responder:firstView
               handleEvent:event];
   return( event);
}


- (UIEvent *) receiveEvent:(UIEvent *) event
{
   id <UIResponder>   firstResponder;
   NSUInteger         eventType;

   assert( event);

   eventType = [event eventType];

#ifdef RECEIVE_EVENT_DEBUG
# if ! defined( MOUSE_MOTION_CALLBACK_DEBUG)
   if( eventType != UIEventTypeMotion)
# endif
   {
      MulleUILog( nil);
      MulleUILog( "receive %#@ event", event);
   }
#endif

   switch( eventType)
   {
   case UIEventTypePresses :
#ifdef DEBUG
      if( [event eventType] == UIEventTypePresses)
         event = [self handleDebugKeyboardEvent:(UIKeyboardEvent *) event];
#endif
      break;

   case UIEventTypeTouches :
      _inputState = [(UIInputEvent *) event inputState];

      // TODO: if view supports mouseDragged; don't pass down touches unless
      //       there are no follow up mouse motion events. Would need to
      //       capture original event though..
      //
      // the suppression delay can be changed by the responder later in
      // its event handler routine 
      if( [(UIMouseButtonEvent *) event action] == UIEventButtonActionDown)
      {
         _clickOrDrag._suppressStartTimestamp      = [event timestamp];
         _clickOrDrag._mouseMotionSuppressionDelay = 0.1;
      }
      break;

   case UIEventTypeMotion :
      _inputState = [(UIInputEvent *) event inputState];

      // TODO: filter out drag events only for views which implement mouseDragged: methods
      //       or have a callback that makes them interested in these events (as Apple does)
      //       That way the single button clicks are more responsive
      //
      event = [self handleMouseMotionEvent:(UIMouseMotionEvent *) event];

      // this filters out drag events until some time has passed
      // but the rectangle thing in handleMouseMotionEvent has to be done 
      if( [(UIMouseMotionEvent *) event buttonStates] && 
          _clickOrDrag._suppressStartTimestamp + _clickOrDrag._mouseMotionSuppressionDelay > [event timestamp])
      {
#if defined( EVENT_DEBUG) || defined( FIRST_RESPONDER_DEBUG)
# if ! defined( MOUSE_MOTION_CALLBACK_DEBUG)
         if( [event eventType] != UIEventTypeMotion)
# endif
            MulleUILog( "Filtered due to drag detection");
#endif         
         return( nil); // 
      }
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
   {
#if defined( EVENT_DEBUG) || defined( FIRST_RESPONDER_DEBUG)
# if ! defined( MOUSE_MOTION_CALLBACK_DEBUG)
   if( [event eventType] != UIEventTypeMotion)
# endif
      MulleUILog( "Window handled event itself");
#endif
      return( event);
   }

//   if( [event isKindOfClass:[UIMouseScrollEvent class]])
//      [self dump];

   // The first responder ... receives key events, motion events, 
   // and action messages, among others. (Mouse events and multitouch events 
   // first go to the view that is under the mouse pointer or finger)
   firstResponder = [self firstResponder];
   if( [firstResponder isFirstResponderEvent:event])
      event = [self responder:firstResponder
                  handleEvent:event];

   //
   // pass down input events to the views, except mouseMotion
   // TODO: make this configurable though
   if( [event isInputEvent] && [event eventType] != UIEventTypeMotion)
   {
      event = [self receiveInputEvent:(UIInputEvent *) event];
   }

   // UIResponder now does stuff for UIWindow
   event = [self handleEvent:event];

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
   MulleUILog( "*** discard event due to queue overflow\n");
#ifdef ABORT_ON_EVENT_OVERFLOW
   abort();
#endif
   return( [self willDiscardEvent:event]);
}


- (BOOL) willDiscardPendingEvent:(UIEvent *) event
{
   return( [self willDiscardEvent:event]);
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
               [event release];  // no need to autorelease or ?
         }
      }
   }
   [_OSWindow setDiscardEventsMask:old];
}


//
// Execute all events in the queue until empty. This has to be called by the
// Windows thread. Returns OR of eventType
//
- (NSUInteger) executeEventQueue
{
   UIEvent             *event;
   NSUInteger          mask;
   NSAutoreleasePool   *pool;

   //
   // the event must be handled by the windowThread, if we have one
   //
   assert( ! _windowThread || [NSThread currentThread] == _windowThread);

   pool = [NSAutoreleasePool new];

   mask = 0;
   for(;;)
   {
      event = ui_window_pointer_fifo_read_barrier( &_eventQueue);
      if( ! event)
         break;

      [event autorelease];
      // could time event time spent and then complain if it's too long
      [self receiveEvent:event];
      mask |= [event eventType];

      [pool mulleReleaseAllObjects];
   }
   [pool release];

   return( mask);
}


- (void) receiveRetainedEvent:(UIEvent *) event
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

       [self receiveEvent:[event autorelease]];
       return;
   }

   //
   // events that can not be queued will have to be discarded
   //
   if( ui_window_pointer_fifo_write( &_eventQueue, event))
   {
      if( [self willDiscardOverflowEvent:event]) // window can figure out something
      {                                          // for super important events
         [event release]; // don't autorelease, we may not be in a releasepool
      }
      return;
   }

   [self wakeupWindowThread];
}


- (void) sendRetainedEvent:(UIEvent *) event
{
#ifdef EVENT_DEBUG
   MulleUILog( "send %@", event);
#endif

   [self receiveRetainedEvent:event];
   [self wakeupWindowThread];
}


- (void) sendWindowFramebufferGeometryEvent:(struct CGWindowInfo *) info
{
   UIEvent   *event;

   event = [[UIWindowFramebufferGeometryEvent alloc] initWithWindowInfo:info];

   // TODO: sendRetainedEvent is superflous no ? As receiveRetainedEvent will
   // call wakeupWindowThread if needed
   [self sendRetainedEvent:event];
}

@end
