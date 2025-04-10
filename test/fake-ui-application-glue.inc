//
// necessary glue code, as long as you don't have MulleUIOS
//
@interface FakeOSWindow : NSObject < UIOSWindow>
@property (assign) id <UIEventReceiver> windowEventsReceiver;
@property (assign) id <UIEventReceiver> eventsReceiver;
@property (assign) NSUInteger discardEventsMask;
@property (assign) id <UIWindow> parentWindow;
@property (readonly, getter=isAntiAliasing) BOOL antiAliasing;
@property (assign) UIOSWindowEventCallback_t windowEventsCallback;
@property (assign) UIOSWindowRetainedEventCallback_t otherRetainedEventsCallback;
@property (assign) UIOSWindowFrameCallback_t frameCallback;

// Private properties for implementation
@property (assign) CGRect frame;
@property (assign) NSInteger shareIdentifier;
@property (assign) BOOL rateLimiter;
@property (assign) mulle_relativetime_t frameRateValue;
@property (assign) CGFloat frameRateHzValue;
@property (assign) NSUInteger backendType;
@property (assign) mulle_absolutetime_t lastSwapTime;
@property (assign) NSUInteger swapInterval;
@property (assign) BOOL shouldClose;
@property (assign) void *cursorPtr;
@property (assign) void *windowPtr;
@end


@implementation FakeOSWindow

- (instancetype)init
{
    if (self = [super init]) {
        _antiAliasing = NO;
        _rateLimiter = YES;
        _frameRateValue = 1.0 / 60.0;
        _frameRateHzValue = 60.0;
        _backendType = 0;
        _shareIdentifier = 1;
        _swapInterval = 1;
        _shouldClose = NO;
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
               titleUTF8String:(char *)title
                     styleMask:(NSUInteger)styleMask
                 graphicsHints:(NSUInteger)hints
                 sharingWindow:(id<UIOSWindow>)sharingWindow
{
    if (self = [super init]) {
        _frame = frame;
        _antiAliasing = (hints & 0x1) != 0; // Assuming 0x1 might be antialiasing flag
        _rateLimiter = YES;
        _frameRateValue = 1.0 / 60.0;
        _frameRateHzValue = 60.0;
        _backendType = 0;

        // If sharing a window, use its shareID
        if (sharingWindow) {
            _shareIdentifier = [sharingWindow shareID];
        } else {
            // Generate a new shareID
            static NSInteger nextShareID = 1;
            _shareIdentifier = nextShareID++;
        }
    }
    return self;
}

- (NSInteger)shareID
{
    return _shareIdentifier;
}

- (void)setFrameRateLimiter:(BOOL)flag MULLE_OBJC_THREADSAFE_METHOD
{
    _rateLimiter = flag;
}

- (BOOL)frameRateLimiter MULLE_OBJC_THREADSAFE_METHOD
{
    return _rateLimiter;
}

- (void)setFrameRate:(mulle_relativetime_t)frameRate MULLE_OBJC_THREADSAFE_METHOD
{
    _frameRateValue = frameRate;
    _frameRateHzValue = frameRate > 0 ? 1.0 / frameRate : 0;
}

- (mulle_relativetime_t)frameRate MULLE_OBJC_THREADSAFE_METHOD
{
    return _frameRateValue;
}

- (void)setFrameRateHz:(CGFloat)frameRateHz MULLE_OBJC_THREADSAFE_METHOD
{
    _frameRateHzValue = frameRateHz;
    _frameRateValue = frameRateHz > 0 ? 1.0 / frameRateHz : 0;
}

- (CGFloat)frameRateHz MULLE_OBJC_THREADSAFE_METHOD
{
    return _frameRateHzValue;
}

- (NSUInteger)backend MULLE_OBJC_THREADSAFE_METHOD
{
    return _backendType;
}

- (NSThread *)activeThread
{
   return [NSThread currentThread];
}

- (id<UIOSWindow>)OSWindow
{
    return self;
}

- (id<UIScreen>)screenOrPrimaryScreen:(BOOL)flag
{
    // Just return nil for testing
    return nil;
}

- (id<UIScreen>)screen
{
    return [self screenOrPrimaryScreen:NO];
}

- (id<UIGamepad>)gamepadAtIndex:(NSUInteger)index
{
    // Just return nil for testing
    return nil;
}

- (void)getOSWindowInfo:(struct UIOSWindowInfo *)info MULLE_OBJC_THREADSAFE_METHOD
{
    // Fill with dummy data
    if (info) {
        memset(info, 0, sizeof(struct UIOSWindowInfo));
    }
}

- (void)os_setSwapInterval:(NSUInteger)value MULLE_OBJC_THREADSAFE_METHOD
{
    _swapInterval = value;
}

- (void)os_activateGraphicsContext
{
    // Fake implementation
}

- (BOOL)os_tryActivateGraphicsContext
{
    return YES; // Always succeeds in fake implementation
}

- (void)os_deactivateGraphicsContext
{
    // Fake implementation
}

- (void)os_swapBuffers
{
    _lastSwapTime = mulle_absolutetime_now();
}

- (void)os_requestClose MULLE_OBJC_THREADSAFE_METHOD
{
    _shouldClose = YES;
}

- (BOOL)os_windowShouldClose MULLE_OBJC_THREADSAFE_METHOD
{
    return _shouldClose;
}

- (void)os_show MULLE_UI_MAIN_THREAD_ONLY
{
    // Fake implementation
}

- (void)os_hide MULLE_UI_MAIN_THREAD_ONLY
{
    // Fake implementation
}

- (CGPoint)os_windowPosition MULLE_UI_MAIN_THREAD_ONLY
{
    return _frame.origin;
}

- (void)os_setWindowPosition:(CGPoint)position MULLE_UI_MAIN_THREAD_ONLY
{
    _frame.origin = position;
}

- (CGSize)os_windowSize MULLE_UI_MAIN_THREAD_ONLY
{
    return _frame.size;
}

- (void)os_setWindowSize:(CGSize)size MULLE_UI_MAIN_THREAD_ONLY
{
    _frame.size = size;
}

- (CGRect)os_windowFrame MULLE_UI_MAIN_THREAD_ONLY
{
    return _frame;
}

- (void)os_setWindowFrame:(CGRect)rect MULLE_UI_MAIN_THREAD_ONLY
{
    _frame = rect;
}

- (CGPixelSize)os_framebufferSize MULLE_UI_MAIN_THREAD_ONLY
{
    CGPixelSize size = { (NSUInteger)_frame.size.width, (NSUInteger)_frame.size.height };
    return size;
}

- (void)os_initEvents MULLE_UI_MAIN_THREAD_ONLY
{
    // Fake implementation
}

- (void)os_finalizeEvents MULLE_UI_MAIN_THREAD_ONLY
{
    // Fake implementation
}

- (void)os_setTitleUTF8String:(char *)s MULLE_UI_MAIN_THREAD_ONLY
{
    // Fake implementation
}

- (void)os_setCursor:(void *)cursor MULLE_UI_MAIN_THREAD_ONLY
{
    _cursorPtr = cursor;
}

- (void *)os_createCursorWithBitmap:(struct CGBitmap)bitmap
                            hotSpot:(struct CGPixelPoint)hotSpot MULLE_UI_MAIN_THREAD_ONLY
{
    // Just return a dummy pointer
    static int dummyCursor;
    return &dummyCursor;
}

- (void)os_destroyCursor:(void *)cursor MULLE_UI_MAIN_THREAD_ONLY
{
    // Fake implementation
}

- (void *)os_window MULLE_OBJC_THREADSAFE_METHOD
{
    return _windowPtr;
}

- (mulle_absolutetime_t)lastSwapBuffersTimestamp
{
    return _lastSwapTime;
}

@end

@interface FakeContext : NSObject < UIGraphicsContext, UIGraphicsDrawing>
{
   char         *_nameUTF8String;
   NSUInteger   _state;
}
@property (assign) NSThread *activeThread;
@property (assign) BOOL rendersOffScreen;
@property (assign) NSUInteger framebufferBits;
@property (assign) id OSWindow;
@property (assign, readonly) UIGraphicsBackend backend;
@property (assign) struct UIInputState inputState;
@property (assign, getter=isInitializedFramebuffer) BOOL initializedFramebuffer;

// Private properties for implementation
@property (assign) UIGraphicsCompositionMode compositionMode;
@property (assign) NSUInteger frameCounter;
@property (assign) BOOL isActiveFlag;
@property (assign) NSUInteger graphicsShareID;
@property (assign) UIGraphicsOptions graphicsOptions;
@property (assign) CGPoint currentMouseLocation;
@property (assign) NSUInteger currentKeyModifiers;
@property (assign) NSUInteger currentButtonStates;

@end


@implementation FakeContext

+ (BOOL)supportsAntiAliasing
{
   return YES;
}

- (instancetype)init
{
   if (self = [super init]) {
       _backend = 0; // Default backend
       _rendersOffScreen = NO;
       _framebufferBits = 32; // Common default
       _compositionMode = 0; // Default composition mode
       _frameCounter = 0;
       _isActiveFlag = NO;
       _initializedFramebuffer = NO;
       _graphicsShareID = 1;

       // Default mouse/input values
       _currentMouseLocation = CGPointZero;
       _currentKeyModifiers = 0;
       _currentButtonStates = 0;

       // Initialize input state to zeros
       memset(&_inputState, 0, sizeof(struct UIInputState));
   }
   return self;
}

- (instancetype) initWithOSGraphicsContext:(id <UIOSGraphicsContext>) osContext
                            nameUTF8String:(char *) nameUTF8String
                                   shareID:(NSUInteger)shareID
                                   options:(UIGraphicsOptions)options
{
   if (self = [super init]) {
       _backend = [osContext backend];
       _graphicsShareID = shareID;
       _graphicsOptions = options;
       _rendersOffScreen = NO;
       _framebufferBits = 32;
       _compositionMode = 0;
       _frameCounter = 0;
       _isActiveFlag = NO;
       _initializedFramebuffer = NO;

       // Default mouse/input values
       _currentMouseLocation = CGPointZero;
       _currentKeyModifiers = 0;
       _currentButtonStates = 0;

       // Initialize input state to zeros
       memset(&_inputState, 0, sizeof(struct UIInputState));
   }
   return self;
}

- (instancetype) initWithOSGraphicsContext:(id <UIOSGraphicsContext>) os_context
                                   shareID:(NSUInteger) shareID
                                   options:(UIGraphicsOptions) options
{
   return( [self initWithOSGraphicsContext:os_context
                            nameUTF8String:NULL
                                   shareID:shareID
                                   options:options]);
}

- (char *)backendUTF8String
{
   static char openglString[] = "OpenGL";
   static char metalString[] = "Metal";
   static char vulkanString[] = "Vulkan";
   static char unknownString[] = "Unknown";

   switch (_backend) {
       case 1: return openglString;
       case 2: return metalString;
       case 3: return vulkanString;
       default: return unknownString;
   }
}

- (void)setActive:(BOOL)flag
{
   _isActiveFlag = flag;
   _activeThread = flag ? [NSThread currentThread] : nil;
}

- (BOOL)isActive
{
   return _isActiveFlag;
}

- (BOOL) needsFramebufferClear
{
   return( YES);
}

- (NSThread *)activeThread
{
   return _activeThread;
}

- (void)clearFramebufferNoColor
{
   // Fake implementation - would clear depth/stencil but not color
}

- (void)clearFramebufferWithHexColor:(NSUInteger)color
{
   // Fake implementation - would clear framebuffer to specified color
}

- (void)useDefaultFont
{
   // Fake implementation
}

- (void)beginRender:(struct CGFrameInfo *)info
{
   // Start rendering, just track state for testing
}

- (void)drawObjects:(struct mulle_pointerarray *)array
{
   // Fake draw objects implementation
}

- (void)suspendRender
{
   // Fake implementation
}

- (void)resumeRender
{
   // Fake implementation
}

- (void)_endRender
{
   _frameCounter++;
}

- (void)endRender
{
   [self suspendRender];
   [self _endRender];
}

- (void)reset
{
   // Reset state for testing
   _compositionMode = 0;
   memset(&_inputState, 0, sizeof(struct UIInputState));
}

- (id)acquireOffscreenFramebuffer MULLE_OBJC_THREADSAFE_METHOD
{
   // Return a dummy framebuffer
   return @"DummyFramebuffer";
}

- (BOOL)recycleFramebuffer:(id)layer MULLE_OBJC_THREADSAFE_METHOD
{
   // Fake implementation
   return YES;
}

- (struct CGBitmap)readFramebufferBitmap:(CGPixelRect)rect
                  framebufferBitmapType:(CGFramebufferBitmapType)type
                              allocator:(struct mulle_allocator *)allocator
{
   // Create a proper CGBitmap based on the structure from x.h
   struct CGBitmapInfo info;
   struct CGBitmap bitmap;
   void *bytes;
   NSInteger pixelSize = 4; // Assuming RGBA format

   // Set up the bitmap info with correct pixel size and encoding
   info.size = rect.size;
   info.stride = rect.size.width * pixelSize;
   info.encoding = CGBitmapEncodingRGBABytes; // Standard RGBA format

   // Allocate memory for the bitmap
   NSUInteger allocationSize = CGBitmapInfoGetAllocationLength(info);
   if (allocator) {
       bytes = mulle_allocator_calloc(allocator, 1, allocationSize);
   } else {
       bytes = calloc(1, allocationSize);
   }

   // Initialize the bitmap structure
   bitmap.bytes = bytes;
   bitmap.info = info;
   bitmap.allocator = allocator;

   return bitmap;
}

- (void)barrier
{
  // Fake implementation for sync/barrier
}

- (NSUInteger)numberOfFrames
{
  return _frameCounter;
}

- (struct CGBitmap)framebufferBitmap
{
   // Create a full-screen bitmap
   struct CGPixelSize size = CGPixelSizeMake(800, 600); // Default size
   struct CGPixelRect rect = CGPixelRectMake(0, 0, size.width, size.height);
   return [self readFramebufferBitmap:rect framebufferBitmapType:0 allocator:NULL];
}

- (void)setCompositionMode:(UIGraphicsCompositionMode)mode
{
   _compositionMode = mode;
}

- (void)drawBitmap:(struct CGBitmap)fb
{
   // Fake bitmap drawing
}

- (void)drawRect:(CGRect)rect
          image:(id)image
          scale:(BOOL)scale
{
   // Fake rect drawing
}

- (id<UIImage>) imageWithFramebuffer:(id<UIFramebuffer>)layer
                      nameUTF8String:(char *) nameUTF8String
{
   // Return nil or a dummy image
   return nil;
}

- (CGPoint)mouseLocation
{
   return _currentMouseLocation;
}

- (NSUInteger)keyModifiers
{
   return _currentKeyModifiers;
}

- (NSUInteger)buttonStates
{
   return _currentButtonStates;
}

@end


@implementation UIPureWindow( UIApplicationGlue)

+ (Class) osWindowClass
{
   return( [FakeOSWindow class]);
}


+ (Class) osGraphicsContextClass
{
   return( [FakeContext class]);
}


+ (NSUInteger) osGraphicsHints
{
   return( 0);
}

@end


@implementation UIApplication( Mockery)

- (void) os_sendEmptyEvent
{
}

@end

@interface FakeApplication : NSObject
{
   id <UIOSWindow>     _keyOSWindow;
   struct mulle_array  _windows;
}

+ (FakeApplication *) sharedInstance;
- (void) setOSKeyWindow:(id <UIOSWindow>) window;
- (id <UIOSWindow>) osKeyWindow;
- (void) addWindow:(UIPureWindow *) window;
- (void) os_waitEventsWithTimeout:(mulle_relativetime_t) timeout;
- (id <UIScreen>) primaryScreen;
@end

@implementation FakeApplication

+ (FakeApplication *) sharedInstance
{
   return [FakeApplication object];
}

- (id) init
{
   if (self = [super init]) {
      mulle_array_init( &_windows, 0, &MulleObjCContainerRetainKeyCallback, NULL);
   }
   return self;
}


- (void) dealloc
{
   mulle_array_done( &_windows);
   [super dealloc];
}

- (void) setOSKeyWindow:(id <UIOSWindow>) window
{
   _keyOSWindow = window;
}

- (id <UIOSWindow>) osKeyWindow
{
   return _keyOSWindow;
}

- (void) addWindow:(UIPureWindow *) window
{
   if (!window) return;

   mulle_array_add( &_windows, window);
   // This is the critical part - connect the window to the application
   [window applicationDidAddWindow:(UIApplication *) self];
}

- (void) os_waitEventsWithTimeout:(mulle_relativetime_t) timeout
{
   // Mock implementation - doesn't actually wait
   // Just a stub to satisfy the assertion in UIPureWindow+OneFrame.m
}

- (id <UIScreen>) primaryScreen
{
   // Return a basic fake screen
   return nil; // For simplicity - could implement FakeUIScreen if needed
}

@end

