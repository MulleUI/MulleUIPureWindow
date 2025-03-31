#define _GNU_SOURCE

#import "UIPureWindow.h"

#import "UIPureWindow+DebugPrivate.h"
#import "UIPureWindow+FrameInfo.h"
#import "UIPureWindow+InvocationQueue.h"
#import "UIPureWindow+Render.h"
#import "UIPureWindow+Thread.h"
#import "UIPureWindow+NSTimer.h"
#import "UIPureWindow+UIEvent.h"
#import "UIPureWindow+UIGraphicsContext.h"
#import "UIPureWindow+UIWindow.h"

#import "import-private.h"


//#define RENDER_DEBUG
//#define FLAG_DEBUG


@interface UIPureWindow ( SetFrame)

- (void) _setFrame:(CGRect) frame;

@end


PROTOCOLCLASS_IMPLEMENTATION( UIWindowFrameDelegate)

- (void) window:(UIPureWindow *) window
 willBeginFrame:(struct CGFrameInfo *) info
graphicsContext:(id <UIGraphicsContext>) context
{
}

- (void) window:(UIPureWindow *) window
    didEndFrame:(struct CGFrameInfo *) info
graphicsContext:(id <UIGraphicsContext>) context
{
}

- (void)  window:(UIPureWindow *) window
   willDrawFrame:(struct CGFrameInfo *) info
 graphicsContext:(id <UIGraphicsContext>) context
{
}

- (void)  window:(UIPureWindow *) window
    didDrawFrame:(struct CGFrameInfo *) info
 graphicsContext:(id <UIGraphicsContext>) context
{
}

PROTOCOLCLASS_END()


#define MulleObjCNSLockProtectedAssignReadAccessor( ivar, lockIvar, rval) \
   ( [lockIvar lock], rval = ivar, [lockIvar unlock], rval)

#define MulleObjCNSLockProtectedAssignWriteAccessor( ivar, lockIvar, value) \
   ( [lockIvar lock], ivar = (value), [lockIvar unlock], ivar)


static void   *MulleObjCAtomicPointerReadClearIfSet( mulle_atomic_pointer_t *pointer)
{
   void   *value;

   do
   {
      value = _mulle_atomic_pointer_read( pointer);
      if( ! value)
         break;
   }
   while( ! _mulle_atomic_pointer_cas( pointer, (void *) 0, (void *) value));

   return( value);
}


static void   MulleObjCAtomicPointerSetBit( mulle_atomic_pointer_t *pointer, uintptr_t bit)
{
   uintptr_t   old;
   uintptr_t   value;

   assert( mulle_c_popcount( bit) == 1);

   do
   {
      old   = (uintptr_t) _mulle_atomic_pointer_read( pointer);
      value = old | bit;
      if( value == old)
         break;
   }
   while( ! _mulle_atomic_pointer_cas( pointer, (void *) value, (void *) old));
}


#if 0
static void   MulleObjCAtomicPointerClearBit( mulle_atomic_pointer_t *pointer, uintptr_t bit)
{
   uintptr_t   old;
   uintptr_t   value;

   do
   {
      old   = (uintptr_t) _mulle_atomic_pointer_read( pointer);
      value = old & ~bit;
      if( value == old)
         break;
   }
   while( ! _mulle_atomic_pointer_cas( pointer, (void *) value, (void *) old));
}
#endif


@implementation NSObject ( UIPureWindow)

- (BOOL) __isUIPureWindow   MULLE_OBJC_THREADSAFE_METHOD
{
   return( NO);
}

@end


@implementation UIPureWindow

MULLE_OBJC_DEPENDS_ON_CLASS( UIApplication);


static struct
{
   NSUInteger   _debuggingFlags;
} Self;


+ (void) initialize
{
   char   *s;

   // don't rerun for subclass
   if( MulleObjCClassGetID( self) != @selector( UIPureWindow))
      return;

   s = getenv( MULLE_C_STRINGIFY( UIWindow) "DebuggingFlags");
   if( ! s)
      s = getenv( "UIDebuggingFlags");
   if( s)
      Self._debuggingFlags = strtol( s, NULL, 0);
}


+ (void) deinitialize
{
}


+ (void) setDebuggingFlags:(NSUInteger) flag    MULLE_OBJC_THREADSAFE_METHOD
{
   Self._debuggingFlags = flag;
}


+ (instancetype) windowWithFrame:(CGRect) frame;
{
   UIPureWindow *obj;

   obj = [self alloc];
   obj = [obj initWithFrame:frame];
   obj = [obj autorelease];
   return(obj);
}

+ (instancetype) windowWithFrame:(CGRect) frame
                titleUTF8String:(char *) title
                      styleMask:(NSUInteger) styleMask
{
   UIPureWindow *obj;

   obj = [self alloc];
   obj = [obj initWithFrame:frame
              titleUTF8String:title
                    styleMask:styleMask];
   obj = [obj autorelease];
   return(obj);
}


+ (Class) osWindowClass
{
   fprintf( stderr, "Someone needs to override %s to provide a OS window\n", __FUNCTION__);
   abort();
}


+ (Class) osGraphicsContextClass
{
   fprintf( stderr, "Someone needs to override %s to provide a OS graphics context\n", __FUNCTION__);
   abort();
}


void   UIWindowDisplayFrameStatisticsUpdate( struct UIWindowFrameStatistics *stats,
                                             mulle_absolutetime_t begin,
                                             mulle_absolutetime_t end)
{
   NSUInteger             i;
   mulle_relativetime_t   diff;

   if( ! stats)
      return;

   diff = end - begin;

   stats->lastEndTimestamp   = end;
   stats->lastBeginTimestamp = begin;

   // time spent for display last time
   stats->elapsedHistory[ stats->elapsedHistoryIndex] = diff;
   stats->elapsedHistoryIndex++;
   stats->elapsedHistoryIndex  &= (UIWINDOW_S_ELAPSED_HISTORY - 1);

   stats->avgElapsedHistory     = 0.0;
   for( i = 0; i < UIWINDOW_S_ELAPSED_HISTORY; i++)
      stats->avgElapsedHistory += stats->elapsedHistory[ i];
   stats->avgElapsedHistory    /= UIWINDOW_S_ELAPSED_HISTORY;
}



- (void) _init
{
   _asyncAnimationRate      = 1.0 / 60.0;
   _oldSwapInterval         = NSIntegerMax;
   _refreshContentMode      = CGContentModeTopLeft;

   _willRenderFrameCallback = UIWindowDefaultWillRenderFrameCallback;
   _rawFrameCallback        = UIWindowDefaultRawFrameCallback;
   _didRenderFrameCallback  = UIWindowDefaultDidRenderFrameCallback;

#ifdef UIWINDOW_DEBUGGING_FLAGS
   _debuggingFlags = UIWINDOW_DEBUGGING_FLAGS;
#else
   _debuggingFlags = Self._debuggingFlags;
#endif
}


- (instancetype) _initWithFrame:(CGRect) frame
{
   UIWindowDisplayBits   displayBits;

   self = [super init];
   if( ! self)
      return( self);

   [self _init];

   // this is done by startThread
   // _windowPropertyLock = [NSLock new];
   _frame              = frame;
   // not framebuffer size, the bounds need to stay in "user" render coordinates
   _bounds.size        = frame.size;

   if( _debuggingFlags)
      MulleUILog( "_initWithFrame");

   assert( frame.size.height == _frame.size.height);
   assert( frame.size.width == _frame.size.width);

   // initialize various plane for the future, currently only
   // _contentPlane can be used

   // initially dirty with renderer 1, renderer go!
   _mulle_atomic_pointer_nonatomic_write( &_needsRefresh, (void *) 1);

   // don't use ~0 it traces ugly
   // we could probably use UIWindowDisplayBitsInititalState here
   displayBits = UIWindowDisplayNeedsRedraw;
   _mulle_atomic_pointer_nonatomic_write( &_needsDisplay, (void *) displayBits);


   UIInputStateInit( &_inputState, CGPointMake( -1, -1), 0, 0);

   // preset with some useable values
   UIWindowDisplayFrameStatisticsInit( &_windowThreadStatistics);
   UIWindowDisplayFrameStatisticsInit( &_mainThreadStatistics);

   ui_window_pointer_fifo_init( &_eventQueue);
   ui_window_pointer_fifo_init( &_timerQueue);

   [self _initInvocationQueues];
   [self _initResourceStorage:&_resourceStorage];

   return( self);
}


- (instancetype) initWithOSWindow:(id <UIOSWindow>) osWindow
                offscreenOSWindow:(id <UIOSWindow>) osOffscreenWindow
{
//CGFloat    primaryMonitorPPI;
   struct CGFrameInfo   info;

   if( ! osWindow)
   {
      [self release];
      return( nil);
   }

//   primaryMonitorPPI = [osWindow os_primaryMonitorPPI];
//   if( primaryMonitorPPI == 0.0)
//   {
//      // no monitor connected, so lets just bail ? Why though ?
//      [self release];
//      return( nil);
//   }

   _OSWindow = [osWindow retain];
   [_OSWindow setParentWindow:self];

   if( osOffscreenWindow)
   {
      _offscreenOSWindow = [osOffscreenWindow retain];
      [_offscreenOSWindow setParentWindow:self];
   }

   // setup initial values while still single threaded
   [self getFrameInfo:&info];
   // _currentWindowInfo  = info.window;
   _previousWindowInfo = info.window;

   self = [self _initWithFrame:[osWindow os_windowFrame]];

   if( self)
   {
      // don't initialize offscreen window for events
      [_OSWindow os_initEvents];
      [_OSWindow setWindowEventsReceiver:self];
      [_OSWindow setEventsReceiver:self];
   }

   return( self);
}


//
// When we create a window on Linux, the first one usually stays where
// it's at, and doesn't get a refresh or move notice. But a window manager
// may reposition the subsequent window (or even the first), so we get
// a move and refresh event. The refresh event will hit after the first
// render forcing a second render sortof immediately, as the eventloop is
// positioned byhind the renderloop.
//
- (instancetype) initWithFrame:(CGRect) frame
               titleUTF8String:(char *) title
                     styleMask:(NSUInteger) styleMask
{
   id <UIOSWindow>   osWindow;
   id <UIOSWindow>   offscreenWindow;
   NSUInteger        hints;
   Class             osWindowClass;
   Class             Self;
   Class             contextClass;

   assert( [NSThread mulleIsMainThread]);

   Self          = [self class];
   osWindowClass = [Self osWindowClass];
   hints         = [Self osGraphicsHints];
   contextClass  = [Self osGraphicsContextClass];

   // TTY windows w/o graphicsContext stay at 0
   if( ! styleMask && contextClass)
      styleMask = UIWindowStyleMaskDefault|UIWindowStyleResizable;

   // if you want to create a "manual" offscreen window, this is not going
   // to be visible ever. It is kinda wasteful to have this anything else than
   // UIWindowStyleRenderNonRetainedOnly though or ?
   if( styleMask & UIWindowStyleOffscreen)
      styleMask |= UIWindowStyleInvisible;

   offscreenWindow = nil;

   // default for now
   _backingStore       = UIWindowBackingStoreVolatile;
   _offscreenStyleMask = styleMask;

   if( styleMask & UIWindowStyleProfileQueue)
      _profileQueue = mulle_structqueue_create_default( sizeof( struct MulleWindowProfileEntry),
                                                        alignof( struct MulleWindowProfileEntry),
                                                        MulleObjCInstanceGetAllocator( self));
   //
   // if we want antialiasing (usually) and the graphics context doesn't
   // support it (GLES 2.0), then force edge anti alias, so that the windows
   // aren't configured for MSAA uselessly
   //
   if( styleMask & UIWindowStyleAntiAlias)
   {
      if( [contextClass supportsAntiAliasing] == NO)
      {
         _offscreenStyleMask &= ~UIWindowStyleAntiAlias;
         _offscreenStyleMask |= UIWindowStyleForceEdgeAntiAlias;
      }
   }

   // buffered with offscreen window is the default,
   if( styleMask & (UIWindowStyleRetained|UIWindowStyleRetainedOnMainThread))
   {
      //
      // Offscreen window can be minimally sized as we use two different
      // framebuffers. Why ? Because then we have it under control and get a
      // textureID.
      //
      _offscreenStyleMask &= ~(UIWindowStyleResizable);
      _offscreenStyleMask |= UIWindowStyleInvisible|UIWindowStyleOffscreen|UIWindowStyleBare;
//      _offscreenStyleMask |= UIWindowStyleSingleBuffer; // save some memory from bogus buffer
      offscreenWindow      = [[[osWindowClass alloc] initWithFrame:CGRectMake( 0, 0, 32, 32)
                                                   titleUTF8String:"OffScreen"
                                                         styleMask:_offscreenStyleMask
                                                     graphicsHints:hints
                                                     sharingWindow:nil] autorelease];
      if( ! offscreenWindow)
      {
         [self release];
         return( nil);
      }

      //
      // MEMO: if we have a retained scenario, does it make sense to run the
      //       foreground window double buffered ?
      //
      _backingStore = (styleMask & UIWindowStyleRetainedOnMainThread)
                        ? UIWindowBackingStoreRetainedOnMainThread
                        : UIWindowBackingStoreRetained;

      // reduce styleMask for main window
      // also remove UIWindowStyleAntiAlias

      // if the offscreenWindow uses MSAA4 the osWindow also needs to support
      // it, otherwise its still jaggy ?  maybe not looks

      if( [offscreenWindow isAntiAliasing] == NO)
         styleMask &= ~(UIWindowStyleAntiAlias|UIWindowStyleForceEdgeAntiAlias|UIWindowStyleClearType|UIWindowStyleStencilStrokes);
      else
         styleMask &= ~(UIWindowStyleForceEdgeAntiAlias|UIWindowStyleStencilStrokes|UIWindowStyleClearType);
   }

   _styleMask                   = styleMask;
   //
   // we can keep the OSGraphicsContext active, if the window is running in its
   // own thread, or if it can be ascertained that only one window is open
   // ever (user resposibility then). By default we assume that the thread
   // doesn't change
   //
   _keepOSGraphicsContextActive = (styleMask & (UIWindowStyleRetained|UIWindowStyleRetainedOnMainThread)) == UIWindowStyleRetained
                                  ? UIGraphicsContextAssociated|UIGraphicsContextActive
                                  : UIGraphicsContextAssociated;

   osWindow = [[[osWindowClass alloc] initWithFrame:frame
                                    titleUTF8String:title
                                          styleMask:styleMask
                                      graphicsHints:hints
                                      sharingWindow:offscreenWindow] autorelease];

   MulleObjCObjectSetDuplicatedUTF8String( self, &_titleUTF8String, title);

   self = [self initWithOSWindow:osWindow
               offscreenOSWindow:offscreenWindow];

   return( self);
}


- (instancetype) initWithFrame:(CGRect) frame
{
   return( [self initWithFrame:frame
               titleUTF8String:"Demo"
                     styleMask:UIWindowStyleMaskDefault]);
}


- (instancetype) init
{
   return( [self initWithFrame:CGRectZero]);
}


- (void) _finalizeGraphicsContexts
{
   if( _offscreenContext)
   {
      if( ! ([_offscreenContext state] & UIGraphicsContextActive))
      {
         // if still locked somehow (keep flag) fine
         [self activateGraphicsContext:_offscreenContext
                              OSWindow:_offscreenOSWindow];
      }

      [_lastOffscreenFramebuffer mullePerformFinalize];

      [_offscreenContext mullePerformFinalize];
      [_offscreenOSWindow os_deactivateGraphicsContext];
   }
   [_offscreenContext autorelease];
   _offscreenContext = nil;

   [_lastOffscreenFramebuffer autorelease];
   _lastOffscreenFramebuffer = nil;

   if( _context)
   {
      if( ! ([_context state] & UIGraphicsContextActive))
      {
         // don't deadlock if still locked
         [self activateGraphicsContext:_context
                              OSWindow:_OSWindow];
      }
      [_context mullePerformFinalize];
      [_OSWindow os_deactivateGraphicsContext];
   }
   [_context autorelease];
   _context = nil;   
}


-(void) _finalizeOSWindows
{
   // TODO: delete window ?
   //       remove from screen ?
   [_offscreenOSWindow mullePerformFinalize];
   [_offscreenOSWindow autorelease];
   _offscreenOSWindow = nil;

   [_OSWindow setWindowEventsReceiver:nil];
   [_OSWindow setEventsReceiver:nil];
   [_OSWindow os_finalizeEvents];

   [_OSWindow mullePerformFinalize];
   [_OSWindow autorelease];
   _OSWindow = nil;   
}


- (void) finalize
{
   assert( [NSThread mulleIsMainThread]);

   // remove events from window thread and clear display flag
   // this is better than not doing it, but no guarantee that an event isn't
   // processed in the background
#ifdef DEBUG
   MulleUILog("");
#endif

   // this must have died before hand...
   assert( ! _windowThread);

   [self discardPendingTimers];
   [self discardPendingEvents];
   [self terminateAllInvocationQueues];

   // unmount all subviews, the subviews -window method will now return nil
   // which allows them to finalize

   [self _finalizeGraphicsContexts];
   [self _finalizeOSWindows];

   _firstResponder = nil;
   
   [super finalize];
}


- (void) dealloc
{
   MulleObjCObjectSetDuplicatedUTF8String( self, &_titleUTF8String, NULL);

   [_reusableTrackingEvent release];


   // now done locally in _dealloc
   //_mulle__pointerset_done( &_layoutedViews, MulleObjCInstanceGetAllocator( self));

   [self _doneResourceStorage:&_resourceStorage];
   [self _doneInvocationQueues];

   ui_window_pointer_fifo_done( &_timerQueue);
   ui_window_pointer_fifo_done( &_eventQueue);

   UIWindowDestroyProfileQueue( _profileQueue);
   [_windowPropertyLock release];

   // TODO: delete window ?
   [super dealloc];
}


//
// gain and relinquish are tailored to transfer between the UIWindow+Thread
// and the mainThread. Not for anything else (so far)
//
- (void) mulleGainAccess
{
   // more todo
   [super mulleGainAccess];

   if( _firstResponder != _responder)
      [_firstResponder mulleGainAccess];
   [_responder mulleGainAccess];

   [_offscreenOSWindow mulleGainAccess];
   [_offscreenContext mulleGainAccess];
   [_frameDelegate mulleGainAccess];
   [_userInfo mulleGainAccess];
}


- (void) mulleRelinquishAccess
{
   [_userInfo mulleRelinquishAccess];
   [_frameDelegate mulleRelinquishAccess];
   [_offscreenOSWindow mulleRelinquishAccess];
   [_offscreenContext mulleRelinquishAccess];

   [_responder mulleRelinquishAccess];
   if( _firstResponder != _responder)
      [_firstResponder mulleRelinquishAccess];

   [super mulleRelinquishAccess];
}


- (BOOL) __isUIPureWindow
{
   return( YES);
}


- (struct MulleUIResourceStorage *) _resourceStorage  MULLE_OBJC_THREADSAFE_METHOD
{
   return( &_resourceStorage);
}


//
// forward methods to _OSWindow (or UIView ?)
//
- (void *) forward:(void *) param
{
   void   *rval;
   int    fail = 0;

   rval = _MulleDynamicObjectForward( self, _cmd, param, &fail);
   if( ! fail)
      return( rval);

   assert( _OSWindow); // if nil, window should not forward...
   return( mulle_objc_object_call_variable_inline( _OSWindow,
                                                   (mulle_objc_methodid_t) _cmd,
                                                   param));
}


- (void) applicationDidAddWindow:(UIApplication *) app
{
   assert( [NSThread mulleIsMainThread]);

   _application = app;
   if( [app osKeyWindow] == nil)
   {
      [app setOSKeyWindow:_OSWindow];
   }
   [self startWindowThreadMainIfNeeded];
}


- (void) applicationDidRemoveWindow:(UIApplication *) app
{
   assert( [NSThread mulleIsMainThread]);

   // ok but how does the app get a new key window ?
   // maybe the app should run a NSNotification now
   if( [app osKeyWindow] == _OSWindow)
   {
      [app setOSKeyWindow:nil];
   }

   // if we have a window thread, we need to bring it down
   [self finalizeWindowThread];
   [self mullePerformFinalize];
   _application = nil;
}


- (void) requestClose
{
   [_OSWindow os_requestClose];
}


- (BOOL) shouldClose
{
   return( [_OSWindow os_windowShouldClose]);
}


- (CGPoint) mouseLocation
{
   return( _inputState.locationInWindow);
}


- (NSUInteger) buttonStates
{
   return( _inputState.buttonStates);
}


- (NSUInteger) keyModifiers
{
   return( _inputState.keyModifiers);
}


- (CGPixelSize) framebufferSize
{
   struct UIOSWindowInfo   info;

   [_OSWindow getOSWindowInfo:&info];
   return( UIOSWindowInfoGetFramebufferSize( &info));
}


- (CGFloat) pixelRatio
{
   struct UIOSWindowInfo   info;

   [_OSWindow getOSWindowInfo:&info];
   return( UIOSWindowInfoGetPixelRatio( &info));
}


//
// This flag is set by the OS (or the window thread) to indicate that
// either the most current offscreen buffer should be now copied to the
// foreground window (thread) or that everything needs to be drawn
// (direct)
//
- (void) setNeedsRefresh
{
   _mulle_atomic_pointer_write( &_needsRefresh, (void *) 1);
   UIWindowRefreshBitsLog( "needsRefresh: 0x%tx", (intptr_t) _mulle_atomic_pointer_read( &_needsRefresh));
}


- (void) setNeedsRefresh:(BOOL) value
{
   _mulle_atomic_pointer_write( &_needsRefresh, (void *) value);
   UIWindowRefreshBitsLog( "needsRefresh: 0x%tx", (intptr_t) _mulle_atomic_pointer_read( &_needsRefresh));
}


- (BOOL) needsRefresh
{
   void   *value;

   value = _mulle_atomic_pointer_read( &_needsRefresh);
   return( (BOOL) (uintptr_t) value);
}


- (BOOL) needsRefreshClearIfSet
{
   BOOL   flag;

   flag = (BOOL) (NSUInteger) MulleObjCAtomicPointerReadClearIfSet( &_needsRefresh);
   if( flag)
   {
      UIWindowRefreshBitsLog( "needsRefresh: 0x%tx", (intptr_t) _mulle_atomic_pointer_read( &_needsRefresh));
   }
   return( flag);
}


- (void) setNeedsDisplay
{
   assert( ! _isRendering || "window is rendering, your change will be discarded unnoticed soon");

   _mulle_atomic_pointer_write( &_needsDisplay, (void *) ~0);

   UIWindowDisplayBitsLog( "needsDisplay: 0x%tx", (intptr_t) _mulle_atomic_pointer_read( &_needsDisplay));
}


- (void) setNeedsDisplayBits:(UIWindowDisplayBits) value
{
   assert( ! _isRendering || "window is rendering, your change will be discarded unnoticed soon");

   _mulle_atomic_pointer_write( &_needsDisplay, (void *) value);

   UIWindowDisplayBitsLog( "needsDisplay: 0x%tx", (intptr_t) _mulle_atomic_pointer_read( &_needsDisplay));
}


- (void) setNeedsDisplayBit:(UIWindowDisplayBits) value
{
   assert( value);
   assert( ! _isRendering || "window is rendering, your change will be discarded unnoticed soon");

   MulleObjCAtomicPointerSetBit( &_needsDisplay, value);

   UIWindowDisplayBitsLog( "needsDisplay: 0x%tx", (intptr_t) _mulle_atomic_pointer_read( &_needsDisplay));
}


- (UIWindowDisplayBits) needsDisplay
{
   void   *value;

   value = _mulle_atomic_pointer_read( &_needsDisplay);
   return( (NSUInteger) value);
}


- (UIWindowDisplayBits) needsDisplayBitsClearIfSet
{
   return( (NSUInteger) MulleObjCAtomicPointerReadClearIfSet( &_needsDisplay));
}


/*
 *
 */
- (BOOL) isWindowThread
{
   if( ! _windowThread)
      return( [NSThread mulleIsMainThread]);
   return( [NSThread currentThread] == _windowThread);
}


- (BOOL) receivesMouseMotionEvents
{
   return( [_firstResponder isMouseMotionEnabled]);
}


//
// lets write a novel here:
// the problem with resizing is that on resize we need to provide content
// with in 1/60s
// Unfortunately, during resize for whatever reason most of the CPU time
// is already taken up by the window manager ? Or the event comes in the
// middle of our frame ?
// If we get isResizing, we should immediately abort, and provide a cheap
// facade for resizing. The best facade would be a resizable screenshot of
// our (previous) window contents.
//
// Problems: glReadPixels maybe too late (window manager already corrupted
//           framebuffer ?)
//           glReadPixels maybe too slow ?
//
// Window should re-layout because of size change. Solution: Window renders
// into a separate framebuffer. Problem: same thread, where we want to draw
// our screenshot.
// Solution: Windows creates a hidden window
// that renders with a separate thread. Problem (getting framebuffer to
// other window)
//
// - (BOOL) isResizing
// {
//    return( _isResizing);
// }

/*
 * petty accessors
 */

- (void) setAlpha:(CGFloat) value
{
   assert( 0 && "don't set alpha on window");
}


- (CGFloat) alpha
{
   return( 1.0);
}


/*
 * Only to be used by UIEvents, these don't reflect. This sets our view
 * frame/bounds (from the moved OSWindow frame. It does not set the OSWindow
 * frame.
 */
- (void) _setFrame:(CGRect) frame   MULLE_OBJC_THREADSAFE_METHOD
{
   BOOL     hasChange;

   MulleObjCLockDo( _windowPropertyLock)
   {
      hasChange = ! CGRectEqualToRect( _frame, frame);
      if( hasChange)
      {
         _frame       = frame;
         _bounds.size = frame.size;
      }
   }
}

//
- (void) _setPosition:(CGPoint) position  MULLE_OBJC_THREADSAFE_METHOD
{
   [_windowPropertyLock lock];
   {
      if( ! CGPointEqualToPoint( _frame.origin, position))
         _frame.origin = position;
   }
   [_windowPropertyLock unlock];
}
//
//
// - (void) _setSize:(CGSize) size
// {
//    CGRect   frame;
//
//    [_windowPropertyLock lock];
//    {
//       if( ! CGSizeEqualToSize( _frame.size, size))
//       {
//          _frame.size  = size;
//          _bounds.size = size;
//       }
//    }
//    [_windowPropertyLock unlock];
// }
//
// - (void) _setFramebufferSize:(CGPixelSize) size
// {
//    MulleObjCNSLockProtectedAssignWriteAccessor( _framebufferSize, _windowPropertyLock, size);
// }


/*
 * Reflecting property changed to OSWindow
 */

static void   setPropertyChangesBit( UIPureWindow *self, NSUInteger bit)
{
   NSUInteger   oldChanges;
   NSUInteger   newChanges;

   // changes property is read atomically, without locking
   do
   {
      oldChanges = (NSUInteger) _mulle_atomic_pointer_read( &self->_propertyChanges);
      newChanges = oldChanges | bit;
      if( oldChanges == newChanges)
         break;
   }
   while( ! _mulle_atomic_pointer_cas( &self->_propertyChanges, (void *) newChanges, (void *) oldChanges));
}


- (BOOL) windowPropertySet:(SEL) sel
                parameters:(void *) param
                       bit:(NSUInteger) bit
{
   BOOL   changed;

   changed = NO;    
   MulleObjCLockDo( _windowPropertyLock)
   {
      changed = (BOOL) (intptr_t) MulleObjCObjectPerformSelector( self, sel, param);
      if( changed)
         setPropertyChangesBit( self, bit);
   }

   if( changed)
      [UIEvent sendEmptyEvent];
   return( changed);
}


// returns an autoreleased copy of the title string
- (char *) titleUTF8String
{
   char   *s;

   MulleObjCLockDo( _windowPropertyLock)
   {
      s = MulleObjC_asprintf( "%s", _titleUTF8String ? _titleUTF8String : "");
   }
   return( s);
}


- (BOOL) unlocked_setTitleUTF8String:(char *) s
{
   if( _titleUTF8String == s)
      return( NO);

   if( s && _titleUTF8String && ! strcmp( s, _titleUTF8String))
      return( NO);

   MulleObjCObjectSetDuplicatedUTF8String( self, &_titleUTF8String, s);
   return( YES);
}


- (void) setTitleUTF8String:(char *) s
{
   [self windowPropertySet:@selector( unlocked_setTitleUTF8String:)
               parameters:s
                       bit:UIWindowPropertyChangeTitle];
}


- (CGRect) frame
{
   CGRect   rval;

   MulleObjCNSLockProtectedAssignReadAccessor( _frame, _windowPropertyLock, rval);
   return( rval);
}


- (BOOL) unlocked_setFrame:(CGRect) frame
{
   if( CGRectEqualToRect( _frame, frame))
      return( NO);

   _frame       = frame;
   _bounds.size = frame.size;
   setPropertyChangesBit( self, UIWindowPropertyChangeFrame);
   return( YES);
}


- (void) setFrame:(CGRect) frame
{
   [self windowPropertySet:@selector( unlocked_setFrame:)
                parameters:_param
                       bit:UIWindowPropertyChangeFrame];
}


- (UICursor *) cursor
{
   UICursor   *rval;

   MulleObjCNSLockProtectedAssignReadAccessor( _cursor,
                                               _windowPropertyLock,
                                               rval);
   return( rval);
}


- (BOOL) unlocked_setCursor:(UICursor *) cursor
{
   ++_cursorGenerationCount;

   if( _cursor == cursor)
      return( NO);

   _cursor = cursor;
   return( YES);
}


- (void) setCursor:(UICursor *) cursor
{
   [self windowPropertySet:@selector( unlocked_setCursor:)
                parameters:cursor
                       bit:UIWindowPropertyChangeCursor];
}


- (NSUInteger) discardEventsMask
{
   NSUInteger   rval;

   MulleObjCNSLockProtectedAssignReadAccessor( _discardEventsMask,
                                               _windowPropertyLock,
                                               rval);
   return( rval);
}


- (BOOL) unlocked_setDiscardEventsMask:(NSUInteger) discardEventsMask
{
   if( _discardEventsMask == discardEventsMask)
      return( NO);
   _discardEventsMask = discardEventsMask;
   return( YES);
}


- (void) setDiscardEventsMask:(NSUInteger) discardEventsMask
{
   [self windowPropertySet:@selector( unlocked_setDiscardEventsMask:)
                parameters:(void *) discardEventsMask
                       bit:UIWindowPropertyChangeDiscardEventsMask];
}


- (CGHexColor) backgroundHexColor
{
   NSUInteger   rval;

   MulleObjCNSLockProtectedAssignReadAccessor( _backgroundHexColor,
                                               _windowPropertyLock,
                                               rval);
   return( rval);
}


- (void) setBackgroundHexColor:(CGHexColor) color
{
   MulleObjCNSLockProtectedAssignWriteAccessor( _backgroundHexColor,
                                                _windowPropertyLock,
                                                color);
}


- (CGContentMode) refreshContentMode
{
   CGContentMode   rval;

   MulleObjCNSLockProtectedAssignReadAccessor( _refreshContentMode, 
                                               _windowPropertyLock, 
                                               rval);
   return( rval);
}


- (void) setRefreshContentMode:(CGContentMode) contentMode
{
   MulleObjCNSLockProtectedAssignWriteAccessor( _refreshContentMode, 
                                                _windowPropertyLock, 
                                                contentMode);
}


/*
 *
 */

- (CGRect) bounds
{
   CGRect   rect;

   rect        = [self frame];
   rect.origin = CGPointZero;
   return( rect);
}



- (void) dumpWithIndent:(NSUInteger) indent
                   FILE:(FILE *) fp
{
   NSUInteger   i;

   for( i = 0; i < indent; i++)
      fputc( ' ', fp);

   fprintf( fp, "%s: f=[%s] b=[%s]\n",
               [self UTF8String],
               CGRectUTF8String( [self frame]),
               CGRectUTF8String( [self bounds]));
}


- (void) dump
{
   [self dumpWithIndent:0
                   FILE:mulleui_log_fp];
   fflush( mulleui_log_fp);
}



void   UIWindowDestroyProfileQueue( struct mulle_structqueue *queue)
{
   struct MulleWindowProfileEntry  *entry;

   mulle_structqueue_for( queue, entry)
   {
      if( entry->flags.mode & MulleWindowProfileEntryFreeFunction)
         mulle_free( entry->function);
      if( entry->flags.mode & MulleWindowProfileEntryFreeStacktrace)
         mulle_free( entry->stacktrace);
   }
   mulle_structqueue_destroy( queue);
}


- (struct mulle_structqueue *) extractProfileQueue
{
   struct mulle_structqueue  *queue;

   queue = _profileQueue;
   if( queue)
   {
      _profileQueue = mulle_structqueue_create_default( sizeof( struct MulleWindowProfileEntry),
                                                        alignof( struct MulleWindowProfileEntry),
                                                        MulleObjCInstanceGetAllocator( self));
   }
   return( queue);
}


- (void) dumpProfileQueueToFile:(FILE *) fp
{
   struct MulleWindowProfileEntry   *entry;
   char                             *sep;
   char                             *first;

   if( ! _profileQueue)
   {
      mulle_fprintf( stderr, "Enable profiling with UIWindowStyleProfileQueue\n");
      return;
   }

   mulle_fprintf( fp, "(");
   first = "\n   ";
   sep   = first;

   MulleObjCLockDo( _windowPropertyLock)
   {
      mulle_structqueue_for( _profileQueue, entry)
      {
         mulle_fprintf( fp, "%s{ %.9f, %d, \"%#s\" }", sep,
                                                       entry->timestamp,
                                                       entry->flags.action,
                                                       entry->function);
         sep = ",\n   ";
      }
      mulle_structqueue_reset( _profileQueue);
   }
   if( sep != first)
      mulle_fprintf( fp, "\n");
   mulle_fprintf( fp, ")\n");
}


- (void) dumpProfileQueue
{
   [self dumpProfileQueueToFile:mulleui_log_fp];
   fflush( mulleui_log_fp);
}


@end
