
// Enable with environment variable "UIWindowDebuggingFlags" like so
//
//    UIWindowDebuggingFlags=0xNNNN  ./mx-project.ext
// or
//    mulle-sde -DUIWindowDebuggingFlags=0x40 -DNSZombieEnabled=YES debug demo1
//
enum
{
   UIWindowDebug                   = 0x00000001, // UIViewDebug,      // 0x00000001
   UIWindowDebugEvent              = 0x00000002, //UIViewDebugEvent, // 0x00000002

   UIWindowDebugLayout             = 0x00000004, // UIViewDebugLayout, // 0x00000004
   UIWindowDebugRender             = 0x008,
   UIWindowDebugThread             = 0x010,

   UIWindowDebugWindowEvent        = 0x020,

   UIWindowDebugDisplayBits        = 0x040,
   UIWindowDebugRefreshBits        = 0x080,

   UIWindowDebugBackend            = 0x100,
   // 0x200
   UIWindowDebugSwap               = 0x0400,
   UIWindowDebugResource           = 0x0800,  // MulleUIResourceMap

   UIWindowDebugVerbose            = 0x00001000, // UIViewDebugVerbose,      // 0x00001000
   UIWindowDebugEventVerbose       = 0x00002000, // UIViewDebugEventVerbose, // 0x00002000
   UIWindowDebugRenderVerbose      = 0x008000,
   UIWindowDebugThreadVerbose      = 0x010000,

   // 0x020000
   // 0x040000
   // 0x080000
   // 0x100000
   // 0x200000
   // 0x400000
   // 0x800000

   UIWindowDebugMouseMotionEvent   = 0x01000000, // UIViewDebugMouseMotionEvent,   // 0x01000000
   UIWindowDebugMouseTrackingEvent = 0x02000000, // UIViewDebugMouseTrackingEvent, // 0x02000000

   UIWindowDebugDumpFrameToFile    = 0x08000000,
   UIWindowDebugRenderDisplayBits  = 0x10000000,
   UIWindowDebugFramebufferIdRect  = 0x20000000,
   UIWindowDebugRenderFrameInfo    = 0x40000000,
   UIWindowAbortOnEventOverflow    = 0x80000000,
};


@interface NSObject ( UIPureWindow)

- (BOOL) __isUIPureWindow   MULLE_OBJC_THREADSAFE_METHOD;

@end



#if ! defined( UI_WINDOW_LOG_DISABLED)

#define UIWindowLog( format, ...)                                           \
do                                                                          \
{                                                                           \
   assert( [self __isUIPureWindow]);                                        \
   if( self->_debuggingFlags & UIWindowDebug)                               \
      mulleui_log_object_method( self, (char *) __PRETTY_FUNCTION__,        \
                                       (char *) format, ## __VA_ARGS__);    \
}                                                                           \
while( 0)

#define UIWindowLogVerbose( format, ...)                                    \
do                                                                          \
{                                                                           \
   assert( [self __isUIPureWindow]);                                        \
   if( self->_debuggingFlags & UIWindowDebugVerbose)                        \
      mulleui_log_object_method( self, (char *) __PRETTY_FUNCTION__,        \
                                       (char *) format, ## __VA_ARGS__);    \
}                                                                           \
while( 0)


#define UIWindowRenderLog( format, ...)                                     \
do                                                                          \
{                                                                           \
   assert( [self __isUIPureWindow]);                                        \
   if( self->_debuggingFlags & UIWindowDebugRender)                         \
      mulleui_log_object_method( self, (char *) __PRETTY_FUNCTION__,        \
                                       (char *) format, ## __VA_ARGS__);    \
}                                                                           \
while( 0)

#define UIWindowRenderLogVerbose( format, ...)                              \
do                                                                          \
{                                                                           \
   assert( [self __isUIPureWindow]);                                        \
   if( self->_debuggingFlags & UIWindowDebugRenderVerbose)                  \
      mulleui_log_object_method( self, (char *) __PRETTY_FUNCTION__,        \
                                       (char *) format, ## __VA_ARGS__);    \
}                                                                           \
while( 0)

#define UIWindowThreadLog( format, ...)                                     \
do                                                                          \
{                                                                           \
   assert( [self __isUIPureWindow]);                                        \
   if( self->_debuggingFlags & UIWindowDebugThread)                         \
      mulleui_log_object_method( self, (char *) __PRETTY_FUNCTION__,        \
                                       (char *) format, ## __VA_ARGS__);    \
}                                                                           \
while( 0)


#define UIWindowLayoutLog( format, ...)                                     \
do                                                                          \
{                                                                           \
   assert( [self __isUIPureWindow]);                                        \
   if( self->_debuggingFlags & UIWindowDebugLayout)                         \
      mulleui_log_object_method( self, (char *) __PRETTY_FUNCTION__,        \
                                       (char *) format, ## __VA_ARGS__);    \
}                                                                           \
while( 0)

#define UIWindowThreadLogVerbose( format, ...)                              \
do                                                                          \
{                                                                           \
   assert( [self __isUIPureWindow]);                                        \
   if( self->_debuggingFlags & UIWindowDebugThreadVerbose)                  \
      mulleui_log_object_method( self, (char *) __PRETTY_FUNCTION__,        \
                                       (char *) format, ## __VA_ARGS__);    \
}                                                                           \
while( 0)


#define UIWindowSwapLog( format, ...)                                       \
do                                                                          \
{                                                                           \
   assert( [self __isUIPureWindow]);                                        \
   if( self->_debuggingFlags & UIWindowDebugSwap)                           \
      mulleui_log_object_method( self, (char *) __PRETTY_FUNCTION__,        \
                                       (char *) format, ## __VA_ARGS__);    \
}                                                                           \
while( 0)


#define UIWindowDisplayBitsLog( format, ...)                                \
do                                                                          \
{                                                                           \
   assert( [self __isUIPureWindow]);                                        \
   if( self->_debuggingFlags & UIWindowDebugDisplayBits)                    \
      mulleui_log_object_method( self, (char *) __PRETTY_FUNCTION__,        \
                                       (char *) format, ## __VA_ARGS__);    \
}                                                                           \
while( 0)

#define UIWindowRefreshBitsLog( format, ...)                                \
do                                                                          \
{                                                                           \
   assert( [self __isUIPureWindow]);                                        \
   if( self->_debuggingFlags & UIWindowDebugRefreshBits)                    \
      mulleui_log_object_method( self, (char *) __PRETTY_FUNCTION__,        \
                                       (char *) format, ## __VA_ARGS__);    \
}                                                                           \
while( 0)


#define UIWindowEventLog( event, format, ...)                               \
do                                                                          \
{                                                                           \
   assert( [self __isUIPureWindow]);                                        \
   if( self->_debuggingFlags & UIWindowDebugEvent)                          \
      if( ! event || ([event eventType] & ~(UIEventTypeMotion|UIEventTypeTracking)))     \
         mulleui_log_object_method( self, (char *) __PRETTY_FUNCTION__,     \
                                          (char *) format, ## __VA_ARGS__); \
}                                                                           \
while( 0)


#define UIWindowEventLogVerbose( event, format, ...)                        \
do                                                                          \
{                                                                           \
   assert( [self __isUIPureWindow]);                                        \
   if( self->_debuggingFlags & UIWindowDebugEventVerbose)                   \
      if( ! event || ([event eventType] & ~(UIEventTypeMotion|UIEventTypeTracking)))     \
         mulleui_log_object_method( self, (char *) __PRETTY_FUNCTION__,     \
                                          (char *) format, ## __VA_ARGS__); \
}                                                                           \
while( 0)

#define UIWindowMouseTrackingEventLog( event, format, ...)                  \
do                                                                          \
{                                                                           \
   assert( [self __isUIPureWindow]);                                        \
   if( self->_debuggingFlags & UIWindowDebugMouseTrackingEvent)             \
      if( ! event || [event eventType] == UIEventTypeTracking)              \
         mulleui_log_object_method( self, (char *) __PRETTY_FUNCTION__,     \
                                          (char *) format, ## __VA_ARGS__); \
}                                                                           \
while( 0)


#define UIWindowMouseMotionEventLog( event, format, ...)                    \
do                                                                          \
{                                                                           \
   assert( [self __isUIPureWindow]);                                        \
   if( self->_debuggingFlags & UIWindowDebugMouseMotionEvent)               \
      if( ! event || [event eventType] == UIEventTypeMotion)                \
         mulleui_log_object_method( self, (char *) __PRETTY_FUNCTION__,     \
                                          (char *) format, ## __VA_ARGS__); \
}                                                                           \
while( 0)

#define UIWindowWindowEventLog( format, ...)                                \
do                                                                          \
{                                                                           \
   assert( [self __isUIPureWindow]);                                        \
   if( self->_debuggingFlags & UIWindowDebugWindowEvent)                    \
      mulleui_log_object_method( self, (char *) __PRETTY_FUNCTION__,        \
                                       (char *) format, ## __VA_ARGS__);    \
}                                                                           \
while( 0)


#else

#define UIWindowLog( format, ...)                           do {} while( 0)
#define UIWindowLogVerbose( format, ...)                    do {} while( 0)
#define UIWindowRenderLog( format, ...)                     do {} while( 0)
#define UIWindowRenderLogVerbose( format, ...)              do {} while( 0)
#define UIWindowThreadLog( format, ...)                     do {} while( 0)
#define UIWindowThreadLogVerbose( format, ...)              do {} while( 0)
#define UIWindowSwapLog( format, ...)                       do {} while( 0)
#define UIWindowDisplayBitsLog( format, ...)                do {} while( 0)
#define UIWindowRefreshBitsLog( format, ...)                do {} while( 0)
#define UIWindowEventLog( event, format, ...)               do {} while( 0)
#define UIWindowEventLogVerbose( event, format, ...)        do {} while( 0)
#define UIWindowMouseTrackingEventLog( event, format, ...)  do {} while( 0)
#define UIWindowMouseMotionEventLog( event, format, ...)    do {} while( 0)
#define UIWindowWindowEventLog( format, ...)                do {} while( 0)

#endif


