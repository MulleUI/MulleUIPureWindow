# MulleUIPureWindow Library Documentation for AI
<!-- Keywords: window, framebuffer, threading, events, rendering -->

## 1. Introduction & Purpose

**MulleUIPureWindow** provides window management with framebuffer and graphics context support. It implements a "retained" rendering mode using separate threads for drawing and display, enabling flicker-free updates during window operations. The library handles window lifecycle, event processing, and responder chain management without dependencies on UIView hierarchies, layout systems, or animations. It is a foundational component of the MulleUI framework, sitting above MulleUIApplication and below higher-level UI components like UIWindow.

Key features:
- **Multi-threaded rendering**: Offscreen framebuffer drawing in separate thread with main thread display
- **Event handling**: Complete mouse, keyboard, and window event processing with responder chain support
- **Flexible backing stores**: Volatile (direct), retained on main thread (debug), or retained (production default)
- **Timer and invocation queues**: Built-in support for scheduled operations and background processing
- **Graphics context abstraction**: Works with any graphics context implementing UIGraphicsContext protocol

## 2. Key Concepts & Design Philosophy

### Threading Model
MulleUIPureWindow implements three backing store modes:
- **UIWindowBackingStoreVolatile**: Single-threaded, draws directly to window framebuffer (fast code required)
- **UIWindowBackingStoreRetainedOnMainThread**: Single-threaded retained mode (debugging only)
- **UIWindowBackingStoreRetained**: Multi-threaded default with offscreen buffers and dedicated window thread

In retained mode, a separate window thread handles:
- Event processing from the OS
- Timer firing
- Rendering into offscreen framebuffer
- Layout and animation callbacks

The main thread handles:
- Event dispatching from UIApplication
- Window property updates (title, cursor, frame)
- Buffer swapping and refresh requests

### Synchronization Primitives
- **Atomic flags**: `_needsDisplay` (render request), `_needsRefresh` (swap request), `_propertyChanges`
- **Lock-free FIFOs**: 128-element pointer queues for events and timers (single producer/single consumer)
- **Property lock**: NSLock for window properties accessed from both threads
- **Window thread lock**: NSConditionLock for thread lifecycle management

### Frame and Refresh Distinction
- **Frame**: The rendering cycle (layout, animation, drawing) producing a framebuffer
- **Refresh**: Displaying the framebuffer to the visible window (swap buffers)
- Frame statistics track rendering performance to adapt frame rates dynamically

### Responder Chain
Windows implement UIResponder protocol and maintain firstResponder tracking. Events propagate through the responder chain starting from firstResponder, enabling keyboard focus and event bubbling without UIView dependencies.

### Resource Management
Windows support MulleUIResourceMap protocol for storing context-specific resources. Invocation queues can be created and managed per-name for background operations.

## 3. Core API & Data Structures

### 3.1. `UIPureWindow.h` - Main Window Class

#### `@interface UIPureWindow : MulleObject <MulleUIResourceMap>`
**Purpose:** Core window object managing framebuffer, graphics context, events, and threading.

**Key Properties:**

Window Geometry:
- `@property CGRect frame` - OS window frame (position and size)
- `@property(readonly) CGRect bounds` - Framebuffer size (origin always 0,0)
- `- (CGPixelSize) framebufferSize` - Pixel dimensions of framebuffer
- `- (CGFloat) pixelRatio` - DPI scaling factor

Graphics Context:
- `@property(readonly) id<UIGraphicsContext> renderGraphicsContext` - Context available during rendering only
- `@property(readonly) id<UIOSWindow> OSWindow` - Underlying OS window object

Window Appearance:
- `@property char *titleUTF8String` - Window title (thread-safe)
- `@property UICursor *cursor` - Current cursor (thread-safe)
- `@property UICursor *defaultCursor` - Fallback cursor when none set
- `@property CGHexColor backgroundHexColor` - Background color (thread-safe)
- `@property BOOL opaque` - If YES, framebuffer doesn't need color clearing

Rendering Configuration:
- `@property(readonly) UIWindowBackingStoreType backingStore` - Threading mode
- `@property CGContentMode refreshContentMode` - How backing store scales to window (thread-safe)
- `@property UIGraphicsContextState keepOSGraphicsContextActive` - Minimize context switches (thread-safe)
- `@property NSUInteger swapInterval` - VSYNC interval (0=unlimited, 1=60Hz, etc.)
- `@property mulle_relativetime_t asyncAnimationRate` - Animation frame rate (default 1.0/60.0)

Display Flags:
- `@property NSUInteger debuggingFlags` - Debug visualization bits (thread-safe)
- `@property NSUInteger maxRenderedFrames` - Stop after N frames (debugging)
- `@property NSUInteger startTraceFrames` - Begin profiling at frame N

Event Handling:
- `@property NSUInteger discardEventsMask` - Bitmask of event types to ignore (thread-safe)
- `@property struct UIInputState polledInputState` - Current input state (thread-safe, requires UIWindowStyleInputPolling)
- `@property(readonly) struct UIInputState eventInputState` - Input state from last event
- `@property(readonly) struct UIInputState previousEventInputState` - Previous event input state
- `@property(readonly) CGPoint mouseLocation` - Current mouse position
- `@property(readonly) NSUInteger buttonStates` - Mouse button states
- `@property(readonly) NSUInteger keyModifiers` - Keyboard modifier keys

Responder Chain:
- `@property(assign) id<UIResponder> initialFirstResponder` - First responder to set on startup
- `@property(assign) id<UIResponder> firstResponder` - Current keyboard focus
- `@property(assign) id<UIResponder> responder` - Root responder (typically root view)

Delegation:
- `@property(retain) id<UIWindowFrameDelegate> frameDelegate` - Frame lifecycle callbacks
- `@property id userInfo` - Application-specific data

**Lifecycle Functions:**

Creation:
```c
+ (instancetype) windowWithFrame:(CGRect) frame;
+ (instancetype) windowWithFrame:(CGRect) frame
                 titleUTF8String:(char *) title;
+ (instancetype) windowWithFrame:(CGRect) frame
                 titleUTF8String:(char *) title
                       styleMask:(NSUInteger) styleMask;

- (instancetype) initWithFrame:(CGRect) frame
               titleUTF8String:(char *) title
                     styleMask:(NSUInteger) styleMask;

// Advanced: provide custom OS windows
- (instancetype) initWithOSWindow:(id<UIOSWindow>) window
                offscreenOSWindow:(id<UIOSWindow>) offscreenWindow;
```

Style masks combine flags:
- `UIWindowStyleRetained` - Use offscreen rendering thread
- `UIWindowStyleResizable` - Allow user resizing
- `UIWindowStylePlanes` - Use color planes
- `UIWindowStyleAntiAlias` - Enable antialiasing
- `UIWindowStyleStencilStrokes` - Use stencil buffer for strokes
- `UIWindowStyleClearType` - Enable subpixel rendering
- `UIWindowOpenGLLibraryFallback` - Fallback to older OpenGL
- `UIWindowStyleInputPolling` - Enable polled mouse state
- `UIWindowStyleMaskDefault` - Recommended defaults (includes Retained)
- `UIWindowStyleMaskNonRetained` - Default without retained mode

**Core Operations:**

Display and Refresh (thread-safe):
```c
- (void) setNeedsDisplay;                              // Request redraw (all bits)
- (void) setNeedsDisplayBit:(UIWindowDisplayBits) bit; // Request specific phase
- (void) setNeedsDisplayBits:(UIWindowDisplayBits) bits; // Set multiple bits
- (UIWindowDisplayBits) needsDisplay;                  // Query display bits
- (UIWindowDisplayBits) needsDisplayBitsClearIfSet;    // Atomic read and clear

- (void) setNeedsRefresh;                              // Request buffer swap
- (void) setNeedsRefresh:(BOOL) value;
- (BOOL) needsRefresh;
- (BOOL) needsRefreshClearIfSet;                       // Atomic read and clear
```

Display bits (can OR together):
- `UIWindowDisplayNeedsLayout` - Run layout pass
- `UIWindowDisplayNeedsAnimation` - Run animation pass
- `UIWindowDisplayNeedsRedraw` - Run drawing pass

Window State:
```c
- (BOOL) isWindowThread;                               // Are we on window thread?
- (void) requestClose;                                 // Request window close
- (BOOL) shouldClose;                                  // Should window close?
```

Application Integration:
```c
- (void) applicationDidAddWindow:(UIApplication *) app;    // Called by UIApplication
- (void) applicationDidRemoveWindow:(UIApplication *) app; // Called by UIApplication
- (UIApplication *) application;                           // Get owning application
```

**Render Callbacks:**

The window uses function pointers for maximum performance. All callbacks execute on the window thread in retained mode.

```c
// Master callback - controls entire frame rendering
@property UIWindowDisplayBits (*rawFrameCallback)(
   UIPureWindow *window,
   id<UIGraphicsContext> context,
   struct CGFrameInfo *frameInfo,
   UIWindowDisplayBits displayBits);

// Pre-render callback - graphics context activated, framebuffer not bound yet
@property UIWindowDisplayBits (*willRenderFrameCallback)(
   UIPureWindow *window,
   id<UIGraphicsContext> context,
   struct CGFrameInfo *frameInfo,
   UIWindowDisplayBits displayBits);

// Post-render callback - called after rawFrameCallback, before swap
@property UIWindowDisplayBits (*didRenderFrameCallback)(
   UIPureWindow *window,
   id<UIGraphicsContext> context,
   struct CGFrameInfo *frameInfo,
   UIWindowDisplayBits displayBits);

// Application drawing callback - if set, replaces UIView/animation handling
@property UIWindowDisplayBits (*frameCallback)(
   UIPureWindow *window,
   id<UIGraphicsContext> context,
   struct CGFrameInfo *frameInfo,
   UIWindowDisplayBits displayBits);

// Pre-clear callback - return NO to skip automatic framebuffer clearing
@property BOOL (*willClearCallback)(
   UIPureWindow *window,
   id<UIGraphicsContext> context,
   struct CGFrameInfo *info);

// Post-swap callback - called after buffer swap
@property void (*didSwapBuffersCallback)(
   UIPureWindow *window,
   BOOL immediately);

// Thread lifecycle callbacks (retained mode only)
@property void (*willStartDrawingInThreadCallback)(
   UIPureWindow *window,
   NSThread *thread);
@property void (*didStopDrawingInThreadCallback)(
   UIPureWindow *window,
   NSThread *thread);
```

Default callbacks:
- `UIPureWindowDefaultRawFrameCallback()` - Implements standard frame rendering
- `UIPureWindowDefaultWillRenderFrameCallback()` - No-op, returns displayBits unchanged
- `UIPureWindowDefaultDidRenderFrameCallback()` - No-op, returns displayBits unchanged

**Inspection Functions:**
```c
- (BOOL) receivesMouseMotionEvents;
- (struct mulle_structqueue *) extractProfileQueue;    // Get performance trace data
```

#### `struct CGFrameInfo`
**Purpose:** Passed to all render callbacks, contains timing and frame metadata.

**Key Fields:**
```c
struct CGFrameInfo
{
   mulle_absolutetime_t   timestamp;        // Frame start time
   mulle_relativetime_t   elapsed;          // Time since last frame
   NSUInteger             numberOfFrames;   // Total frames rendered
   // Additional timing and state fields...
};
```

#### `struct UIWindowFrameStatistics`
**Purpose:** Tracks frame timing for performance adaptation.

**Key Fields:**
```c
struct UIWindowFrameStatistics
{
   mulle_absolutetime_t   lastBeginTimestamp;
   mulle_absolutetime_t   lastEndTimestamp;
   mulle_relativetime_t   elapsedHistory[4];           // Rolling history
   NSUInteger             elapsedHistoryIndex;
   mulle_relativetime_t   avgElapsedHistory;           // Average frame time
};
```

**Functions:**
```c
void UIWindowDisplayFrameStatisticsUpdate(
   struct UIWindowFrameStatistics *stats,
   mulle_absolutetime_t start,
   mulle_absolutetime_t end);

static inline void UIWindowDisplayFrameStatisticsInit(
   struct UIWindowFrameStatistics *stats);
```

#### `@protocol UIWindowFrameDelegate`
**Purpose:** Receive frame lifecycle notifications.

**Methods:**
```c
- (void) window:(id) window
 willBeginFrame:(struct CGFrameInfo *) info
graphicsContext:(id<UIGraphicsContext>) context;

- (void) window:(id) window
    didEndFrame:(struct CGFrameInfo *) info
graphicsContext:(id<UIGraphicsContext>) context;

- (void) window:(id) window
   willDrawFrame:(struct CGFrameInfo *) info
 graphicsContext:(id<UIGraphicsContext>) context;

- (void) window:(id) window
    didDrawFrame:(struct CGFrameInfo *) info
 graphicsContext:(id<UIGraphicsContext>) context;
```

#### Profiling Support
```c
struct MulleWindowProfileEntry
{
   mulle_absolutetime_t   timestamp;
   char                   *function;
   void                   *stacktrace;
   uint8_t                action;     // Begin, Sync, or End
   uint8_t                mode;
};

void UIWindowDestroyProfileQueue(struct mulle_structqueue *queue);

// Macros for profiling (active when window created with profile flag)
MulleWindowProfileBegin()
MulleWindowProfileEnd()
MulleWindowProfileSync()
```

### 3.2. `UIPureWindow+UIWindow.h` - UIWindow Protocol Conformance

#### `@interface UIPureWindow(UIWindow) <UIWindow>`
**Purpose:** Conforms to UIWindow protocol for UIApplication integration.

**Methods:**
```c
// Called by UIApplication run loop to render frame if needed
- (mulle_relativetime_t) displayFrameIfNeeded:(mulle_absolutetime_t) now;
```

**Functions:**
```c
mulle_relativetime_t UIWindowGetAnimationRate(UIPureWindow *self);
```

### 3.3. `UIPureWindow+Render.h` - Rendering Infrastructure

#### `@interface UIPureWindow(Render)`
**Purpose:** Core rendering methods and render pipeline support.

**Main Render Entry:**
```c
// Primary render method - called from window thread or displayFrameIfNeeded:
- (UIWindowDisplayBits) renderWithFrameInfo:(struct CGFrameInfo *) info
                                displayBits:(UIWindowDisplayBits) displayBits;
```

**Supporting Render Methods:**
```c
// Clear framebuffer (respects opaque property and willClearCallback)
- (void) clearFrame:(struct CGFrameInfo *) info
    graphicsContext:(id<UIGraphicsContext>) context;

// Execute frame callbacks (layout, animation, drawing)
- (UIWindowDisplayBits) render_frameWithFrameInfo:(struct CGFrameInfo *) info
                                      displayBits:(UIWindowDisplayBits) displayBits;

// Adjust frame geometry if window resized
- (UIWindowDisplayBits) render_adjustFrameWithFrameInfo:(struct CGFrameInfo *) info
                                            displayBits:(UIWindowDisplayBits) displayBits;

// Initialize first responder if not yet set
- (void) render_setupInitialFirstResponderIfNeeded;

// Request synthetic mouse motion event if needed for hover tracking
- (void) render_requestFakeMouseEventIfNeeded:(UIWindowDisplayBits) displayBits;
```

**Debug Rendering:**
```c
// Draw debug overlay (frame count, display bits, etc.)
- (void) render_drawDebug:(struct CGFrameInfo *) info
          graphicsDrawing:(id<UIGraphicsDrawing>) drawing;

// Draw frame number at position
- (void) render_debugNumberOfFrames:(NSUInteger) numberOfFrames
                            atPoint:(CGPoint) point
                           hexColor:(NSUInteger) color
                    graphicsDrawing:(id<UIGraphicsDrawing>) context;

// Draw display bits at position
- (void) render_debugDisplayBits:(NSUInteger) displayBits
                         atPoint:(CGPoint) point
                 graphicsDrawing:(id<UIGraphicsDrawing>) context;
```

**Render Pipeline:**
```
render_setupInitialFirstResponderIfNeeded
    ↓
render_adjustFrameIfNeeded
    ↓
render_frameWithFrameInfo:displayBits:
    ↓
render_requestFakeMouseEventIfNeeded
```

### 3.4. `UIPureWindow+Frame.h` - Buffer Swapping and Screenshots

#### `@interface UIPureWindow(Frame)`
**Purpose:** Buffer swapping and framebuffer capture.

**Methods:**
```c
// Swap buffers (respects swapInterval)
- (void) swapBuffers;                           // Thread-safe

// Swap immediately ignoring swapInterval
- (void) swapBuffersImmediately;                // Thread-safe

// Capture current framebuffer as bitmap
- (struct CGBitmap) screenshotBitmap;
```

### 3.5. `UIPureWindow+UIEvent.h` - Event Handling

#### `@interface UIPureWindow(UIEvent) <UIEventReceiver>`
**Purpose:** Process and dispatch UI events through responder chain.

**Event Reception (Main Thread):**
```c
// Receive event from UIApplication (retains event)
- (void) receiveRetainedEvent:(UIEvent *) event;        // Main thread only

// Handle window-specific event
- (UIWindowEvent *) handleWindowEvent:(UIWindowEvent *) event; // Main thread only

// Execute queued events on window thread
- (NSUInteger) executeEventQueue;
```

**Event Queue Management:**
```c
// Discard all pending events
- (void) discardPendingEvents;

// Control whether to discard event (return YES to discard)
- (BOOL) willDiscardEvent:(UIEvent *) event;            // Thread-safe
- (BOOL) willDiscardOverflowEvent:(UIEvent *) event;    // Main thread only
- (BOOL) willDiscardPendingEvent:(UIEvent *) event;     // Window thread
```

**Event Configuration:**
```c
// Enable/disable mouse motion events
- (BOOL) isMouseMotionEventsEnabled;
- (void) setMouseMotionEventsEnabled:(BOOL) flag;

// Send window geometry change event
- (void) sendWindowFramebufferGeometryEvent:(struct CGWindowInfo *) info; // Thread-safe
```

#### `@interface UIPureWindow(OSInputEvents)`
**Purpose:** Low-level OS event callbacks (called by OS window).

**Keyboard Events:**
```c
- (void) _charCallback:(unsigned int) codepoint;
- (void) _keyCallback:(int) key
             scancode:(int) scancode
               action:(int) action
            modifiers:(int) mods;
```

**Mouse Events:**
```c
- (void) _mouseMotionCallback:(CGPoint) pos;
- (void) _mouseButtonCallback:(int) button
                       action:(int) action
                    modifiers:(int) mods;
- (void) _mouseScrollCallback:(CGPoint) offset;
```

### 3.6. `UIPureWindow+UIResponder.h` - Responder Chain Management

#### `@interface UIPureWindow(UIResponder)`
**Purpose:** Manage first responder and keyboard event routing.

**First Responder Management:**
```c
// Get current first responder
- (id<UIResponder>) firstResponder;

// Change first responder (low-level, prefer becomeFirstResponder/resignFirstResponder)
- (BOOL) makeFirstResponder:(id<UIResponder>) responder;

// Navigate responder chain
- (id<UIResponder>) previousFirstResponder;
- (id<UIResponder>) nextFirstResponder;
```

**Event Routing:**
```c
// Route keyboard event through responder chain
- (UIInputEvent *) acceptKeyboardEvent:(UIKeyboardEvent *) event;
```

### 3.7. `UIPureWindow+UIGraphicsContext.h` - Graphics Context Management

#### `@interface UIPureWindow(UIGraphicsContext)`
**Purpose:** Activate and deactivate graphics contexts for rendering.

**Context Activation:**
```c
// Activate window's visible context (main thread in retained mode)
- (id<UIGraphicsContext>) activateWindowGraphicsContext;     // Thread-safe

// Activate offscreen rendering context (window thread in retained mode)
- (id<UIGraphicsContext>) activateOffscreenGraphicsContext;  // Thread-safe

// Deactivate any context
- (void) deactivateGraphicsContext:(id<UIGraphicsContext>) context; // Thread-safe
```

**Render Context (Internal):**
```c
// Activate render context (used during frame rendering)
- (void) activateRenderGraphicsContext;                      // Thread-safe
- (void) deactivateRenderGraphicsContext;                    // Thread-safe
- (void) deactivateRenderGraphicsContextKeepState:(UIGraphicsContextState) keepState; // Thread-safe

// Advanced: activate custom context
- (id<UIGraphicsContext>) activateGraphicsContext:(id<UIGraphicsContext>) context
                                         OSWindow:(id<UIOSWindow>) OSWindow; // Thread-safe
```

**Usage Pattern:**
Place NSAutoreleasePool between activate and deactivate to properly release temporary GPU resources.

### 3.8. `UIPureWindow+FrameInfo.h` - Frame Timing

#### `@interface UIPureWindow(FrameInfo)`
**Purpose:** Query and synchronize frame timing information.

**Methods:**
```c
// Get current frame info snapshot
- (void) getFrameInfo:(struct CGFrameInfo *) info;           // Thread-safe

// Synchronize frame info (update timestamp and counters)
- (void) syncFrameInfo:(struct CGFrameInfo *) info;          // Thread-safe

// Calculate remaining time in frame budget
- (mulle_relativetime_t) remainingFrameTime:(mulle_absolutetime_t) now
                                  frameRate:(mulle_relativetime_t) frameRate
                              animationRate:(mulle_relativetime_t) animationRate
                            frameStatistics:(struct UIWindowFrameStatistics *) stats
                           frameRateLimiter:(BOOL) frameLimiter;
```

### 3.9. `UIPureWindow+NSTimer.h` - Timer Management

#### `@interface UIPureWindow(NSTimer) <UITimerReceiver>`
**Purpose:** Schedule and execute timers on window thread.

**Timer Management (Thread-safe):**
```c
// Add timer to window (will fire on window thread)
- (void) addTimer:(NSTimer *) timer;

// Reset timer's next fire date
- (void) resetTimer:(NSTimer *) timer;

// Remove specific timer
- (void) removeTimer:(NSTimer *) timer;

// Remove all timers
- (void) removeAllTimers;
```

**Timer Queue Execution (Window Thread):**
```c
// Discard pending timers
- (void) discardPendingTimers;                          // Window thread only

// Execute fired timers
- (NSUInteger) executeTimerQueue;                       // Window thread only
```

**Timer Reception (Main Thread):**
```c
// Handle timer from UIApplication (queues for window thread)
- (void) handleRetainedTimer:(NSTimer *) timer;         // Main thread only

// Control timer discarding
- (BOOL) willDiscardOverflowTimer:(NSTimer *) timer;    // Main thread only
- (BOOL) willDiscardPendingTimer:(NSTimer *) timer;     // Window thread only
```

**Note:** Window must be added to UIApplication before adding timers.

### 3.10. `UIPureWindow+InvocationQueue.h` - Background Operations

#### `@interface UIPureWindow(InvocationQueue)`
**Purpose:** Manage named invocation queues for background processing.

**Queue Management:**
```c
// Get or create invocation queue by name
- (MulleInvocationQueue *) invocationQueueForNameUTF8String:(char *) name;

// Set specific invocation queue for name
- (void) setInvocationQueue:(MulleInvocationQueue *) queue
          forNameUTF8String:(char *) name;

// Remove invocation queue
- (void) removeInvocationQueueForNameUTF8String:(char *) name;
```

**Queue Processing:**
```c
// Poll all invocation queues (called during frame processing)
- (void) pollInvocationQueues;

// Terminate all queues
- (void) terminateAllInvocationQueues;
```

**Internal:**
```c
- (void) _initInvocationQueues;
- (void) _doneInvocationQueues;
```

### 3.11. `UIPureWindow+Thread.h` - Window Thread Management

#### `@interface UIPureWindow(Thread)`
**Purpose:** Manage dedicated window rendering thread (retained mode only).

**Thread Lifecycle:**
```c
// Start window thread if needed (based on backingStore)
- (void) startWindowThreadMainIfNeeded;

// Cleanup window thread (main thread only)
- (void) finalizeWindowThread;                          // Main thread only

// Wake sleeping window thread (main thread only)
- (void) wakeupWindowThread;                            // Main thread only
```

**Thread Main Loop:**
```c
// Window thread main loop (runs on window thread)
- (void) windowThreadMain:(NSLock *) lock;              // Thread-safe

// Calculate timeout for next frame
- (mulle_relativetime_t) windowThreadTimeoutIsAnimating:(BOOL) flag;
```

#### `@interface UIPureWindow(ThreadFuture)`
**Purpose:** Future thread API.

**Methods:**
```c
// Refresh display (main thread only)
- (void) refresh;                                       // Main thread only
```

### 3.12. `UIPureWindow+ThreadRefresh.h` - Buffer Refresh

#### `@interface UIPureWindow(ThreadRefresh)`
**Purpose:** Handle buffer swapping between threads.

**Methods:**
```c
// Refresh window from offscreen buffer (main thread in retained mode)
- (void) refresh;                                       // Thread-safe

// Set last rendered framebuffer for next refresh
- (void) setLastOffscreenFramebuffer:(id<UIFramebuffer>) framebuffer; // Thread-safe
```

### 3.13. `UIPureWindow+OneFrame.h` - Simple Render Loop

#### `@interface UIPureWindow(OneFrame)`
**Purpose:** Simplified single-frame API for GLFW-style render loops (non-retained mode).

**Event Waiting:**
```c
// Wait for events with timeout (returns event type bits)
- (NSUInteger) waitForEventsUntil:(mulle_absolutetime_t) timeout
                     returnsEarly:(BOOL) returnsEarly;

// Process events for one iteration
- (NSUInteger) processEvents:(mulle_absolutetime_t) now
                   frameRate:(mulle_relativetime_t) frameRate;

// Event handling with frame rate limit
- (void) eventHandlingWithFrameRate:(mulle_relativetime_t) frameRate;
```

**One-Frame Rendering:**
```c
// Process one complete frame (events + rendering) with frame rate
- (BOOL) processOneFrame:(CGFloat) frameRate;

// Process one complete frame (events + rendering) unsynced
- (BOOL) processOneFrame;

// Render and swap one frame (no event handling)
- (void) renderAndSwapOneFrame;
```

**Return Value:** `processOneFrame` returns NO if window should close.

**Usage:** For simple applications without UIApplication run loop, typically in volatile backing store mode.

### 3.14. `UIPureWindow+UIPasteboard.h` - Clipboard

#### `@interface UIPureWindow(Forward) <UIOSWindow>`
**Purpose:** OS window protocol forwarding and clipboard access.

**Clipboard Methods:**
```c
// Get clipboard content as C string
- (char *) pasteboardCString;

// Set clipboard content from C string
- (void) setPasteboardCString:(char *) s;

// Get OS window handle
- (void *) os_window;                                   // Thread-safe
```

### 3.15. `UIPureWindow(OSFuture)` - OS Abstraction Hooks

#### `@interface UIPureWindow(OSFuture)`
**Purpose:** Customization points for OS window and graphics implementation.

**Class Methods:**
```c
// Override to provide custom OS window class
+ (Class) osWindowClass;

// Override to provide custom graphics context class
+ (Class) osGraphicsContextClass;

// Override to provide graphics hints (OpenGL version, etc.)
+ (NSUInteger) osGraphicsHints;
```

### 3.16. `UIPureWindow(Dump)` - Debugging

#### `@interface UIPureWindow(Dump)`
**Purpose:** Debug output of window state.

**Methods:**
```c
// Dump window state to stdout
- (void) dump;

// Dump window state with indentation to file
- (void) dumpWithIndent:(NSUInteger) indent
                   FILE:(FILE *) fp;
```

## 4. Performance Characteristics

### Threading Performance
- **Lock-free event/timer queues**: O(1) enqueue/dequeue, 128-element capacity, single-producer single-consumer model ensures zero contention
- **Atomic operations**: `_needsDisplay`, `_needsRefresh`, `_propertyChanges` use lock-free atomics for cross-thread signaling
- **Property lock contention**: NSLock used only for window properties (title, cursor, frame), typically accessed infrequently
- **Context switches**: Minimized by `keepOSGraphicsContextActive` flag, avoiding OpenGL context activation overhead

### Rendering Performance
- **Frame statistics**: O(1) rolling average over 4-frame history, used to predict next frame time
- **Backing store modes**:
  - Volatile: No extra memory, no thread overhead, requires sub-frame rendering (<16ms at 60Hz)
  - RetainedOnMainThread: 2x framebuffer memory, no thread overhead, debugging only
  - Retained: 3x framebuffer memory (visible + 2x offscreen), thread overhead minimal, production default
- **Buffer swapping**: O(1) GPU blit from offscreen to visible, typically <1ms on modern GPUs
- **Event processing**: O(n) where n is queued events, typically <100 per frame at 60Hz

### Memory Usage
- Window object: ~1KB base
- Event queue: 128 * sizeof(void*) = 1KB per queue (events + timers)
- Frame statistics: 4 * sizeof(double) = 32 bytes per thread (main + window)
- Profile queue: If enabled, 64 bytes per entry, grows unbounded (13MB per hour at 60Hz)
- Framebuffers: width * height * 4 bytes per buffer (2-3 buffers depending on mode)

### Thread Safety
- **Thread-safe methods**: Use atomics or locks, callable from any thread
- **Main thread only**: Window creation, property updates sent to OS window, buffer refresh
- **Window thread only**: Event execution, timer firing, rendering callbacks
- **Not thread-safe**: Most property setters unless marked MULLE_OBJC_THREADSAFE_PROPERTY

## 5. AI Usage Recommendations & Patterns

### Best Practices

1. **Always use retained mode for production**: `UIWindowStyleMaskDefault` includes `UIWindowStyleRetained`, providing flicker-free rendering during window operations.

2. **Respect thread boundaries**: Methods marked `MULLE_UI_MAIN_THREAD_ONLY` must only be called from main thread. Methods marked `MULLE_UI_PURE_WINDOW_THREAD_ONLY` only from window thread. Methods marked `MULLE_OBJC_THREADSAFE_METHOD` are safe from any thread.

3. **Use atomic display flags**: Always use `setNeedsDisplayBit:` or `setNeedsDisplayBits:` rather than direct ivar access. Use `needsDisplayBitsClearIfSet` for atomic test-and-clear.

4. **Minimize context switches**: Set `keepOSGraphicsContextActive = YES` for windows that render frequently. For multiple windows on same thread, must be NO.

5. **Place autorelease pools around context activation**:
```objc
context = [window activateOffscreenGraphicsContext];
{
   NSAutoreleasePool   *pool;
   
   pool = [NSAutoreleasePool new];
   // Rendering code here
   [pool release];
}
[window deactivateGraphicsContext:context];
```

6. **Use frameCallback for simple rendering**: If you don't need UIViews, set `frameCallback` property to bypass view hierarchy entirely.

7. **Check window thread**: Use `[window isWindowThread]` to verify thread context if unsure.

8. **Add window to application before timers**: Timers require window to be in UIApplication's window list.

9. **Don't access internal fields**: Respect `@protected` and `_`-prefixed fields. Use properties and methods.

10. **Handle event overflow gracefully**: Override `willDiscardOverflowEvent:` to handle event queue overflow (>128 events pending).

### Common Pitfalls

1. **Calling main-thread-only methods from window thread**: Will assert in debug, undefined in release. Always check method comments for thread requirements.

2. **Forgetting to add window to application**: Window won't receive events or timers. Always call `[app addWindow:window]`.

3. **Accessing renderGraphicsContext outside rendering**: Property is only valid during frame callbacks. Will abort if accessed at other times.

4. **Not handling shouldClose**: Override or check `shouldClose` to respond to user close requests.

5. **Using volatile mode with slow rendering**: Will flicker during window resize. Use retained mode or optimize rendering to <16ms.

6. **Mixing context activation types**: Don't call `activateOffscreenGraphicsContext` from main thread in retained mode. Each thread has its designated context.

7. **Assuming synchronous property updates**: Properties marked thread-safe may not update immediately due to cross-thread synchronization. Don't rely on read-after-write consistency.

8. **Leaking timers**: Always balance `addTimer:` with `removeTimer:` or `removeAllTimers`. Timers are retained.

9. **Not checking opaque flag**: If rendering leaves transparent pixels, set `opaque = NO` or framebuffer won't be cleared properly.

### Idiomatic Usage

**Window Creation Pattern:**
```objc
UIPureWindow   *window;
CGRect         frame;

frame  = CGRectMake( 100, 100, 800, 600);
window = [UIPureWindow windowWithFrame:frame
                       titleUTF8String:"My Window"
                             styleMask:UIWindowStyleMaskDefault];
[[UIApplication sharedInstance] addWindow:window];
```

**Custom Rendering Pattern:**
```objc
static UIWindowDisplayBits   myFrameCallback( UIPureWindow *window,
                                              id <UIGraphicsContext> context,
                                              struct CGFrameInfo *info,
                                              UIWindowDisplayBits bits)
{
   id <UIGraphicsDrawing>   drawing;
   
   drawing = [context drawing];
   
   // Draw your content
   [drawing beginPath];
   [drawing rect:CGRectMake( 10, 10, 100, 100)];
   [drawing fillHexColor:0xFF0000FF];
   
   return( bits & UIWindowDisplayNeedsAnimation); // Return non-zero if animating
}

[window setFrameCallback:myFrameCallback];
```

**Event Handling Pattern:**
```objc
@interface MyResponder : NSObject <UIResponder>
@end

@implementation MyResponder

- (UIMouseEvent *) mouseDown:(UIMouseEvent *) event
{
   CGPoint   location;
   
   location = [event locationInWindow];
   printf( "Mouse down at %.0f,%.0f\n", location.x, location.y);
   return( nil); // Consume event
}

- (UIKeyboardEvent *) keyDown:(UIKeyboardEvent *) event
{
   unsigned int   key;
   
   key = [event key];
   if( key == UIKeyEscape)
   {
      [[self window] requestClose];
      return( nil);
   }
   return( event); // Forward event
}

@end

// Setup
MyResponder   *responder;

responder = [MyResponder new];
[window setResponder:responder];
[responder release];
```

**Timer Pattern:**
```objc
- (void) timerFired:(NSTimer *) timer
{
   printf( "Timer fired\n");
   [window setNeedsDisplayBit:UIWindowDisplayNeedsRedraw];
}

NSTimer   *timer;

timer = [NSTimer timerWithTimeInterval:1.0
                                target:self
                              selector:@selector( timerFired:)
                               repeats:YES];
[window addTimer:timer];
[timer release];
```

**Simple Render Loop Pattern (Volatile Mode):**
```objc
window = [UIPureWindow windowWithFrame:frame
                       titleUTF8String:"Simple"
                             styleMask:UIWindowStyleMaskNonRetained];
[window setFrameCallback:myFrameCallback];

while( [window processOneFrame:60.0])
{
   // Loop continues until window close requested
}
```

## 6. Integration Examples

### Example 1: Creating a Basic Window with Custom Drawing

```c
#import <MulleUIPureWindow/MulleUIPureWindow.h>

static UIWindowDisplayBits   customDrawing( UIPureWindow *window,
                                            id <UIGraphicsContext> context,
                                            struct CGFrameInfo *info,
                                            UIWindowDisplayBits bits)
{
   id <UIGraphicsDrawing>   drawing;
   CGRect                   bounds;
   
   drawing = [context drawing];
   bounds  = [window bounds];
   
   // Draw gradient background
   [drawing beginPath];
   [drawing rect:bounds];
   [drawing fillLinearGradientFromPoint:CGPointMake( 0, 0)
                                toPoint:CGPointMake( 0, bounds.size.height)
                         startHexColor:0x1E3A8AFF
                           endHexColor:0x3B82F6FF];
   
   // Draw text
   [drawing fillHexColor:0xFFFFFFFF];
   [drawing setFontWithNameUTF8String:"sans"
                                 size:48.0];
   [drawing text:"Hello Window!"
             atX:bounds.size.width / 2.0
               y:bounds.size.height / 2.0
           align:UITextAlignCenter | UITextAlignMiddle];
   
   return( 0); // Not animating
}

int   main( int argc, char *argv[])
{
   UIApplication   *app;
   UIPureWindow    *window;
   CGRect          frame;
   
   app = [UIApplication sharedInstance];
   
   frame  = CGRectMake( 100, 100, 800, 600);
   window = [UIPureWindow windowWithFrame:frame
                          titleUTF8String:"Drawing Example"
                                styleMask:UIWindowStyleMaskDefault];
   
   [window setFrameCallback:customDrawing];
   [window setBackgroundHexColor:0x000000FF];
   [window setOpaque:YES];
   
   [app addWindow:window];
   [window setNeedsDisplay];
   
   [app run];
   
   return( 0);
}
```

### Example 2: Animated Rotating Square

```c
#import <MulleUIPureWindow/MulleUIPureWindow.h>

struct AnimationState
{
   CGFloat   rotation;
   CGFloat   rotationSpeed;
};

static UIWindowDisplayBits   animatedDrawing( UIPureWindow *window,
                                              id <UIGraphicsContext> context,
                                              struct CGFrameInfo *info,
                                              UIWindowDisplayBits bits)
{
   struct AnimationState   *state;
   id <UIGraphicsDrawing>  drawing;
   CGRect                  bounds;
   CGPoint                 center;
   CGFloat                 size;
   
   state   = [window userInfo];
   drawing = [context drawing];
   bounds  = [window bounds];
   center  = CGPointMake( bounds.size.width / 2.0, bounds.size.height / 2.0);
   size    = 100.0;
   
   // Update rotation
   state->rotation += state->rotationSpeed * info->elapsed;
   
   // Draw rotating square
   [drawing save];
   [drawing translate:center.x
                    y:center.y];
   [drawing rotate:state->rotation];
   
   [drawing beginPath];
   [drawing rect:CGRectMake( -size / 2.0, -size / 2.0, size, size)];
   [drawing fillHexColor:0xFF6B6BFF];
   [drawing strokeHexColor:0xFFFFFFFF];
   [drawing setStrokeWidth:3.0];
   [drawing stroke];
   
   [drawing restore];
   
   return( UIWindowDisplayNeedsRedraw); // Keep animating
}

int   main( int argc, char *argv[])
{
   UIApplication           *app;
   UIPureWindow            *window;
   CGRect                  frame;
   struct AnimationState   state;
   
   app = [UIApplication sharedInstance];
   
   frame  = CGRectMake( 100, 100, 800, 600);
   window = [UIPureWindow windowWithFrame:frame
                          titleUTF8String:"Animation Example"];
   
   // Setup animation state
   state.rotation      = 0.0;
   state.rotationSpeed = 2.0; // radians per second
   [window setUserInfo:(id) &state];
   
   [window setFrameCallback:animatedDrawing];
   [window setBackgroundHexColor:0x1A202CFF];
   [window setOpaque:YES];
   
   [app addWindow:window];
   [window setNeedsDisplay];
   
   [app run];
   
   return( 0);
}
```

### Example 3: Mouse and Keyboard Event Handling

```c
#import <MulleUIPureWindow/MulleUIPureWindow.h>

@interface EventResponder : NSObject <UIResponder>
{
   CGPoint   _mouseLocation;
   BOOL      _isMouseDown;
}
@end

@implementation EventResponder

- (UIMouseEvent *) mouseDown:(UIMouseEvent *) event
{
   _isMouseDown    = YES;
   _mouseLocation  = [event locationInWindow];
   
   [[self window] setNeedsDisplayBit:UIWindowDisplayNeedsRedraw];
   return( nil);
}

- (UIMouseEvent *) mouseUp:(UIMouseEvent *) event
{
   _isMouseDown = NO;
   [[self window] setNeedsDisplayBit:UIWindowDisplayNeedsRedraw];
   return( nil);
}

- (UIMouseEvent *) mouseMoved:(UIMouseEvent *) event
{
   if( _isMouseDown)
   {
      _mouseLocation = [event locationInWindow];
      [[self window] setNeedsDisplayBit:UIWindowDisplayNeedsRedraw];
   }
   return( nil);
}

- (UIKeyboardEvent *) keyDown:(UIKeyboardEvent *) event
{
   unsigned int   key;
   
   key = [event key];
   
   switch( key)
   {
   case UIKeyEscape :
      [[self window] requestClose];
      break;
      
   case UIKeySpace :
      _isMouseDown   = NO;
      _mouseLocation = CGPointMake( 0, 0);
      [[self window] setNeedsDisplayBit:UIWindowDisplayNeedsRedraw];
      break;
   }
   
   return( nil);
}

- (CGPoint) mouseLocation
{
   return( _mouseLocation);
}

- (BOOL) isMouseDown
{
   return( _isMouseDown);
}

@end

static UIWindowDisplayBits   eventDrawing( UIPureWindow *window,
                                           id <UIGraphicsContext> context,
                                           struct CGFrameInfo *info,
                                           UIWindowDisplayBits bits)
{
   EventResponder          *responder;
   id <UIGraphicsDrawing>  drawing;
   CGPoint                 location;
   
   responder = [window responder];
   drawing   = [context drawing];
   location  = [responder mouseLocation];
   
   // Draw circle at mouse location if button down
   if( [responder isMouseDown])
   {
      [drawing beginPath];
      [drawing circle:location
               radius:20.0];
      [drawing fillHexColor:0xFF4444FF];
   }
   
   // Draw instructions
   [drawing fillHexColor:0xFFFFFFFF];
   [drawing setFontWithNameUTF8String:"sans"
                                 size:16.0];
   [drawing text:"Click and drag to draw. Space to clear. ESC to quit."
             atX:10.0
               y:20.0
           align:UITextAlignLeft | UITextAlignTop];
   
   return( 0);
}

int   main( int argc, char *argv[])
{
   UIApplication   *app;
   UIPureWindow    *window;
   EventResponder  *responder;
   CGRect          frame;
   
   app = [UIApplication sharedInstance];
   
   frame  = CGRectMake( 100, 100, 800, 600);
   window = [UIPureWindow windowWithFrame:frame
                          titleUTF8String:"Event Example"];
   
   responder = [EventResponder new];
   [window setResponder:responder];
   [responder release];
   
   [window setFrameCallback:eventDrawing];
   [window setBackgroundHexColor:0x000000FF];
   [window setOpaque:YES];
   [window setMouseMotionEventsEnabled:YES];
   
   [app addWindow:window];
   [window setNeedsDisplay];
   
   [app run];
   
   return( 0);
}
```

### Example 4: Using Timers for Periodic Updates

```c
#import <MulleUIPureWindow/MulleUIPureWindow.h>

@interface TimerController : NSObject
{
   NSUInteger   _counter;
}
@end

@implementation TimerController

- (instancetype) init
{
   _counter = 0;
   return( self);
}

- (void) timerFired:(NSTimer *) timer
{
   UIPureWindow   *window;
   char           title[256];
   
   _counter++;
   window = [timer userInfo];
   
   sprintf( title, "Timer Example - Count: %lu", (unsigned long) _counter);
   [window setTitleUTF8String:title];
   [window setNeedsDisplayBit:UIWindowDisplayNeedsRedraw];
}

- (NSUInteger) counter
{
   return( _counter);
}

@end

static UIWindowDisplayBits   timerDrawing( UIPureWindow *window,
                                           id <UIGraphicsContext> context,
                                           struct CGFrameInfo *info,
                                           UIWindowDisplayBits bits)
{
   TimerController         *controller;
   id <UIGraphicsDrawing>  drawing;
   CGRect                  bounds;
   char                    text[256];
   
   controller = [window userInfo];
   drawing    = [context drawing];
   bounds     = [window bounds];
   
   sprintf( text, "%lu", (unsigned long) [controller counter]);
   
   [drawing fillHexColor:0xFFFFFFFF];
   [drawing setFontWithNameUTF8String:"sans-bold"
                                 size:72.0];
   [drawing text:text
             atX:bounds.size.width / 2.0
               y:bounds.size.height / 2.0
           align:UITextAlignCenter | UITextAlignMiddle];
   
   return( 0);
}

int   main( int argc, char *argv[])
{
   UIApplication    *app;
   UIPureWindow     *window;
   TimerController  *controller;
   NSTimer          *timer;
   CGRect           frame;
   
   app = [UIApplication sharedInstance];
   
   frame  = CGRectMake( 100, 100, 800, 600);
   window = [UIPureWindow windowWithFrame:frame
                          titleUTF8String:"Timer Example - Count: 0"];
   
   controller = [TimerController new];
   [window setUserInfo:controller];
   [controller release];
   
   [window setFrameCallback:timerDrawing];
   [window setBackgroundHexColor:0x2D3748FF];
   [window setOpaque:YES];
   
   [app addWindow:window];
   
   timer = [NSTimer timerWithTimeInterval:1.0
                                   target:controller
                                 selector:@selector( timerFired:)
                                 userInfo:window
                                  repeats:YES];
   [window addTimer:timer];
   [timer release];
   
   [window setNeedsDisplay];
   
   [app run];
   
   return( 0);
}
```

### Example 5: Simple GLFW-style Render Loop (Volatile Mode)

```c
#import <MulleUIPureWindow/MulleUIPureWindow.h>

static UIWindowDisplayBits   simpleDrawing( UIPureWindow *window,
                                            id <UIGraphicsContext> context,
                                            struct CGFrameInfo *info,
                                            UIWindowDisplayBits bits)
{
   id <UIGraphicsDrawing>  drawing;
   CGRect                  bounds;
   CGFloat                 phase;
   CGHexColor              color;
   
   drawing = [context drawing];
   bounds  = [window bounds];
   
   // Pulsing color based on frame time
   phase = sin( info->timestamp * 2.0) * 0.5 + 0.5;
   color = (CGHexColor) (phase * 255.0) << 16 | 0x4444FF;
   
   [drawing beginPath];
   [drawing rect:CGRectMake( bounds.size.width / 2.0 - 50.0,
                             bounds.size.height / 2.0 - 50.0,
                             100.0,
                             100.0)];
   [drawing fillHexColor:color];
   
   return( UIWindowDisplayNeedsRedraw); // Keep animating
}

int   main( int argc, char *argv[])
{
   UIPureWindow   *window;
   CGRect         frame;
   
   frame  = CGRectMake( 100, 100, 640, 480);
   window = [UIPureWindow windowWithFrame:frame
                          titleUTF8String:"Simple Loop"
                                styleMask:UIWindowStyleMaskNonRetained];
   
   [window setFrameCallback:simpleDrawing];
   [window setBackgroundHexColor:0x1A1A1AFF];
   [window setOpaque:YES];
   
   // Simple render loop (no UIApplication needed)
   while( [window processOneFrame:60.0])
   {
      // Application logic here
   }
   
   return( 0);
}
```

### Example 6: Multiple Windows

```c
#import <MulleUIPureWindow/MulleUIPureWindow.h>

static UIWindowDisplayBits   window1Drawing( UIPureWindow *window,
                                             id <UIGraphicsContext> context,
                                             struct CGFrameInfo *info,
                                             UIWindowDisplayBits bits)
{
   id <UIGraphicsDrawing>  drawing;
   CGRect                  bounds;
   
   drawing = [context drawing];
   bounds  = [window bounds];
   
   [drawing beginPath];
   [drawing rect:CGRectMake( 50, 50, 100, 100)];
   [drawing fillHexColor:0xFF0000FF];
   
   return( 0);
}

static UIWindowDisplayBits   window2Drawing( UIPureWindow *window,
                                             id <UIGraphicsContext> context,
                                             struct CGFrameInfo *info,
                                             UIWindowDisplayBits bits)
{
   id <UIGraphicsDrawing>  drawing;
   CGRect                  bounds;
   
   drawing = [context drawing];
   bounds  = [window bounds];
   
   [drawing beginPath];
   [drawing circle:CGPointMake( bounds.size.width / 2.0,
                                bounds.size.height / 2.0)
            radius:50.0];
   [drawing fillHexColor:0x00FF00FF];
   
   return( 0);
}

int   main( int argc, char *argv[])
{
   UIApplication   *app;
   UIPureWindow    *window1;
   UIPureWindow    *window2;
   CGRect          frame;
   
   app = [UIApplication sharedInstance];
   
   // Create first window
   frame   = CGRectMake( 100, 100, 400, 300);
   window1 = [UIPureWindow windowWithFrame:frame
                           titleUTF8String:"Window 1"];
   [window1 setFrameCallback:window1Drawing];
   [window1 setBackgroundHexColor:0x000000FF];
   [window1 setOpaque:YES];
   [window1 setKeepOSGraphicsContextActive:NO]; // Important for multiple windows!
   [app addWindow:window1];
   [window1 setNeedsDisplay];
   
   // Create second window
   frame   = CGRectMake( 550, 100, 400, 300);
   window2 = [UIPureWindow windowWithFrame:frame
                           titleUTF8String:"Window 2"];
   [window2 setFrameCallback:window2Drawing];
   [window2 setBackgroundHexColor:0x000000FF];
   [window2 setOpaque:YES];
   [window2 setKeepOSGraphicsContextActive:NO]; // Important for multiple windows!
   [app addWindow:window2];
   [window2 setNeedsDisplay];
   
   [app run];
   
   return( 0);
}
```

## 7. Dependencies

MulleUIPureWindow directly depends on:

- **MulleUIApplication** - Provides UIApplication, UIEvent, UIResponder protocols, and event infrastructure
- **MulleInvocationQueue** - Background thread processing for invocation queues
- **mulle-objc-list** - Runtime introspection (build-time only, no linking)

Additional transitive dependencies (inherited through MulleUIApplication):
- **MulleUIBase** - Core UI types, protocols, and constants
- **MulleGraphics** - Graphics context and drawing protocols (optional, but typically used)
- **MulleFoundation** - Foundation classes (NSTimer, NSThread, NSLock, etc.)
- **mulle-objc** - Objective-C runtime
- **mulle-core** - Core C libraries (containers, threads, time)
- **mulle-c11** - C11 compatibility and allocator

Position in hierarchy: MulleUIPureWindow sits between MulleUIApplication (below) and UIWindow/full UI stack (above). It provides the foundation for windowing without imposing view hierarchy requirements.
