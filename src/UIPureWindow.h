#import "import.h"

// MEMO: technically MulleUIPureWindow could be part of MulleUIApplication.
//       It's a separate project, because of size and the smaller testing
//       scope.


// A "frame" is the timespan taken to fill the contents of the "framebuffer"
// that will then be displayed by swapBuffers. It doesn't contain the time
// needed to handle events.
#define MULLE_UI_PURE_WINDOW_THREAD_ONLY    MULLE_OBJC_THREADSAFE_METHOD

@class GLFWOSWindow;  // move to private some time
@class UIPasteboard;


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
// MEMO: We can't forward declare UIWindow, because this would make the
//       UIWindow a protocolclass
//
PROTOCOLCLASS_INTERFACE0( UIWindowFrameDelegate)

@optional
- (void) window:(id) window
 willBeginFrame:(struct CGFrameInfo *) info
graphicsContext:(id <UIGraphicsContext>) context;

- (void) window:(id) window
    didEndFrame:(struct CGFrameInfo *) info
graphicsContext:(id <UIGraphicsContext>) context;

- (void)  window:(id) window
   willDrawFrame:(struct CGFrameInfo *) info
 graphicsContext:(id <UIGraphicsContext>) context;

- (void)  window:(id) window
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
@interface UIPureWindow : MulleObject < MulleUIResourceMap>
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
   UIMouseTrackingEvent            *_reusableTrackingEvent;
   
@protected
   //
   // 8Khz at 60fps = 133 events, 256 should be ample
   // The queue is single consumer/single producer thread. The producer is
   // ALWAYS the main thread. 
   //
   struct mulle_map                _invocationQueueMap;
   struct MulleUIResourceStorage   _resourceStorage;
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
   struct MulleClickDragDifferentiator     _clickOrDrag;
   id <UIResponder>                _firstResponder;
   id <UIResponder>                _responder;     // typically root UIView

   // 0: unchecked 1:found -1:non found
   int                             _initialFirstResponderState;


// atomic variables accessed by both threads
@protected
   // window was resized, so we need an immediate render
   mulle_atomic_pointer_t          _needsDisplay;
   // we have a fresh framebuffer drawn, pls2swap
   mulle_atomic_pointer_t          _needsRefresh;

   mulle_atomic_pointer_t          _propertyChanges;

   NSUInteger                      _cursorGenerationCount;

   // these values are only accessible to the window thread
@protected
   struct UIWindowFrameStatistics  _windowThreadStatistics;


// these values are only accessible to the main thread
@protected
   mulle_absolutetime_t            _lastDidProcessEventsTimestamp;

   struct UIWindowFrameStatistics  _mainThreadStatistics;

   // the profile entries are 64 bytes, at 60 Hz thats 3840 bytes, so one hour
   // of tracing consumes 13,824,000 bytes 13 MB (not caring) :)
   // activate with special window flag
   struct mulle_structqueue        *_profileQueue;

   // only used to create UIEventTypeWindowFramebufferGeometry events
   struct CGWindowInfo             _previousWindowInfo;
}

//
// On Wayland, you won't be able to move/resize the window via frame.
//
@property( assign)           CGRect                frame;        // os_windowFrame of osWindow
@property( assign, readonly) CGRect                bounds;       // os_framebufferSize (of the offscreenWindow, if exists)
                                                    // bounds.origin is always 0/0

@property( assign) NSUInteger                      debuggingFlags      MULLE_OBJC_THREADSAFE_PROPERTY;



@property( retain, readonly) id <UIOSWindow>       OSWindow            MULLE_OBJC_THREADSAFE_PROPERTY;

// only available during rendering use for layout code if you need
// to do font measurements, will abort if nil
@property( assign, readonly) id <UIGraphicsContext>  renderGraphicsContext;

@property( retain) id                              userInfo;


// get a cursor from UIApplication cursorWithStandardShape:
// NULL is the default arrow. this is the current cursor
@property( assign) UICursor                        *cursor              MULLE_OBJC_THREADSAFE_PROPERTY;

// cursor to use, when no cursor is set 
@property( assign) UICursor                        *defaultCursor;

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


// Rendercallbacks. If the renderer is in its own thread, then all these
//                  callbacks will appear on the render thread. This thread
//                  will possibly conflict with events from the main thread.
//

// This is the "master" callback, if you override this, none of the other
// render callbacks and delegate methods will be invoked (except 
// -willRenderFrameCallback and -didRenderFrameCallback). So in general keep it
// as UIWindowDefaultRawFrameCallback. DisplayBits are
// UIWindowDisplayNeedsRedraw et.al.
// Returns YES, if any animations were run.
//
// Will be usually either  or 
//
@property UIWindowDisplayBits   (*rawFrameCallback)( UIPureWindow *window,
                                                     id <UIGraphicsContext> context,
                                                     struct CGFrameInfo *frameInfo,
                                                     UIWindowDisplayBits displayBits);

// will be called immediately before rawFrameCallback, you should return
// displayBits intact, unless you know better. The framebuffer will not be
// bound yet, but the graphics context is activated. Don't draw anything
// here yet.
@property UIWindowDisplayBits   (*willRenderFrameCallback)( UIPureWindow *window,
                                                            id <UIGraphicsContext> context,
                                                            struct CGFrameInfo *frameInfo,
                                                            UIWindowDisplayBits displayBits);

// will be called immediately after rawFrameCallback, before swapBuffers
@property UIWindowDisplayBits   (*didRenderFrameCallback)( UIPureWindow *window,
                                                           id <UIGraphicsContext> context,
                                                           struct CGFrameInfo *frameInfo,
                                                           UIWindowDisplayBits displayBits);

//
// This is useful to add custom drawing stuff on the bottom.
// If you return NO, it's assumed that you cleared the framebuffer yourself.
// Remember that nanovg needs the stencilbuffer cleared.
@property BOOL  (*willClearCallback)( UIPureWindow *window,
                                      id <UIGraphicsContext> context,
                                      struct CGFrameInfo *info);

//
// If this callback is set, then UIViews and CAAnimations are ignored and this 
// callback will be used for drawing, the context is already setup for 
// rendering.  UIWindowFrameDelegate methods will be sent but other callbacks
// won't. Return '1' if you are animating and need to break out of async for 
// a while.
//
@property UIWindowDisplayBits (*frameCallback)( UIPureWindow *window,
                                                id <UIGraphicsContext> context,
                                                struct CGFrameInfo *frameInfo,
                                                UIWindowDisplayBits displayBits);

//
// This can be useful to setup stuff for the next frame. You can't draw here
// though.
//
@property void   (*didSwapBuffersCallback)( UIPureWindow *window, BOOL immediately);


// these two callbacks will only be called in UIWindowRetained mode, where
// a drawing thread is active. The intention of the callback is to allow
// "hacky" global variables that are thread unsafe to be attached/detached from
// the thread with -mulleGainAccess/-mulleRelinquishAccess (see candycrash
// example). Both callbacks will be executed in the drawing thread.
//
@property void   (*willStartDrawingInThreadCallback)( UIPureWindow *window,
                                                      NSThread *thread);
@property void   (*didStopDrawingInThreadCallback)( UIPureWindow *window,
                                                    NSThread *thread);

@property( readonly, assign) UIApplication    *application;

@property( assign) id <UIResponder>           initialFirstResponder;

// these are all "assign" only, but they WILL get called with
// gainAccess and relinquishAccess
@property( assign) id <UIResponder>           firstResponder;
@property( assign) id <UIResponder>           responder;


+ (instancetype) windowWithFrame:(CGRect) frame;

+ (instancetype) windowWithFrame:(CGRect) frame
                 titleUTF8String:(char *) title
                       styleMask:(NSUInteger) styleMask;

// typically that's a GLFWOSWindow, this method does not create a contentView!!
- (instancetype) initWithOSWindow:(id <UIOSWindow>) window
                offscreenOSWindow:(id <UIOSWindow>) offscreenWindow;

// default visible: closable, non-resizable, non-maximizable
- (instancetype) initWithFrame:(CGRect) frame
               titleUTF8String:(char *) title
                     styleMask:(NSUInteger) styleMask;

// calls initWithFrame:titleUTF8String:styleMask: with some "Demo" defaults
- (instancetype) initWithFrame:(CGRect) frame;



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

//
// needs Display is a combination of needsLayout and needsRedraw, needsAnimation
// bits defined in UIWindowDisplayBits
//
// - (void) setNeedsDisplayBit:(UIWindowDisplayBit) value;  // can't zero
- (UIWindowDisplayBits) needsDisplayBitsClearIfSet        MULLE_OBJC_THREADSAFE_METHOD;

// sets more than just one bit, can also zero
- (void) setNeedsDisplayBits:(UIWindowDisplayBits) value  MULLE_OBJC_THREADSAFE_METHOD;

// sets only one bit
- (void) setNeedsDisplayBit:(UIWindowDisplayBits) value;

// legacy compatibility
- (void) setNeedsDisplay                     MULLE_OBJC_THREADSAFE_METHOD;  // sets all bits
- (UIWindowDisplayBits) needsDisplay         MULLE_OBJC_THREADSAFE_METHOD;

- (BOOL) receivesMouseMotionEvents;

- (BOOL) isWindowThread                      MULLE_OBJC_THREADSAFE_METHOD;

- (CGFloat) pixelRatio                       MULLE_OBJC_THREADSAFE_METHOD;
- (CGPixelSize) framebufferSize              MULLE_OBJC_THREADSAFE_METHOD;

- (void) requestClose;

// if closed will also return YES !!
- (BOOL) shouldClose                         MULLE_OBJC_THREADSAFE_METHOD;

// these can only get called from the main thread (by UIApplication)
- (void) applicationDidAddWindow:(UIApplication *) app      MULLE_OBJC_THREADSAFE_METHOD;
- (void) applicationDidRemoveWindow:(UIApplication *) app   MULLE_OBJC_THREADSAFE_METHOD;

// for performance monitoring
- (struct mulle_structqueue *) extractProfileQueue;

@end


//
// UIWindow will forward to _OSWindow, so it implements UIOSWindow
//
@interface UIPureWindow( Forward) <UIOSWindow>

//
// use this if you want to send glfw C commands to the window
// see UIOSWindow protocol in MulleUIBase for more
//
- (void *) os_window          MULLE_OBJC_THREADSAFE_METHOD;

- (char *) pasteboardCString;
- (void) setPasteboardCString:(char *) s;

@end


@interface UIPureWindow( OSFuture)

+ (Class) osWindowClass;
+ (Class) osGraphicsContextClass;
+ (NSUInteger) osGraphicsHints;

@end


@interface UIPureWindow( Dump)

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
