#define _GNU_SOURCE

#import "UIPureWindow+UIEvent.h"

#import "import-private.h"

#import "UIPureWindow+FrameInfo.h"
#import "UIPureWindow+Frame.h"
#import "UIPureWindow+Thread.h"
#import "UIPureWindow+DebugPrivate.h"
#import "UIPureWindow+UIResponder.h"



//#define FAKE_MOUSE_MOTION_CALLBACK_DEBUG
//#define ABORT_ON_EVENT_OVERFLOW




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


@interface UIPureWindow( Private)

- (void) _setPosition:(CGPoint) position MULLE_OBJC_THREADSAFE_METHOD;
//- (void) _setSize:(CGSize) size;
- (void) _setFrame:(CGRect) rect;
//- (void) _setFramebufferSize:(CGPixelSize) size;

@end


@implementation UIPureWindow( UIEvent)

/*
 * Window events are special. They don't come in over the queue but are
 * dispatched directly. It's assumed that only the main window (not the
 * offscreen window) sends these events. In a multi-thread configuration
 * these events come in and are handled by the mainThread. The regular
 * evens also come in over the mainThread put are then queued for the
 * window thread.
 */
- (UIWindowEvent *) handleWindowEvent:(UIWindowEvent *) event  MULLE_OBJC_THREADSAFE_METHOD
{
   struct CGFrameInfo   info;

   assert( [NSThread mulleIsMainThread]);

   UIWindowWindowEventLog( "handle %#@", event);

   switch( [event windowEventType])
   {
   case UIWindowEventTypeClose :
      return( nil);

   case UIWindowEventTypeFramebufferResize :
      // TODO: should set bounds ?
      // [self _setFramebufferSize:[(UIWindowFramebufferResizeEvent *) event size]];
      [self setNeedsDisplayBits:UIWindowDisplayNeedsLayout | UIWindowDisplayNeedsDisplay];
      return( nil);

   case UIWindowEventTypeResize :
      // TODO: should set bounds & frame ?
      // [self _setSize:CGSizeMakeWithPixelSize( [(UIWindowResizeEvent *) event size])];
      _isResizing = YES;

      [self setNeedsDisplayBits:UIWindowDisplayNeedsLayout | UIWindowDisplayNeedsDisplay];
      return( nil);

   //
   // this necessitates a refresh on Linux, else flicker
   // but we always get a refresh afterwards, so don't do it twice
   // But how sure is that ?
   case UIWindowEventTypeMove :
      // keep this is sync
      [self _setPosition:CGPointMakeWithPixelPoint( [(UIWindowMoveEvent *) event origin])];
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
         if( [self refresh])
            [self swapBuffersImmediately];
         else
            [self setNeedsRefresh];  // nothing to show yet, try again later

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
   return( event);
}


- (UIInputEvent *) acceptDebugKeyboardEvent:(UIKeyboardEvent *) keyEvent
{
   NSUInteger   action;
   NSUInteger   key;

   action = [keyEvent action];
   if( action == UIEventButtonActionDown)
   {
      // F12 key: 301
      key = [keyEvent key];
      switch( key)
      {
      case UIEventKeyF11 :
         if( [self respondsToSelector:@selector( dumpAnimations)])
         {
            [self performSelector:@selector( dumpAnimations)];
            return( nil);
         }
         break;

      // change from F12, because CLion snarfs it and F10
      case UIEventKeyF9 :
         if( [self respondsToSelector:@selector( dump)])
         {
            [self performSelector:@selector( dump)];
            return( nil);
         }
         break;

      case UIEventKeyF8 :
         if( [self respondsToSelector:@selector( dumpProfileQueue)])
         {
            [self performSelector:@selector( dumpProfileQueue)];
            return( nil);
         }
         break;

      case UIEventKeyF7 :
         if( [self respondsToSelector:@selector( writeScreenshotToPNGUTF8String:)])
         {
            if( [self performSelector:@selector( writeScreenshotToPNGUTF8String:)
                           withObject:(id) "screenshot.png"])
               mulleui_log( "Saved \"screenshot.png\"\n");
            return( nil);
         }
         break;
      }
   }
   return( keyEvent);
}

- (UIEvent *) didChangeFramebufferGeometry
{
   return( nil);
}

// MEMO: we don't have a C callback here, because the OSWindow already
//       has a C callback for events
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
      if( eventType == UIEventTypePresses)
      {
         event     = [self acceptDebugKeyboardEvent:(UIKeyboardEvent *) event];
         eventType = [event eventType];
      }
#endif
      break;

   case UIEventTypeTouches :
      _previousEventInputState = _eventInputState;
      _eventInputState         = [(UIInputEvent *) event inputState];

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
      _previousEventInputState = _eventInputState;
      _eventInputState         = [(UIInputEvent *) event inputState];

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
         event = [self didChangeFramebufferGeometry]; // should return nil
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

      if( [event isInputEvent])
      {
         event     = [firstResponder handleInputEvent:(UIInputEvent *) event];
         eventType = [event eventType];
      }

      if( event)
      {
         event     = [firstResponder handleEvent:event];
         eventType = [event eventType];
      }
   }

   //
   // pass down input events to the views, except mouseMotion events,
   // which should only be consumed by firstResponder
   //
   // TODO: make this configurable though
   if( eventType == UIEventTypeMotion)
   {
      return( event);
//         event = [self->_view handleMouseMotionEvent:(UIMouseMotionEvent *) event];
   }

   if( [event isInputEvent])
   {
      event     = [self->_responder handleInputEvent:(UIInputEvent *) event];
      eventType = [event eventType];
   }

   if( event)
   {
      event     = [self->_responder handleEvent:event];
      eventType = [event eventType];
   }

   if( event)
   {
      UIWindowEventLog( event, "No one wanted to handle event %#@", event);
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
   if( _debuggingFlags & UIWindowAbortOnEventOverflow)
      abort();
   return( [self willDiscardEvent:event]);
}


- (BOOL) willDiscardPendingEvent:(UIEvent *) event
{
   return( [self willDiscardEvent:event]);
}


- (BOOL) isMouseMotionEventsEnabled
{
   NSUInteger   discardEventsMask;

   discardEventsMask = [_OSWindow discardEventsMask];
   return( (discardEventsMask & UIEventTypeMotion) ? NO : YES);  
} 


- (void) setMouseMotionEventsEnabled:(BOOL) flag 
{
   NSUInteger   discardEventsMask;
   NSUInteger   newDiscardEventsMask;

// not true anymore...
//   assert( [self isWindowThread]);

   discardEventsMask = [self discardEventsMask];
   if( flag)
      newDiscardEventsMask = discardEventsMask & ~UIEventTypeMotion;  // enable by clearing bit
   else
      newDiscardEventsMask = discardEventsMask & UIEventTypeMotion;   // disable by setting bit
   if( newDiscardEventsMask != discardEventsMask)
   {
      UIWindowMouseMotionEventLog( nil, "%sbles mouse motion events", flag ? "en" : "dis");
      [self setDiscardEventsMask:discardEventsMask];
   }
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

   MulleWindowProfileBegin();

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
         // _sendFakeMouseMotionEvent gets set by the frame render mechanism.
         //
         if( _sendFakeMouseMotionEvent)
         {
            _sendFakeMouseMotionEvent = 0;

            event = [[UIMouseMotionNonPhysicalEvent alloc] initWithInputState:&_eventInputState];
            UIWindowMouseMotionEventLog( event, "sending fake mouse motion event: %#@", event);
         }
         else
         {
            event = ui_window_pointer_fifo_read_barrier( &_eventQueue);
            if( ! event)
               break;
            // make event available to this thread
            [event mulleGainAccess];
         }
         [event autorelease];

         // could time event time spent and then complain if it's too long
         [self receiveEvent:event];
         mask |= [event eventType];

         [pool mulleReleaseAllPoolObjects];
      }
   }
   [pool release];

   MulleWindowProfileEnd();

   return( mask);
}


- (void) receiveRetainedEvent:(UIEvent *) event
{
   assert( [NSThread mulleIsMainThread]);
   assert( event);

   MulleWindowProfileBegin();
   //
   // if this is a "bare" mainthread window handle the event immediately
   // otherwise queue it up
   //
   if( ! _windowThread)
   {
       assert( _backingStore != UIWindowBackingStoreRetained);

       [self receiveEvent:[event autorelease]];
       MulleWindowProfileEnd();
       return;
   }

   //
   // events that can not be queued will have to be discarded
   //
   // As the window thread will pick it up, we need to relinquish access to
   // the event here. (this implicitly retains it, so if we discard we need
   // to gain access back)

   [event mulleRelinquishAccess];
   if( ui_window_pointer_fifo_write( &_eventQueue, event))
   {
      // OK, fine give it back to me (but doesn't this autorelease (?)
      [event mulleGainAccess];
      if( [self willDiscardOverflowEvent:event]) // window can figure out something
      {                                          // for super important events
         [event release]; // don't autorelease, we may not be in a releasepool
      }
      MulleWindowProfileEnd();
      return;
   }

   [self wakeupWindowThread];
   MulleWindowProfileEnd();
}


- (void) sendWindowFramebufferGeometryEvent:(struct CGWindowInfo *) info
{
   UIEvent   *event;

   event = [[UIWindowFramebufferGeometryEvent alloc] initWithWindowInfo:info];

   // TODO: sendRetainedEvent is superflous no ? As receiveRetainedEvent will
   // call wakeupWindowThread if needed

   UIWindowEventLog( nil, "send %#@", event);
   [self receiveRetainedEvent:event];
   [self wakeupWindowThread];
}

@end
