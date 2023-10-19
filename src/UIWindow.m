#define _GNU_SOURCE

#import "UIWindow.h"

#import "UIWindow+DebugPrivate.h"
#import "UIWindow+Frame.h"
#import "UIWindow+Render.h"
#import "UIWindow+Thread.h"
#import "UIWindow+NSTimer.h"
#import "UIWindow+UIEvent.h"
#import "UIWindow+UIWindow.h"
#import "UIWindow+InvocationQueue.h"

#import "import-private.h"


//#define RENDER_DEBUG
//#define FLAG_DEBUG


@interface UIWindow ( SetFrame)

- (void) _setFrame:(CGRect) frame;

@end


PROTOCOLCLASS_IMPLEMENTATION( UIWindowFrameDelegate)

- (void) window:(UIWindow *) window
 willBeginFrame:(struct CGFrameInfo *) info
graphicsContext:(id <UIGraphicsContext>) context
{
}

- (void) window:(UIWindow *) window
    didEndFrame:(struct CGFrameInfo *) info
graphicsContext:(id <UIGraphicsContext>) context
{
}

- (void)  window:(UIWindow *) window
   willDrawFrame:(struct CGFrameInfo *) info
 graphicsContext:(id <UIGraphicsContext>) context
{
}

- (void)  window:(UIWindow *) window
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


@implementation UIWindow

MULLE_OBJC_DEPENDS_ON_CLASS( UIApplication);


static struct
{
   NSUInteger   _debugEnabled;
} Self;


+ (void) initialize
{
   char   *s;

   // don't rerun for subclass
   if( MulleObjCClassGetID( self) != @selector( UIWindow))
      return;

   s = getenv( "UIWindowDebugEnabled");
   if( s)
      Self._debugEnabled = strtol( s, NULL, 0);
   else
   {
#ifdef UIWINDOW_DEBUG_ENABLED
      Self._debugEnabled = UIWINDOW_DEBUG_ENABLED;
#endif
   }
}


+ (void) deinitialize
{
}


+ (void) setDebugEnabled:(NSUInteger) flag
{
   Self._debugEnabled = flag;
}


+ (instancetype) windowWithFrame:(CGRect) frame;
{
   return( [[[self alloc] initWithFrame:frame] autorelease]);
}


+ (instancetype) windowWithFrame:(CGRect) frame
                 titleUTF8String:(char *) title
                       styleMask:(NSUInteger) styleMask
{
   return( [[[self alloc] initWithFrame:frame
                        titleUTF8String:title
                              styleMask:styleMask] autorelease]);
}

// conveniences for quick hacks
+ (instancetype) windowWithView:(UIView *) view
                titleUTF8String:(char *) title
                      styleMask:(NSUInteger) styleMask
{
   CGRect       rect;
   NSUInteger   autoresizingMask;
   UIWindow     *window;

   autoresizingMask = [view autoresizingMask];
   if( UIViewAutoresizingIsScaling( autoresizingMask) ||
       UIViewAutoresizingIsFlexible( autoresizingMask))
   {
      styleMask |= UIWindowStyleResizable;
   }

   rect = UIEdgeInsetsExtrudeRect( [view frame], [view margins]);
   if( rect.size.width < 32)
      rect.size.width = 32;
   if( rect.size.height < 32)
      rect.size.height = 32;

   [view setAutoresizingMask:autoresizingMask];

   rect.origin = CGPointZero;
   window      = [self windowWithFrame:rect
                       titleUTF8String:title ? title : "Demo"
                             styleMask:styleMask];
   [[window contentView] addSubview:view];
   return( window);
}


+ (instancetype) windowWithView:(UIView *) view
                titleUTF8String:(char *) title
{
   return( [self windowWithView:view 
                 titleUTF8String:title
                       styleMask:UIWindowStyleMaskDefault & ~UIWindowStylePanes]);
}


// conveniences for quick hacks

+ (instancetype) windowWithLayer:(id <UILayer>) layer
                 titleUTF8String:(char *) title
                       styleMask:(NSUInteger) styleMask
{
   UIView          *view;
   CGRect          frame;
   UIEdgeInsets    margins;


   // convenience
   frame   = [layer frame];
   margins = UIEdgeInsetsMake( frame.origin.x, frame.origin.y,
                               frame.origin.x, frame.origin.y);
   frame.origin = CGPointZero;
   [layer setFrame:frame];

   view = [UIView viewWithLayer:layer];
   [view setDebugNameUTF8String:"layerContainerView"];
   [view setMargins:margins];
   [view setAutoresizingMask:UIViewAutoresizingScaleToFill];
   return( [self windowWithView:view
               titleUTF8String:title
                     styleMask:styleMask]);
}

+ (instancetype) windowWithLayer:(id <UILayer>) layer
                 titleUTF8String:(char *) title
{
   return( [self windowWithLayer:layer 
                 titleUTF8String:title
                       styleMask:UIWindowStyleMaskDefault & ~UIWindowStylePanes]);
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


static UIWindowEvent   *defaultWindowEventCallback( UIWindow *window, UIWindowEvent *event)
{
   return( event);
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
   stats->elapsedHistoryIndex &= (UIWINDOW_S_ELAPSED_HISTORY - 1);

   stats->avgElapsedHistory = 0.0;
   for( i = 0; i < UIWINDOW_S_ELAPSED_HISTORY; i++)
      stats->avgElapsedHistory += stats->elapsedHistory[ i];
   stats->avgElapsedHistory /= UIWINDOW_S_ELAPSED_HISTORY;
}


//
// No OSWindow calls in here
//
- (void) setupContentPlanesInRect:(CGRect) frame 
{
   _contentPlane = [UIView viewWithFrame:frame];

   [_contentPlane setDebugNameUTF8String:"Window/ContentPlane"];
   [_contentPlane setAutoresizingMask:UIViewAutoresizingScaleToFill];
   [_contentPlane setClipsToBounds:NO];
   [self addSubview:_contentPlane];

   _toolTipPlane = [UIView viewWithFrame:frame];
   [_toolTipPlane setDebugNameUTF8String:"Window/ToolTipPlane"];
   [_toolTipPlane setAutoresizingMask:UIViewAutoresizingScaleToFill];
   [_toolTipPlane setClipsToBounds:NO];
   [self addSubview:_toolTipPlane];
   // why is hiding this a good idea ?
   [_toolTipPlane setHidden:YES];

   _menuPlane = [UIView viewWithFrame:frame];
   [_menuPlane setAutoresizingMask:UIViewAutoresizingScaleToFill];
   [_menuPlane setDebugNameUTF8String:"Window/MenuPlane"];
   [_menuPlane setClipsToBounds:NO];
   [self addSubview:_menuPlane];
   // why is hiding this a good idea ?
   [_menuPlane setHidden:YES];

   _dragAndDropPlane = [UIView viewWithFrame:frame];
   [_dragAndDropPlane setAutoresizingMask:UIViewAutoresizingScaleToFill];
   [_dragAndDropPlane setDebugNameUTF8String:"Window/DragAndDropPlane"];
   [_dragAndDropPlane setClipsToBounds:NO];
   [self addSubview:_dragAndDropPlane];
   // why is hiding this a good idea ?
   [_dragAndDropPlane setHidden:YES];

   _alertPlane = [UIView viewWithFrame:frame];
   [_alertPlane setAutoresizingMask:UIViewAutoresizingScaleToFill];
   [_alertPlane setDebugNameUTF8String:"Window/AlertPlane"];
   [_alertPlane setClipsToBounds:NO];
   // why is hiding this a good idea ?
   [_alertPlane setHidden:YES];
   [self addSubview:_alertPlane];
}


- (BOOL) isWindowPlane:(UIView *) view
{
   return( view == _contentPlane || 
           view == _alertPlane || 
           view == _menuPlane || 
           view == _dragAndDropPlane || 
           view == _toolTipPlane);
}


- (instancetype) _initWithFrame:(CGRect) frame
{
   // UIView init
   [super initWithFrame:frame];

   _frame = frame;

   _debugEnabled = Self._debugEnabled;
   if( _debugEnabled)
      MulleUILog( "_initWithFrame");

   assert( frame.size.height == _frame.size.height);
   assert( frame.size.width == _frame.size.width);

   // initialize various plane for the future, currently only
   // _contentPlane can be used

   _mulle_pointerarray_init( &_drawingQueue, 128, MulleObjCInstanceGetAllocator( self));
   _mulle_pointerarray_init( &_delegateViews, 8, MulleObjCInstanceGetAllocator( self));

   // initially dirty with renderer 1, renderer go!
   _mulle_atomic_pointer_nonatomic_write( &_needsRefresh, (void *) 1);
   _mulle_atomic_pointer_nonatomic_write( &_needsDisplay, (void *) ~0);

   _oldSwapInterval         = NSIntegerMax;
   _willRenderFrameCallback = UIWindowDefaultWillRenderFrameCallback;
   _rawFrameCallback        = UIWindowDefaultRawFrameCallback;
   _didRenderFrameCallback  = UIWindowDefaultDidRenderFrameCallback;

   // its kinda pointless to inherit clipRects down for views, that are full
   // window size
   _clipsToBounds         = NO;
   _backgroundHexColor    = 0xFFFFFFFF;
   _refreshContentMode    = CGContentModeTopLeft;
   _asyncAnimationRate    = 1.0 / 60.0;
   _windowEventCallback   = defaultWindowEventCallback;
   _window                = self;
   _trackingAreasEnabled  = YES;
   _keepOSGraphicsContextActive = YES;  // now the default
   _loadDefaultFont             = YES;

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
   _currentWindowInfo  = info.window;
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

   if( ! styleMask)
      styleMask = UIWindowStyleMaskDefault;

   // if you want to create a "manual" offscreen window, this is not going
   // to be visible ever. It is kinda wasteful to have this anything else than
   // UIWindowStyleRenderNonRetainedOnly though or ?
   if( styleMask & UIWindowStyleOffscreen)
      styleMask |= UIWindowStyleInvisible;

   offscreenWindow = nil;

   Self          = [self class];
   osWindowClass = [Self osWindowClass];
   hints         = [Self osGraphicsHints];

   // default for now
   _backingStore       = UIWindowBackingStoreVolatile;
   _offscreenStyleMask = styleMask;

   //
   // if we want antialiasing (usually) and the graphics context doesn't
   // support it (GLES 2.0), then force edge anti alias, so that the windows
   // aren't configured for MSAA uselessly
   //
   if( styleMask & UIWindowStyleAntiAlias)
   {
      contextClass = [[self class] osGraphicsContextClass];
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

   _styleMask = styleMask;
   osWindow   = [[[osWindowClass alloc] initWithFrame:frame
                                      titleUTF8String:title
                                            styleMask:styleMask
                                        graphicsHints:hints
                                        sharingWindow:offscreenWindow] autorelease];

   MulleObjCObjectSetDuplicatedUTF8String( self, &_titleUTF8String, title);

   self = [self initWithOSWindow:osWindow
               offscreenOSWindow:offscreenWindow];
   if( styleMask & UIWindowStylePanes)
      [self setupContentPlanesInRect:[self contentRect]];
   return( self);
}



- (instancetype) initWithFrame:(CGRect) frame
{
   return( [self initWithFrame:frame
               titleUTF8String:"Demo"
                     styleMask:UIWindowStyleMaskDefault|UIWindowStyleResizable]);
}


- (void) finalize
{
   // remove events from window thread and clear display flag
   // this is better than not doing it, but no guarantee that an event isn't
   // processed in the background
#ifdef DEBUG
   MulleUILogThisMethod();
#endif

   // if we have a window thread, we need to bring it down
   if( _windowThread)
      [self finalizeWindowThread];

   [self discardPendingTimers];
   [self discardPendingEvents];
   [self terminateAllInvocationQueues];

   _mulle_atomic_pointer_write( &_needsDisplay, (void *) 0);

   // unmount all subviews, the subviews -window method will now return nil
   // which allows them to finalize
   [self removeAllSubviews];

   [self _finalizeResourceStorage:&_resourceStorage];

   if( _offscreenContext)
   {
      if( ! [_offscreenContext isActive])
      {
         // if still locked somehow (keep flag) fine
         [_offscreenOSWindow os_tryActivateGraphicsContext];
         [_offscreenContext setActive:YES];
      }

      [_lastOffscreenFramebuffer mullePerformFinalize];

      [_offscreenContext mullePerformFinalize];
      [_offscreenOSWindow os_deactivateGraphicsContext];
      [_offscreenContext setActive:NO];
   }
   [_offscreenContext autorelease];
   _offscreenContext = nil;

   [_lastOffscreenFramebuffer autorelease];
   _lastOffscreenFramebuffer = nil;

   if( _context)
   {
      if( ! [_context isActive])
      {
         // don't deadlock if still locked
         [_OSWindow os_tryActivateGraphicsContext];
         [_context setActive:YES];
      }
      [_context mullePerformFinalize];
      [_OSWindow os_deactivateGraphicsContext];
      [_context setActive:NO];
   }
   [_context autorelease];
   _context = nil;

   // TODO: delete window ?
   //       remove from screen ?
   [_offscreenOSWindow mullePerformFinalize];
   [_offscreenOSWindow autorelease];
   _offscreenOSWindow = nil;

   [_OSWindow mullePerformFinalize];
   [_OSWindow autorelease];
   _OSWindow = nil;

   _firstResponder = nil;
   _window = nil;
   
   [super finalize];
}


- (void) dealloc
{
   MulleObjCObjectSetDuplicatedUTF8String( self, &_titleUTF8String, NULL);

   [_postLayoutAnimator release];
   [_preLayoutAnimator release];

   [_reusableTrackingEvent release];

   mulle_pointerarray_release_all( &_trackingViews);
   mulle_pointerarray_done( &_trackingViews);
   mulle_pointerarray_release_all( &_enteredAreas);
   mulle_pointerarray_done( &_enteredAreas);
   mulle_pointerarray_done( &_delegateViews);
   mulle_pointerarray_done( &_drawingQueue);
   _mulle__pointerset_done( &_layoutedViews, MulleObjCInstanceGetAllocator( self));

   mulle_quadtree_destroy( _quadtree);

   ui_window_pointer_fifo_done( &_timerQueue);
   ui_window_pointer_fifo_done( &_eventQueue);
   
   [self _doneResourceStorage:&_resourceStorage];
   [self _doneInvocationQueues];

   // TODO: delete window ?
   [super dealloc];
}


- (struct MulleUIResourceStorage *) _resourceStorage
{
   return( &_resourceStorage);
}


// defined by UIView actually
- (BOOL) __isUIWindow
{
   return( YES);
}


//
// forward methods to _OSWindow
//
- (void *) forward:(void *) param
{
   assert( _OSWindow); // window should not forward...
   return( mulle_objc_object_call_variablemethodid_inline( _OSWindow,
                                                          (mulle_objc_methodid_t) _cmd,
                                                          param));
}


- (void) applicationDidAddWindow:(UIApplication *) app
{
   _application = app;
   [self startWindowThreadMainIfNeeded];
}


- (void) applicationDidRemoveWindow:(UIApplication *) app
{
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


- (struct MulleIntegerSize) framebufferSize
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
   UIWindowRefreshBitsLog( "needsRefresh: 0x%tx", (intptr_t) _mulle_atomic_pointer_read( &_needsRefresh));
   return( flag);
}


- (void) setNeedsDisplay
{
   _mulle_atomic_pointer_write( &_needsDisplay, (void *) ~0);

   UIWindowDisplayBitsLog( "needsDisplay: 0x%tx", (intptr_t) _mulle_atomic_pointer_read( &_needsDisplay));
}



- (void) setNeedsDisplayBits:(UIWindowDisplayBits) value
{
   _mulle_atomic_pointer_write( &_needsDisplay, (void *) value);

   UIWindowDisplayBitsLog( "needsDisplay: 0x%tx", (intptr_t) _mulle_atomic_pointer_read( &_needsDisplay));
}


- (void) setNeedsDisplayBit:(UIWindowDisplayBits) value
{
   assert( value);

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


- (void) setNeedsLayout
{
   [self setNeedsDisplayBit:UIWindowDisplayNeedsLayout];
}


- (BOOL) needsLayout
{
   return( [self needsDisplay] & UIWindowDisplayNeedsLayout ? YES : NO);
}


- (void) setNeedsAnimation
{
   [self setNeedsDisplayBit:UIWindowDisplayNeedsAnimation];
}


- (BOOL) needsAnimation
{
   return( [self needsDisplay] & UIWindowDisplayNeedsAnimation ? YES : NO);
}


- (void) setNeedsRedraw
{
   [self setNeedsDisplayBit:UIWindowDisplayNeedsRedraw];
}


- (BOOL) needsRedraw
{
   return( [self needsDisplay] & UIWindowDisplayNeedsRedraw ? YES : NO);

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


- (BOOL) isTracking
{
   return( mulle_pointerarray_get_count( &_trackingViews) != 0);
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
// out window.
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


- (CGAffineTransform) transformForRenderQueue:(CGAffineTransform) inherited
{
   return( CGAffineTransformMakeIdentity());
}


/*
 * Only to be used by UIEvents, these don't reflect. This sets our view
 * frame/bounds (from the moved OSWindow frame. It does not set the OSWindow
 * frame.
 */
- (void) _setFrame:(CGRect) frame
{
   [_windowPropertyLock lock];
   {
      if( ! CGRectEqualToRect( _frame, frame))
      {
         _frame       = frame;
         _bounds.size = frame.size;
      }
   }
   [_windowPropertyLock unlock];
}

//
// - (void) _setPosition:(CGPoint) position
// {
//    CGRect   frame;
//
//    [_windowPropertyLock lock];
//    {
//       if( ! CGPointEqualToPoint( _frame.origin, position))
//          _frame.origin = position;
//    }
//    [_windowPropertyLock unlock];
// }
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
// - (void) _setFramebufferSize:(struct MulleIntegerSize) size
// {
//    MulleObjCNSLockProtectedAssignWriteAccessor( _framebufferSize, _windowPropertyLock, size);
// }


/*
 * Reflecting property changed to OSWindow
 */

static void   setPropertyChangesBit( UIWindow *self, NSUInteger bit)
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


- (void) windowPropertySet:(SEL) sel
                parameters:(void *) param
                       bit:(NSUInteger) bit
{
   BOOL   changed;

   changed = NO;    
   [_windowPropertyLock lock];
   {
      changed = (BOOL) (intptr_t) MulleObjCObjectPerformSelector( self, sel, param);
      if( changed)
         setPropertyChangesBit( self, bit);
   }
   [_windowPropertyLock unlock];

   if( changed)
      [UIEvent sendEmptyEvent];
}


// returns an autoreleased copy of the title string
- (char *) titleUTF8String
{
   char   *s;

   [_windowPropertyLock lock];
   {
      s = MulleObjC_asprintf( "%s", _titleUTF8String ? _titleUTF8String : "");
   }
   [_windowPropertyLock unlock];
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


- (NSUInteger) backgroundHexColor
{
   NSUInteger   rval;

   MulleObjCNSLockProtectedAssignReadAccessor( _backgroundHexColor,
                                               _windowPropertyLock,
                                               rval);
   return( rval);
}


- (void) setBackgroundHexColor:(NSUInteger) color
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


- (void) setWindowEventCallback:(UIWindowEvent *(*)(UIWindow *, UIWindowEvent *)) callback
{
   if( ! callback)
      callback = defaultWindowEventCallback;
   _windowEventCallback = callback;
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


- (void) addLayer:(id <UILayer>) layer
{
   abort();
}


- (void) addToDelegateViews:(UIView *) view
{
   assert( _mulle_pointerarray_find( &_delegateViews, view) == mulle_not_found_e);

   _mulle_pointerarray_add( &_delegateViews, view);
}


- (void) removeFromDelegateViews:(UIView *) view
{
   extern void   mulle_pointerarray_remove( struct mulle_pointerarray *, void *);

   // defined in UIView
   mulle_pointerarray_remove( &_delegateViews, view);
}


- (void) setContentView:(UIView *) view
{
   assert( ! view || [view window] == self);
   _contentView = view;
}


- (UIView *) contentView
{
   if( ! _contentView)
      return( _contentPlane ? _contentPlane : self);
   return( _contentView);
}


- (CAAnimator *) preLayoutAnimator
{
   if( ! _preLayoutAnimator)
      _preLayoutAnimator = [CAAnimator new];
   return( _preLayoutAnimator);
}


- (CAAnimator *) postLayoutAnimator
{
   if( ! _postLayoutAnimator)
      _postLayoutAnimator = [CAAnimator new];
   return( _postLayoutAnimator);
}



- (void) dumpAnimations
{
   fprintf( stderr, "Pre Layout:\n%s\n", [_preLayoutAnimator UTF8String]);
   fprintf( stderr, "Post Layout:\n%s\n", [_postLayoutAnimator UTF8String]);
}

@end
