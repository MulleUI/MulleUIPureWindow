#import "import.h"


// A "frame" is the timespan taken to fill the contents of the "framebuffer"
// that will then be displayed by swapBuffers. It doesn't contain the time
// needed to handle events.
//
// In UIWindow a "frame" usually does, "layout", "animation", "rendering" in
// this sequence.
//
#define MULLE_UI_WINDOW_THREAD_ONLY    MULLE_OBJC_THREADSAFE_METHOD

struct CGFrameInfo;

typedef UIView   UIWindowPlane;

@class GLFWOSWindow;  // move to private some time
@class UIPasteboard;
@class UIWindow;


// UIWindowBackingStoreRetained
//
// The default "retained" configuration gives us one "window" and a dual
// offscreen buffer. Renders are made into either offscreen and then used as a
// texture to draw "Window". Offscreen drawing implies use of a second thread.
// Events run on the second thread.
//
//  .------------------------.  .--------------------.---------------------.
//  | Window                 |  | Offscreen 1        | Offscreen 2         |
//  |                        |  |                    |                     |
//  |                        |  |                    |                     |
//  |                        |  |                    |                     |
//  |                        |  |                    |                     |
//  |                        |  |                    |                     |
//  |                        |  |                    |                     |
//  |                        |  |                    |                     |
//  |                        |  |                    |                     |
//  |                        |  |                    |                     |
//  |                        |  |                    |                     |
//  '------------------------'  '--------------------'---------------------'
//
// UIWindowBackingStoreRetainedOnMainThread does everything on the main thread
// this can be useful for debugging, but offers technically no advantage over
// UIWindowBackingStoreVolatile. Events run on the main thread too.
//
// UIWindowBackingStoreVolatile is just Window (which should be double
// buffered).
//
typedef NS_ENUM( NSUInteger, UIWindowBackingStoreType)
{
   UIWindowBackingStoreVolatile,  // draws to "volatile" window framebuffer
                                  // still dual buffered but needs fast code
                                  // to avoid ugliness during resize
                                  // you can use a UIWindowStyleSingleBuffer
                                  // to get single buffered...
   UIWindowBackingStoreRetainedOnMainThread, // useful for debugging only
   UIWindowBackingStoreRetained,  // safe default
};

typedef NSUInteger   UIWindowBackingStoreType;


// UIWindowStyleRetained and multi threading
//
// The UIWindow can do many of its call only on the main thread. But on the
// window render thread, we can't wait for the main thread to sync up and
// do it. For example during events, the window thread will process some method
// and want to set the window title. What is supposed to happen ? It can't
// change the window title directly, since it is not the main thread.
//
// It could put up an invocation to change the title "run on main thread",
// but run it asynchronously. Advantage: works. Disadvantages: asking the
// window for the window title, may return old title.
//
// Use snapshotting like CALayer to gather changed values. Sync them with the
// mainThread during next refresh.
//
// Still mainThread and windowThread can access same ivars, so some sort of
// locking would be needed ?
//
// Let's see it from the other side though. If UIWindow is pretty much
// "private" to the rendering thread, we need to make sure that when the main
// thread changes framebuffer and frame info during events, that these
// properties use locking. Then if there is no "willChange" set on observable
// properties, like title or icon, the refresh does not copy over the values
// during refresh to the window. These properties need also locks or atomic
// updates.
//

// as UIWindowStyleMaskDefault, but not retained (duh)
#define UIWindowStyleMaskNonRetained \
   (UIWindowStyleResizable\
    |UIWindowStylePlanes\
    |UIWindowStyleAntiAlias \
    |UIWindowStyleStencilStrokes\
    |UIWindowStyleClearType\
    |UIWindowOpenGLLibraryFallback)

// value to use if styleMask is 0
#define UIWindowStyleMaskDefault \
   (UIWindowStyleRetained|UIWindowStyleMaskNonRetained)

#define ui_window_pointer_fifo                mulle__pointerfifo128

#define ui_window_pointer_fifo_init           _mulle__pointerfifo128_init
#define ui_window_pointer_fifo_done           _mulle__pointerfifo128_done
#define ui_window_pointer_fifo_write          _mulle__pointerfifo128_write
#define ui_window_pointer_fifo_read_barrier   _mulle__pointerfifo128_read_barrier


// typedef NS_OPTIONS( NSUInteger, UIWindowFramePhase)
// {
//    UIWindowLayoutPhase    = 0x1,
//    UIWindowAnimationPhase = 0x2,
//    UIWindowRenderPhase    = 0x4
// };
//
// #define UIWindowFrameAllPhases   (~0)


// mulle addition
// MEMO: for multiple delegates one would use NSNotificationCenter or
//       some such...
PROTOCOLCLASS_INTERFACE0( UIWindowFrameDelegate)

@optional
- (void) window:(UIWindow *) window
 willBeginFrame:(struct CGFrameInfo *) info
graphicsContext:(id <UIGraphicsContext>) context;

- (void) window:(UIWindow *) window
    didEndFrame:(struct CGFrameInfo *) info
graphicsContext:(id <UIGraphicsContext>) context;

- (void)  window:(UIWindow *) window
   willDrawFrame:(struct CGFrameInfo *) info
 graphicsContext:(id <UIGraphicsContext>) context;

- (void)  window:(UIWindow *) window
    didDrawFrame:(struct CGFrameInfo *) info
 graphicsContext:(id <UIGraphicsContext>) context;

PROTOCOLCLASS_END()


//struct UIWindowRenderInfo
//{
//   struct CGFrameInfo     lastFrameInfo;
//   NSUInteger             numberOfFrames;
//   mulle_absolutetime_t   startTime;
//   mulle_absolutetime_t   lastStartTime;
//};


#define UIWINDOW_S_ELAPSED_HISTORY  4


//
// frame statistics are used to estimate time needed to refreshRate
//
struct UIWindowFrameStatistics
{
   mulle_absolutetime_t   lastBeginTimestamp;
   mulle_absolutetime_t   lastEndTimestamp;
   mulle_relativetime_t   elapsedHistory[ UIWINDOW_S_ELAPSED_HISTORY];
   NSUInteger             elapsedHistoryIndex;
   mulle_relativetime_t   avgElapsedHistory;
};

void   UIWindowDisplayFrameStatisticsUpdate( struct UIWindowFrameStatistics *stats,
                                             mulle_absolutetime_t start,
                                             mulle_absolutetime_t end);

static inline void   UIWindowDisplayFrameStatisticsInit( struct UIWindowFrameStatistics *stats)
{
   NSUInteger   i;

   if( stats)
   {
      memset( stats, 0, sizeof( *stats));
      for( i = 0; i < UIWINDOW_S_ELAPSED_HISTORY; i++)
        stats->elapsedHistory[ i] = 0.0005;
      stats->avgElapsedHistory = 0.0005;
   }
}


typedef NS_OPTIONS( NSUInteger, UIWindowPropertyChange)
{
   UIWindowPropertyChangeFrame  = 0x1,
   UIWindowPropertyChangeTitle  = 0x2,
   UIWindowPropertyChangeCursor = 0x4,
   UIWindowPropertyChangeDiscardEventsMask = 0x8
//   UIWindowPropertyChangeIcon  = 0x4
};


@class UIMouseTrackingEvent;


struct MulleClickDragDifferentiator
{
   mulle_relativetime_t   _mouseMotionSuppressionDelay;  // config value

   mulle_absolutetime_t   _suppressStartTimestamp;
};


//
// TODO: firstResponder needed for UITextField to gain keyboard focus
//
// UIWindow will forward to _OSWindow, so it implements UIOSWindow
// protocol UIWindow is implemented by +Frame.h
//
// MEMO: keep a form of UIWindow maybe a baseclass completely separate from
//       UIView and event handling. So not TrackingViews, no UIResponder etc.
//       This should make it easier to maintain in terms of justs setting
//       up and maintaining the OS windows. 
//
@interface UIWindow : MulleObject < MulleUIResourceMap>
{
   // these ivars are single thread only
   id <UIGraphicsContext>          _context;

   // these ivars are single thread only
   id <UIGraphicsContext>          _offscreenContext;
   id <UIOSWindow>                 _offscreenOSWindow;   // our drawing Window if buffered

   // TODO: full "beauty" is only needed for offscreen or ?
   NSUInteger                      _styleMask;
   NSUInteger                      _offscreenStyleMask;

   // need to setNeedsDisplay to get the renderer out of the lock and start
   // the render. The _contextLock still needs to be observed when
   // attempting to modify the view hierarchy ?
   BOOL                            _isLayouting;
   BOOL                            _isRendering;      // used in asserts, don't depend on it
   BOOL                            _isResizing;       // obsolete yet in use (?) in OneFrame
   BOOL                            _shouldClose;      // obsolete yet in use (?) in OneFrame
   NSInteger                       _oldSwapInterval;
   id                              _lastOffscreenFramebuffer;

// These ivars are used by the rendering thread only to manage the view
// hierarchy, layout, handle events and draw stuff. If there is no windowThread
// then the mainThread can access this
//
@protected
   void                            *_quadtree;
   BOOL                            _quadtreeNeedsSetup;
   UIMouseTrackingEvent            *_reusableTrackingEvent;
   
   struct mulle_pointerarray       _trackingViews;    // views with tracking areas
   struct mulle_pointerarray       _enteredAreas;     // areas with mouseEntered: sent
   struct mulle_pointerarray       _renderDelegates;  // objects with get willRenderWithAbsoluteTime: sent
   struct mulle_pointerarray       _controllers;      // viewcontroller retain point
   struct mulle_map                _invocationQueueMap;  
   struct MulleUIResourceStorage   _resourceStorage;

   CAAnimator                      *_preLayoutAnimator;
   CAAnimator                      *_postLayoutAnimator;
   struct mulle_pointerarray       _drawingQueue; // layers to render

@protected
   //
   // 8Khz at 60fps = 133 events, 256 should be ample
   // The queue is single consumer/single producer thread. The producer is
   // ALWAYS the main thread. 
   //
   struct ui_window_pointer_fifo   _eventQueue;
   struct ui_window_pointer_fifo   _timerQueue;
   int                             _sendFakeMouseMotionEvent;

   // usually if we are buffered, we have a windowThread to do everything
   NSThread                        *_windowThread;
   NSConditionLock                 *_windowThreadLock;
   mulle_absolutetime_t            _lastWindowThreadTimestamp;

   // for properties set by events, and observable properties that are
   // written to by the window thread and read by the main thread and pushed
   // into OS_Window, we need a lock (if the changes can't be done atomically)
   NSLock                          *_windowPropertyLock;

   //
   // this lock is given to the root view, you don't interact with it
   // directly from UIWindow (especially, you don't lock it)
   //
   NSRecursiveLock                 *_viewHierarchyLock;
   struct MulleClickDragDifferentiator     _clickOrDrag;
   id <UIResponder>                _firstResponder;

   // 0: unchecked 1:found -1:non found
   int                             _initialFirstResponderState;


// atomic variables accessed by both threads
@private
   // window was resized, so we need an immediate render
   mulle_atomic_pointer_t          _needsDisplay;
   // we have a fresh framebuffer drawn, pls2swap
   mulle_atomic_pointer_t          _needsRefresh;

   mulle_atomic_pointer_t          _propertyChanges;

   NSUInteger                      _cursorGenerationCount;

//   struct UIWindowRenderInfo       _renderInfo;

   // these values are only accessible to the window thread
@protected
   struct UIWindowFrameStatistics  _windowThreadStatistics;

@private
   // each view, that gets a -layout call can add itself here, and then
   // check that -layout isn't called twice during a layout
   struct mulle__pointerset        _layoutedViews;

// these values are only accessible to the main thread
@private
   mulle_absolutetime_t            _lastDidProcessEventsTimestamp;

   struct UIWindowFrameStatistics  _mainThreadStatistics;

   // the profile entries are 64 bytes, at 60 Hz thats 3840 bytes, so one hour
   // of tracing consumes 13,824,000 bytes 13 MB (not caring) :)
   // activate with special window flag
   struct mulle_structqueue        *_profileQueue;

   // only used to create UIEventTypeWindowFramebufferGeometry events
   struct CGWindowInfo             _previousWindowInfo;
   struct CGWindowInfo             _currentWindowInfo;

   // used by LED display... so ugly
   NSUInteger                      _debugDisplayBits;
   NSUInteger                      _debugReturnBits;

   // used for showing menus
   char                            _oldUserInteractionEnabled;
   char                            _oldMenuPlaneHidden;
}

//
// On Wayland, you won't be able to move/resize the window via frame.
//
@property( assign)           CGRect                frame;        // os_windowFrame of osWindow
@property( assign, readonly) CGRect                bounds;       // os_framebufferSize (of the offscreenWindow, if exists)
                                                    // bounds.origin is always 0/0

@property( assign) NSUInteger                      debuggingFlags      MULLE_OBJC_THREADSAFE_PROPERTY;



@property( retain, readonly) id <UIOSWindow>       OSWindow;

// only available during rendering use for layout code if you need
// to do font measurements, will abort if nil
@property( assign, readonly) id <UIGraphicsContext>  renderGraphicsContext;

@property( retain) id                              userInfo;
// TODO: pasteboard is a global resource and is on Application ?
@property( retain) UIPasteboard                    *pasteboard;

// get a cursor from UIApplication cursorWithStandardShape:
// NULL is the default arrow. this is the current cursor
@property( assign) UICursor                        *cursor              MULLE_OBJC_THREADSAFE_PROPERTY;

// cursor to use, when no cursor is set 
@property( assign) UICursor                        *defaultCursor;

@property( assign, getter=areTrackingAreasEnabled) BOOL   trackingAreasEnabled;

// changed by UIWindow to enable/disable mouse events
@property( assign) NSUInteger                      discardEventsMask    MULLE_OBJC_THREADSAFE_PROPERTY;

@property( assign, readonly) struct UIInputState   inputState;
@property( assign, readonly) struct UIInputState   previousInputState; // used in hover detection

@property( dynamic, assign, readonly) CGPoint      mouseLocation;
@property( dynamic, assign, readonly) NSUInteger   buttonStates;
@property( dynamic, assign, readonly) NSUInteger   keyModifiers;

// used for MulleUIPerformance (actually retained!)
// rename to something other than Delegate framePainter ?
@property( retain) id <UIWindowFrameDelegate>      frameDelegate;

// default is 1.0/60.0. Only for use in async configuration
@property( assign) mulle_relativetime_t            asyncAnimationRate;

@property( assign) NSUInteger                      swapInterval;


@property char                                     *titleUTF8String     MULLE_OBJC_THREADSAFE_PROPERTY;

// default is UIWindowBackingStoreRetained, this is more expensive. If your
// event/drawing code is very fast (within a frame), you can get by with
// UIWindowBackingStoreVolatile
@property( assign, readonly) UIWindowBackingStoreType   backingStore;

// how the backing store image is placed into the framebuffer
// default is CGContentModeScaleToFill, but CGContentModeTopLeft or
// CGContentModeCenterPoint can be better for non-resizable content
// Accessed my main thread, therefore both are lock protected
@property( assign) CGContentMode                   refreshContentMode   MULLE_OBJC_THREADSAFE_PROPERTY;
@property( assign) CGHexColor                      backgroundHexColor   MULLE_OBJC_THREADSAFE_PROPERTY;

// what's the difference to alpha ? An alpha value of 1.0 does not mean
// that all pixels are opaque. This guarantees it. The main benefit of
// setting this flag is, that you can avoid clearing the framebuffer
// color bits, which might save bandwidth
@property( getter=isOpaque) BOOL                   opaque;

// context switches are expensive, try to minimize with this setting
// this will be NO if the window is not running in its own thread
// For multiple windows on the same thread (i.e. mainThread) this must not be
// set, otherwise you see only drawings in one window
@property( assign) BOOL                            keepOSGraphicsContextActive;
// default yes
@property( assign, getter=isLoadingDefaultFont) BOOL   loadDefaultFont;

// Rendercallbacks. If the renderer is in its own thread, then all these
//                  callbacks will appear on the render thread. This thread
//                  will possibly conflict with events from the main thread.
//

// This is the "master" callback, if you override this, none of the other
// render callbacks and delegate methods will be invoked (except 
// didRenderFrameCallback). So in general keep it as 
// UIWindowDefaultRawFrameCallback. DisplayBits are UIWindowDisplayNeedsRedraw et.al.
// Returns YES, if any animations were run.
//
// Will be usually either  or 
//
@property UIWindowDisplayBits
   (*rawFrameCallback)( UIWindow *window,
                        id <UIGraphicsContext> context,
                        struct CGFrameInfo *frameInfo,
                        UIWindowDisplayBits displayBits);

// will be called immediately before rawFrameCallback, you should return
// displayBits intact, unless you know better. The framebuffer will not be
// bound yet, but the graphics context is activated. Don't draw anything
// here yet.
@property UIWindowDisplayBits
   (*willRenderFrameCallback)( UIWindow *window,
                               id <UIGraphicsContext> context,
                               struct CGFrameInfo *frameInfo,
                               UIWindowDisplayBits displayBits);

// will be called immediately after rawFrameCallback, before swapBuffers
@property UIWindowDisplayBits
   (*didRenderFrameCallback)( UIWindow *window,
                              id <UIGraphicsContext> context,
                              struct CGFrameInfo *frameInfo,
                              UIWindowDisplayBits displayBits);

//
// If this callback is set, then UIViews and CAAnimations are ignored and this 
// callback will be used for drawing, the context is already setup for 
// rendering.  UIWindowFrameDelegate methods will be sent but other callbacks
// won't. Return '1' if you are animating and need to break out of async for 
// a while.
//
@property int   (*frameCallback)( UIWindow *window,
                                  id <UIGraphicsContext> context,
                                  struct CGFrameInfo *frameInfo,
                                  UIWindowDisplayBits displayBits);
//
// This is useful to add custom drawing stuff on the bottom.
// If you return NO, it's assumed that you cleared the framebuffer yourself.
// Remember that nanovg needs the stencilbuffer cleared.
@property BOOL  (*willClearCallback)( UIWindow *window,
                                      id <UIGraphicsContext> context,
                                      struct CGFrameInfo *info);

//
// This is useful to add custom drawing stuff on the bottom.
//
@property void  (*willDrawCallback)( UIWindow *window,
                                     id <UIGraphicsContext> context,
                                     struct CGFrameInfo *info);

//
// This is useful to add custom nanovg drawing stuff on top.
//
@property void   (*didDrawObjectsCallback)( UIWindow *window,
                                            id <UIGraphicsContext> context,
                                            struct CGFrameInfo *info);
//
// This is useful to add custom Open GL drawing stuff on top of nanovg.
//
@property void   (*didDrawCallback)( UIWindow *window,
                                     id <UIGraphicsContext> context,
                                     struct CGFrameInfo *info);


// These callbacks will be called in this sequence for every frame.
// It should be obvious, that you don't do any system calls in these callbacks
// and finish ASAP. The mulle_absolutetime_t is the time the render started it will
// be the same through all callbacks.
//
@property void   (*willLayoutCallback)( UIWindow *window,
                                        struct CGFrameInfo *info);
@property void   (*didLayoutCallback)( UIWindow *window,
                                       struct CGFrameInfo *info);
@property void   (*didCreateRenderQueueCallback)( UIWindow *window,
                                                  struct CGFrameInfo *info);

//
// stage #0: after _preLayoutAnimator
// stage #1: after _postLayoutAnimator
// stage #2: after CALayer "privat" animations
// return YES if animations happened (and a redraw should happen)
@property BOOL   (*didAnimateCallback)( UIWindow *window,
                                        struct CGFrameInfo *info,
                                        NSInteger stage);

//
// This can be useful to setup stuff for the next frame. You can't draw here
// though.
//
@property void   (*didSwapBuffersCallback)( UIWindow *window, BOOL immediately);


// these two callbacks will only be called in UIWindowRetained mode, where
// a drawing thread is active. The intention of the callback is to allow
// "hacky" global variables that are thread unsafe to be attached/detached from
// the thread with -mulleGainAccess/-mulleRelinquishAccess (see candycrash
// example). Both callbacks will be executed in the drawing thread.
//
@property void   (*willStartDrawingInThreadCallback)( UIWindow *window,
                                                      NSThread *thread);
@property void   (*didStopDrawingInThreadCallback)( UIWindow *window,
                                                    NSThread *thread);

// the view will have the frame and bounds of the window, it contains the
// planes if these are defined, otherwise directly the contentView
@property( retain) UIView                     *view;

@property( readonly, assign) UIApplication    *application;

//
// these properties return nil, if styleMask did not contain UIWindowStylePlanes
// These will be subviews of "view" and "contentPlane" will be the contentView.
//
@property( readonly, assign) UIWindowPlane    *alertPlane;
@property( readonly, assign) UIWindowPlane    *dragAndDropPlane;
// MEMO: If there is one or more UIScrollView between the tooltipping UIView or
//       the menu originator, then there needs to be some way, that scrolls are
//       also scrolling entries (or that the scrollview wipes the tooltip and
//       menu away)
@property( readonly, assign) UIWindowPlane    *menuPlane;
@property( readonly, assign) UIWindowPlane    *toolTipPlane;
@property( readonly, assign) UIWindowPlane    *contentPlane;


@property( assign) id <UIResponder>           initialFirstResponder;

+ (instancetype) windowWithFrame:(CGRect) frame;

+ (instancetype) windowWithFrame:(CGRect) frame
                 titleUTF8String:(char *) title
                       styleMask:(NSUInteger) styleMask;

// Convenience for quick hacks
// Window will be resizable if the view is resizable
// margins will be observed to create spacing around the view
// if any axis is < 32 in size, 32 will be used
//
+ (instancetype) windowWithView:(UIView *) view
                titleUTF8String:(char *) title               
                      styleMask:(NSUInteger) styleMask;
+ (instancetype) windowWithView:(UIView *) view
                 titleUTF8String:(char *) title;

// even more convenient, even less configurable, for even more
// convenience checkout UIApplication+UIWindow
+ (instancetype) windowWithLayer:(id <UILayer>) layer
                 titleUTF8String:(char *) title
                       styleMask:(NSUInteger) styleMask;
                                              
+ (instancetype) windowWithLayer:(id <UILayer>) layer
                 titleUTF8String:(char *) title;

// typically that's a GLFWOSWindow, this method does not create a contentView!!
- (instancetype) initWithOSWindow:(id <UIOSWindow>) window
                offscreenOSWindow:(id <UIOSWindow>) offscreenWindow;

// default visible: closable, non-resizable, non-maximizable
- (instancetype) initWithFrame:(CGRect) frame
               titleUTF8String:(char *) title
                     styleMask:(NSUInteger) styleMask;

// calls initWithFrame:titleUTF8String:styleMask: with some "Demo" defaults
- (instancetype) initWithFrame:(CGRect) frame;


- (UIView *) contentView;
- (void) setContentView:(UIView *) view; // will either change contentPlane or view depending on setup

// does not deal with focus of events
//- (void) show;
//- (void) hide;

//
// GLFWOSWindow also has a flag like this, but UIWindow has one itself
// in  buffered configuration the currently "ready" framebuffer is
// used to refresh. In unbuffered this will do a display and then a swap.
// You usually do a [UIEvent sendEmptyEvent] afterwards to preempt the
// UIApplication event wait and to retrigger a refresh
- (void) setNeedsRefresh                     MULLE_OBJC_THREADSAFE_METHOD;
- (void) setNeedsRefresh:(BOOL) value        MULLE_OBJC_THREADSAFE_METHOD;
- (BOOL) needsRefresh                        MULLE_OBJC_THREADSAFE_METHOD;
- (BOOL) needsRefreshClearIfSet              MULLE_OBJC_THREADSAFE_METHOD;

- (BOOL) isTracking;
- (BOOL) receivesMouseMotionEvents;
//
// needs Display is a combination of needsLayout and needsRedraw, needsAnimation
// bits defined in UIWindowDisplayBits
//
// - (void) setNeedsDisplayBit:(UIWindowDisplayBit) value;  // can't zero
- (UIWindowDisplayBits) needsDisplayBitsClearIfSet        MULLE_OBJC_THREADSAFE_METHOD;

// sets more than just one bit, can also zero
- (void) setNeedsDisplayBits:(UIWindowDisplayBits) value  MULLE_OBJC_THREADSAFE_METHOD;

// legacy compatibility
- (void) setNeedsDisplay                     MULLE_OBJC_THREADSAFE_METHOD;  // sets all bits
- (UIWindowDisplayBits) needsDisplay         MULLE_OBJC_THREADSAFE_METHOD;

// force re-layout on next render, setting this flag does not affect other
// flags
- (void) setNeedsLayout                      MULLE_OBJC_THREADSAFE_METHOD;
- (BOOL) needsLayout                         MULLE_OBJC_THREADSAFE_METHOD;

// this flag means, that the there are animations running
- (void) setNeedsAnimation                   MULLE_OBJC_THREADSAFE_METHOD;
- (BOOL) needsAnimation                      MULLE_OBJC_THREADSAFE_METHOD;

// this flag means, that the UIView hierarchy needs to be drawn into
// the framebuffer
- (void) setNeedsRedraw                      MULLE_OBJC_THREADSAFE_METHOD;
- (BOOL) needsRedraw                         MULLE_OBJC_THREADSAFE_METHOD;


- (BOOL) isWindowThread                      MULLE_OBJC_THREADSAFE_METHOD;

- (CGFloat) pixelRatio                       MULLE_OBJC_THREADSAFE_METHOD;
- (CGPixelSize) framebufferSize              MULLE_OBJC_THREADSAFE_METHOD;

- (CAAnimator *) preLayoutAnimator;
- (CAAnimator *) postLayoutAnimator;

- (void) requestClose;

// if closed will also return YES !!
- (BOOL) shouldClose                         MULLE_OBJC_THREADSAFE_METHOD;

// won't get retained!
- (void) addToRenderDelegates:(id <UIWindowRenderDelegate>) delegate;
- (void) removeFromRenderDelegates:(id <UIWindowRenderDelegate>) delegate;

- (void) addToViewControllers:(UIViewController *) controller;
- (void) removeFromViewControllers:(UIViewController *) controller;


// these can only get called from the main thread (by UIApplication)
- (void) applicationDidAddWindow:(UIApplication *) app      MULLE_OBJC_THREADSAFE_METHOD;
- (void) applicationDidRemoveWindow:(UIApplication *) app   MULLE_OBJC_THREADSAFE_METHOD;

- (BOOL) isWindowPlane:(UIView *) view;

// for performance monitoring
- (struct mulle_structqueue *) extractProfileQueue;


@end


//
// UIWindow will forward to _OSWindow, so it implements UIOSWindow
//
@interface UIWindow( Forward) <UIOSWindow>

//
// use this if you want to send glfw C commands to the window
// see UIOSWindow protocol in MulleUIBase for more
//
- (void *) os_window          MULLE_OBJC_THREADSAFE_METHOD;

@end


@interface UIWindow( Customize)

+ (Class) viewClass;           // default UIView
+ (Class) windowPlaneClass;    // default UIWindowPlane

@end


@interface UIWindow( OSFuture)

+ (Class) osWindowClass;
+ (Class) osGraphicsContextClass;
+ (NSUInteger) osGraphicsHints;

@end


@interface UIWindow( Dump)

- (void) dump;
- (void) dumpWithIndent:(NSUInteger) indent
                   FILE:(FILE *) fp;

@end


enum MulleWindowProfileEntryMode
{
   MulleWindowProfileEntryFunctionIsAddress   = 0x1,
   MulleWindowProfileEntryStacktraceIsCString = 0x2,
   MulleWindowProfileEntryFreeFunction        = 0x4,
   MulleWindowProfileEntryFreeStacktrace      = 0x8
};


enum MulleWindowProfileEntryAction
{
   MulleWindowProfileEntryBegin  = 0x1,
   MulleWindowProfileEntrySync   = 0x2,
   MulleWindowProfileEntryEnd    = 0x0
};



// currently 64 bytes on 64
// The idea behind this struct is to generate tracer information for display
// in a graphical debugger (like Firefox or Hotspot or Renderdoc).
// Work in progress...
//
struct MulleWindowProfileEntry
{
   mulle_absolutetime_t  timestamp;
   char                  *function;
   void                  *stacktrace;
   union
   {
      struct
      {
         uint8_t         action;  // begin=1, sync=2, end=0
         uint8_t         mode;
      } flags;
      uintptr_t          spacer;
   };
};


static inline void
   MulleWindowProfileEntryInitDefault( struct MulleWindowProfileEntry *entry,
                                       char *function,
                                       int action)
{
   if( entry)
   {
      entry->timestamp    = mulle_absolutetime_now();
      entry->function     = function;
      entry->stacktrace   = NULL;
      entry->spacer       = 0;
      entry->flags.action = action;
   }
}


static inline void
   MulleWindowProfileEntryDone( struct MulleWindowProfileEntry *entry)
{
   if( entry)
   {
      if( entry->flags.mode & MulleWindowProfileEntryFreeFunction)
         mulle_free( entry->function);
      if( entry->flags.mode & MulleWindowProfileEntryFreeStacktrace)
         mulle_free( entry->stacktrace);
   }
}


#define _MulleWindowProfileAction( self, s, action)                   \
   do                                                                 \
   {                                                                  \
      if( self->_profileQueue)                                        \
      {                                                               \
         struct MulleWindowProfileEntry   entry;                      \
                                                                      \
         MulleWindowProfileEntryInitDefault( &entry, (s), (action));  \
         [_windowPropertyLock lock];                                  \
         mulle_structqueue_push( self->_profileQueue, &entry);        \
         [_windowPropertyLock unlock];                                \
      }                                                               \
   }                                                                  \
   while( 0)


#define MulleWindowProfileBegin()  \
    _MulleWindowProfileAction( self, (char *) __FUNCTION__, MulleWindowProfileEntryBegin)

#define MulleWindowProfileEnd()    \
   _MulleWindowProfileAction( self, (char *) __FUNCTION__, MulleWindowProfileEntryEnd)

#define MulleWindowProfileSync()   \
   _MulleWindowProfileAction( self, "*** sync ***", MulleWindowProfileEntrySync)


MULLE_UI_CORE_EXTERN_GLOBAL
void   UIWindowDestroyProfileQueue( struct mulle_structqueue *queue);
