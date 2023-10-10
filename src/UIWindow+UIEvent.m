#define _GNU_SOURCE

#import "UIWindow+UIEvent.h"

#import "import-private.h"

#import "UIWindow+Frame.h"
#import "UIWindow+Thread.h"
#import "UIWindow+DebugPrivate.h"
#import "UIWindow+UITrackingArea.h"
#import "UIWindow+UIResponder.h"
#import "UIView+UITrackingArea.h"
#import "UIView+UIResponder.h"
#import "UIView+UIWindow.h"


//#define FAKE_MOUSE_MOTION_CALLBACK_DEBUG
//#define ABORT_ON_EVENT_OVERFLOW



#ifdef FAKE_MOUSE_MOTION_CALLBACK_DEBUG
@interface UIMouseMotionFakeEvent : UIMouseMotionEvent
@end

@implementation UIMouseMotionFakeEvent

// need to do this as we can't partake in reuse
+ (id) alloc
{
   return( NSAllocateObject( self, 0, NULL));
}


- (void) dealloc
{
   NSDeallocateObject( self);
}

@end


#else
# define UIMouseMotionFakeEvent   UIMouseMotionEvent
#endif


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

   UIWindowWindowEventLog( "handle %#@", event);

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
      [self setNeedsDisplayBits:~0];
      return( nil);

   case UIWindowEventTypeResize :
      // [self _setSize:CGSizeMakeWithIntegerSize( [(UIWindowResizeEvent *) event size])];
      _isResizing = YES;

      [self setNeedsDisplayBits:~0];
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
         UIWindowWindowEventLog( "%s short circuits refresh and swap",
                  UIWindowEventTypeUTF8String( [event windowEventType]));
         //
         // events coming on the main window, so we can't be rendering here
         // if _context is nil, it's fine
         //
         [_context setInitializedFramebuffer:NO];

         // immediately refresh framebuffer
         [self setNeedsRefresh:NO];
         [self refresh];
         [self swapBuffersImmediately];

         // window thread may want to check if geometry has changed and
         // redraw if needed
         [self getFrameInfo:&info];
         [self syncFrameInfo:&info];
      }
      return( nil);
   }

   return( event);
}


- (UIMouseMotionEvent *) acceptMouseMotionEvent:(UIMouseMotionEvent *) event
{
   BOOL   inDrag;

   if( [self isTracking])
   {
      UIWindowMouseMotionEventLog( event, "trackingAreasEnabled: %btd", _trackingAreasEnabled);
      if( _trackingAreasEnabled)
      {
         inDrag = [event buttonStates] != 0;
         [self handleTrackingAreaForInputEvent:event
                                        inDrag:inDrag];

      }
   }

   return( event);
}


- (UIInputEvent *) acceptDebugKeyboardEvent:(UIKeyboardEvent *) keyEvent
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


- (UIInputEvent *) receiveInputEvent:(UIInputEvent *) event
{
   CGPoint       location;
   CGPoint       contentLocation;
   UIView        *view;
   UIInputEvent  *changableEvent;

// from UIView+CGGeometry
   location        = [(UIInputEvent *) event locationInWindow];
   contentLocation = [self contentLocationForLocation:location];

   UIWindowEventLogVerbose( event, "translated: %s -> %s [c=%s]\n",
                                        CGPointUTF8String( location),
                                        CGPointUTF8String( contentLocation),
                                        CGRectUTF8String( [self contentRect]));

   if( ! [self directHitTest:contentLocation
              withInputEvent:event])
      return( event);

   changableEvent = event;
   view = [self hitSearchSubviews:contentLocation
            withInputEventPointer:&changableEvent];
   if( changableEvent)
      changableEvent = (UIInputEvent *) [view handleEvent:changableEvent];
   return( changableEvent);
}


- (UIEvent *) receiveEvent:(UIEvent *) event
{
   id <UIResponder>   firstResponder;
   NSUInteger         eventType;

   assert( event);

   UIWindowEventLog( event, NULL);
   UIWindowEventLog( event, "receive %#@ event", event);

   // keep eventType in sync with event, whenever event changes
   eventType = [event eventType];

   switch( eventType)
   {
   case UIEventTypePresses :
#ifdef DEBUG
      if( [event eventType] == UIEventTypePresses)
      {
         event     = [self acceptDebugKeyboardEvent:(UIKeyboardEvent *) event];
         eventType = [event eventType];
      }
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
      //       That way the single button clicks are more responsive.
      //       Conceivably do this in UIResponder though...
      //
      event     = [self acceptMouseMotionEvent:(UIMouseMotionEvent *) event];
      eventType = [event eventType];

      // this filters out drag events until some time has passed
      // but the rectangle thing in handleMouseMotionEvent has to be done 
      if( [(UIMouseMotionEvent *) event buttonStates] && 
          _clickOrDrag._suppressStartTimestamp + _clickOrDrag._mouseMotionSuppressionDelay > [event timestamp])
      {
         UIWindowMouseMotionEventLog( event, "Filtered due to drag detection");
         return( nil); // 
      }
      break;

   case UIEventTypeWindow :
      event     = [self handleWindowEvent:(UIWindowEvent *) event];
      eventType = [event eventType];
      break;

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
      UIWindowEventLogVerbose( event, "Window handled event itself");
      return( event);
   }

   //   if( [event isKindOfClass:[UIMouseScrollEvent class]])
   //      [self dump];


   // The first responder ... receives key events, motion events, 
   // and action messages, among others. (Mouse events and multitouch events 
   // first go to the view that is under the mouse pointer or finger)
   firstResponder = [self firstResponder];
   if( [firstResponder isFirstResponderEvent:event])
   {
      // treat motion events separately because they are clumsy when
      // setting break points
      if( eventType == UIEventTypeMotion)
         event = [firstResponder handleMouseMotionEvent:(UIMouseMotionEvent *) event];
      else
         event = [firstResponder handleEvent:event];
      eventType = [event eventType];
   }

   //
   // pass down input events to the views, except mouseMotion events,
   // which should only be consumed by firstResponder
   //
   // TODO: make this configurable though
   if( eventType != UIEventTypeMotion && [event isInputEvent])
   {
      event     = [self receiveInputEvent:(UIInputEvent *) event];
      eventType = [event eventType];
   }

   if( event)
   {
      // UIResponder now does stuff for UIWindow
      if( eventType == UIEventTypeMotion)
         event = [self handleMouseMotionEvent:(UIMouseMotionEvent *) event];
      else
         event = [self handleEvent:event];
      eventType = [event eventType];
   }

   if( event)
   {
      UIWindowEventLog( event, "No one wanted to handle event %@", event);
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
   UIWindowEventLog( event, "*** discard event due to queue overflow");
   if( _debugEnabled & UIWindowAbortOnEventOverflow)
      abort();
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
   NSUInteger   oldEventsMask;
   UIEvent      *event;

   assert( [self isWindowThread]);

   oldEventsMask = [_OSWindow discardEventsMask];
   [_OSWindow setDiscardEventsMask:~0];  // discard all
   {
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
   [_OSWindow setDiscardEventsMask:oldEventsMask];
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
   {
      mask = 0;
      for(;;)
      {
         //
         // The fake mouseMotion event is there, so that tracking areas can
         // get proper exit/enter signals after a relayout, when their area
         // moved relative to the (static) mouse cursor. It has to be sent
         // ahead of other input queued input events.
         // _sendFakeMouseMotionEvent get sets by the frame render mechanism.
         //
         if( _sendFakeMouseMotionEvent)
         {
            _sendFakeMouseMotionEvent = 0;

            event = [[UIMouseMotionFakeEvent alloc] initWithInputState:&_inputState];
            UIWindowEventLogVerbose( event, "sending fake mouse motion event: %@", event);
         }
         else
         {
            event = ui_window_pointer_fifo_read_barrier( &_eventQueue);
            if( ! event)
               break;
         }
         [event autorelease];

         // could time event time spent and then complain if it's too long
         [self receiveEvent:event];
         mask |= [event eventType];

         [pool mulleReleaseAllObjects];
      }
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
   UIWindowEventLog( nil, "send %@", event);

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
