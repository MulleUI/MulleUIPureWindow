#import "import.h"


// A "frame" is the timespan taken to fill the contents of the "framebuffer"
// that will then be displayed by swapBuffers. It doesn't contain the time
// needed to handle events.
//
// In UIWindow a "frame" usually does, "layout", "animation", "rendering" in
// this sequence.
//


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
   UIWindowBackingStoreRetainedOnMainThread, // useful for debugging only
   UIWindowBackingStoreRetained,  // safe default
   UIWindowBackingStoreVolatile   // draws to "volatile" window framebuffer
                                  // still dual buffered but needs fast code
                                  // to avoid ugliness during resize
                                  // you can use a UIWindowStyleSingleBuffer
                                  // to get single buffered...
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
// value to use if styleMask is 0
#define UIWindowStyleMaskDefault \
   (UIWindowStyleRetained\
    |UIWindowStyleResizable\
    |UIWindowStyleEdgeAntialias \
    |UIWindowStyleStencilStrokes\
    |UIWindowOpenGLLibraryFallback)


#define ui_window_pointer_fifo                mulle__pointerfifo128

#define ui_window_pointer_fifo_init           _mulle__pointerfifo128_init
#define ui_window_pointer_fifo_done           _mulle__pointerfifo128_done
#define ui_window_pointer_fifo_write          _mulle__pointerfifo128_write
#define ui_window_pointer_fifo_read_barrier   _mulle__pointerfifo128_read_barrier


typedef NS_OPTIONS( NSUInteger, UIWindowFramePhase)
{
   UIWindowLayoutPhase    = 0x1,
   UIWindowAnimationPhase = 0x2,
   UIWindowRenderPhase    = 0x4
};

#define UIWindowFrameAllPhases   (~0)


// mulle addition
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


typedef NS_OPTIONS( NSUInteger, UIWindowNeedsDisplay)
{
   UIWindowNeedsRedraw    = 0x1,   // needs immediate attention
   UIWindowNeedsLayout    = 0x2,   // needs immediate attention, forces redraw
   UIWindowNeedsAnimation = 0x4    // needs attention according to animationRate
};


typedef NS_OPTIONS( NSUInteger, UIWindowPropertyChange)
{
   UIWindowPropertyChangeFrame  = 0x1,
   UIWindowPropertyChangeTitle  = 0x2,
   UIWindowPropertyChangeCursor = 0x4
//   UIWindowPropertyChangeIcon  = 0x4
};

typedef NS_OPTIONS( NSUInteger, UIWindowDebugBit)
{
   UIWindowDrawFramebufferIdRect = 0x1
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
@interface UIWindow : UIView <MulleUIResourceMap>
{
// these ivars are mainthread only

   id <UIOSWindow>                 _offscreenOSWindow;   // our drawing Window if buffered

   id <UIGraphicsContext>          _context;
   id <UIGraphicsContext>          _offscreenContext;

   // TODO: full "beauty" is only needed for offscreen or ?
   NSUInteger                      _styleMask;
   NSUInteger                      _offscreenStyleMask;

   // need to setNeedsDisplay to get the renderer out of the lock and start
   // the render. The _contextLock still needs to be observed when
   // attempting to modify the view hierarchy ?
   BOOL                            _isLayouting;
   BOOL                            _isResizing;       // obsolete yet in use (?) in OneFrame
   BOOL                            _shouldClose;      // obsolete yet in use (?) in OneFrame
   NSInteger                       _oldSwapInterval;
   id <UILayer>                    _lastOffscreenFramebuffer;

   UIApplication                   *_application;

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
   struct mulle_pointerarray       _delegateViews;    // views with need willRender: sent
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

   // usually if we are buffered, we have a windowThread to do everything
   NSThread                        *_windowThread;
   NSConditionLock                 *_windowThreadLock;
   mulle_absolutetime_t            _lastWindowThreadTimestamp;

   // for properties set by events, and observable properties that are
   // written to by the window thread and read by the main thread and pushed
   // into OS_Window, we need a lock (if the changes can't be done atomically)
   NSLock                          *_windowPropertyLock;

   struct MulleClickDragDifferentiator     _clickOrDrag;
   id <UIResponder>                 _firstResponder;

   // 0: unchecked 1:found -1:non found
   int                              _initialFirstResponderState; 

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
   struct mulle__pointerset        _layoutedViews;    // views with need willRender: sent

// these values are only accessible to the main thread
@private
   mulle_absolutetime_t            _lastDidProcessEventsTimestamp;

   struct UIWindowFrameStatistics  _mainThreadStatistics;

   // only used to create UIEventTypeWindowFramebufferGeometry events
   struct CGWindowInfo             _previousWindowInfo;
   struct CGWindowInfo             _currentWindowInfo;
}

@property( retain, readonly) id <UIOSWindow>         OSWindow;

// only available during rendering use for layout code if you need
// to do font measurements, will abort if nil
@property( assign, readonly) id <UIGraphicsContext>  renderGraphicsContext;

@property( assign) BOOL                            debugEnabled;

@property( retain) id                              userInfo;
// TODO: pasteboard is a global resource and is on Application ?
@property( retain) UIPasteboard                    *pasteboard;

// get a cursor from UIApplication cursorWithStandardShape:
// NULL is the default arrow. this is the current cursor
@property( assign) UICursor                        *cursor;

// cursor to use, when no cursor is set 
@property( assign) UICursor                        *defaultCursor;

@property( assign, getter=areTrackingAreasEnabled) BOOL   trackingAreasEnabled;

@property( assign, readonly) struct UIInputState   inputState;
@property( dynamic, assign, readonly) CGPoint      mouseLocation;
@property( dynamic, assign, readonly) NSUInteger   buttonStates;
@property( dynamic, assign, readonly) NSUInteger   keyModifiers;

// used for MulleUIPerformance
@property( assign) id <UIWindowFrameDelegate>      frameDelegate;

// default is 1.0/60.0. Only for use in async configuration
@property( assign) mulle_relativetime_t            asyncAnimationRate;

@property( assign) NSUInteger                      swapInterval;


@property char                                     *titleUTF8String;

// default is UIWindowBackingStoreRetained, this is more expensive. If your
// event/drawing code is very fast (within a frame), you can get by with
// UIWindowBackingStoreVolatile
@property( assign, readonly) UIWindowBackingStoreType   backingStore;

// how the backing store image is placed into the framebuffer
// default is CGContentModeScaleToFill, but CGContentModeTopLeft or
// CGContentModeCenterPoint can be better for non-resizable content
// Accessed my main thread, therefore both are lock protected
@property( assign) CGContentMode                    refreshContentMode;
@property( assign) NSUInteger                       backgroundHexColor;

// what's the difference to alpha ? An alpha value of 1.0 does not mean
// that all pixels are opaque. This guarantees it. The main benefit of
// setting this flag is, that you can avoid clearing the framebuffer
// color bits, which might save bandwidth
@property( getter=isOpaque) BOOL                    opaque;

// context switches are expensive, try to minimize with this setting
@property( assign) BOOL                             keepOSGraphicsContext;

// Rendercallbacks. If the renderer is in its own thread, then all these
//                  callbacks will appear on the render thread. This thread
//                  will possibly conflict with events from the main thread.
//

// This is the "master" callback, if you override this, none of the other
// render callbacks and delegate methods will be invoked (except 
// didRenderFrameCallback). So in general keep it as 
// UIWindowDefaultRawFrameCallback. DisplayBits are UIWindowNeedsRedraw et.al.
// Returns YES, if any animations were run.
//
// Will be usually either  or 
//
@property BOOL   (*rawFrameCallback)( UIWindow *window,
                                      id <UIGraphicsContext> context,
                                      struct CGFrameInfo *frameInfo,
                                      NSUInteger displayBits);

// will be called immediately after rawFrameCallback, before swapBuffers
@property BOOL   (*didRenderFrameCallback)( UIWindow *window,
                                            id <UIGraphicsContext> context,
                                            struct CGFrameInfo *frameInfo,
                                            BOOL didAnimate);

//
// If this callback is set, then UIViews and CAAnimations are ignored and this 
// callback will be used for drawing, the context is already setup for 
// rendering.  UIWindowFrameDelegate methods will be sent but other callbacks
// won't. Return '1' if you are animating and need to break out of async for 
// a while.
//
@property int   (*frameCallback)( UIWindow *window,
                                  id <UIGraphicsContext> context,
                                  struct CGFrameInfo *frameInfo);

// These callbacks will be called in this sequence for every frame.
// It should be obvious, that you don't do any system calls in these callbacks
// and finish ASAP. The mulle_absolutetime_t is the time the render started it will
// be the same through all callbacks.
//
@property void   (*willLayoutCallback)( UIWindow *window,
                                        id <UIGraphicsContext> context,
                                        struct CGFrameInfo *info);
@property void   (*didLayoutCallback)( UIWindow *window,
                                       id <UIGraphicsContext> context,
                                       struct CGFrameInfo *info);
@property void   (*didCreateRenderQueueCallback)( UIWindow *window,
                                                  id <UIGraphicsContext> context,
                                                  struct CGFrameInfo *info);

//
// stage #0: after _preLayoutAnimator
// stage #1: after _postLayoutAnimator
// stage #2: after CALayer "privat" animations
// return YES if animations happened (and a redraw should happen)
@property BOOL   (*didAnimateCallback)( UIWindow *window,
                                        id <UIGraphicsContext> context,
                                        struct CGFrameInfo *info,
                                        NSInteger stage);

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

//
// This can be useful to setup stuff for the next frame. You can't draw here
// though.
//
@property void   (*didSwapBuffersCallback)( UIWindow *window);


// low level event taps, generally not used. Get UIEvents in your UIView
// subclass (otherwise 50% of MulleUI is not really used)
@property UIWindowEvent  *(*windowEventCallback)( UIWindow *window, UIWindowEvent *event);

// the resize plane is shown, when the window is resizing
// the other planes are then not shown

@property( readonly, assign) UIWindowPlane   *alertPlane;
@property( readonly, assign) UIWindowPlane   *dragAndDropPlane;
@property( readonly, assign) UIWindowPlane   *menuPlane;
@property( readonly, assign) UIWindowPlane   *toolTipPlane;
@property( readonly, assign) UIWindowPlane   *contentPlane;

@property( assign) id <UIResponder>          initialFirstResponder;

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

// typically that's a GLFWOSWindow
- (instancetype) initWithOSWindow:(id <UIOSWindow>) window
                offscreenOSWindow:(id <UIOSWindow>) offscreenWindow;

- (instancetype) initWithFrame:(CGRect) frame;
// default visible: closable, non-resizable, non-maximizable
- (instancetype) initWithFrame:(CGRect) frame
               titleUTF8String:(char *) title
                     styleMask:(NSUInteger) styleMask;

// does not deal with focus of events
//- (void) show;
//- (void) hide;

//
// GLFWOSWindow also has a flag like this, but UIWindow has one itself
// in  buffered configuration the currently "ready" framebuffer is
// used to refresh. In unbuffered this will do a display and then a swap.
// You usually do a [UIEvent sendEmptyEvent] afterwards to preempt the
// UIApplication event wait and to retrigger a refresh
- (void) setNeedsRefresh;
- (void) setNeedsRefresh:(BOOL) value;
- (BOOL) needsRefresh;
- (BOOL) needsRefreshClearIfSet;

//
// needs Display is a combination of needsLayout and needsRedraw, needsAnimation
// bits defined in UIWindowNeedsDisplay
//
- (void) setNeedsDisplay;  // sets all bits
- (void) setNeedsDisplayBit:(NSUInteger) value;
- (NSUInteger) needsDisplay;
- (NSUInteger) needsDisplayClearIfSet;

// force re-layout on next render, setting this flag does not affect other
// flags
- (void) setNeedsLayout;
- (BOOL) needsLayout;

// this flag means, that the there are animations running
- (void) setNeedsAnimation;
- (BOOL) needsAnimation;

// this flag means, that the UIView hierarchy needs to be drawn into
// the framebuffer
- (void) setNeedsRedraw;
- (BOOL) needsRedraw;


- (BOOL) isWindowThread;

- (CGFloat) pixelRatio;
- (struct MulleIntegerSize) framebufferSize;

- (CAAnimator *) preLayoutAnimator;
- (CAAnimator *) postLayoutAnimator;

- (void) requestClose;

// if closed will also return YES !!
- (BOOL) shouldClose;

- (void) addToDelegateViews:(UIView *) view;
- (void) removeFromDelegateViews:(UIView *) view;

- (void) applicationDidAddWindow:(UIApplication *) app;
- (void) applicationDidRemoveWindow:(UIApplication *) app;

- (BOOL) isWindowPlane:(UIView *) view;

@end


//
// UIWindow will forward to _OSWindow, so it implements UIOSWindow
//
@interface UIWindow( Forward) <UIOSWindow>

//
// use this if you want to send glfw C commands to the window
// see UIOSWindow protocol in MulleUIBase for more
//
- (void *) os_window;

@end


@interface UIWindow( OSFuture)

+ (Class) osWindowClass;
+ (Class) osGraphicsContextClass;
+ (NSUInteger) osGraphicsHints;

@end


@interface UIWindow( Dump)

- (void) dump;

@end

