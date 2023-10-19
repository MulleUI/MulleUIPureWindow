#import <MulleUIView/UIView+DebugPrivate.h>


enum
{
   UIWindowDebug                  = UIViewDebug,
   UIWindowDebugVerbose           = UIViewDebugVerbose,

   UIWindowDebugRender            = 0x004,
   UIWindowDebugRenderVerbose     = 0x004000,
   UIWindowDebugThread            = 0x008,
   UIWindowDebugThreadVerbose     = 0x008000,
   UIWindowDebugSwap              = 0x010,
   UIWindowDebugDisplayBits       = 0x040,
   UIWindowDebugRefreshBits       = 0x080,

   UIWindowDebugEvent             = UIViewDebugEvent,
   UIWindowDebugEventVerbose      = UIViewDebugEventVerbose,
   UIWindowDebugMouseMotionEvent  = UIViewDebugMouseMotionEvent,
   UIWindowDebugWindowEvent       = 0x020,

   UIWindowDebugDumpFrameToFile   = 0x08000000,
   UIWindowDebugRenderDisplayBits = 0x10000000,
   UIWindowDebugFramebufferIdRect = 0x20000000,
   UIWindowDebugRenderFrameInfo   = 0x40000000,
   UIWindowAbortOnEventOverflow   = 0x80000000,
};


@interface NSObject ( UIWindow)

- (BOOL) __isUIWindow;

@end



#if ! defined( UI_WINDOW_DEBUG_DISABLED)

#define UIWindowLog( format, ...)                                           \
do                                                                          \
{                                                                           \
   assert( [self __isUIWindow]);                                            \
   if( self->_debugEnabled & UIWindowDebug)                                 \
      mulleui_log_object_method( self, (char *) __PRETTY_FUNCTION__,        \
                                       (char *) format, ## __VA_ARGS__);    \
}                                                                           \
while( 0)

#define UIWindowLogVerbose( format, ...)                                    \
do                                                                          \
{                                                                           \
   assert( [self __isUIWindow]);                                            \
   if( self->_debugEnabled & UIWindowDebugVerbose)                          \
      mulleui_log_object_method( self, (char *) __PRETTY_FUNCTION__,        \
                                       (char *) format, ## __VA_ARGS__);    \
}                                                                           \
while( 0)


#define UIWindowRenderLog( format, ...)                                     \
do                                                                          \
{                                                                           \
   assert( [self __isUIWindow]);                                            \
   if( self->_debugEnabled & UIWindowDebugRender)                           \
      mulleui_log_object_method( self, (char *) __PRETTY_FUNCTION__,        \
                                       (char *) format, ## __VA_ARGS__);    \
}                                                                           \
while( 0)

#define UIWindowRenderLogVerbose( format, ...)                              \
do                                                                          \
{                                                                           \
   assert( [self __isUIWindow]);                                            \
   if( self->_debugEnabled & UIWindowDebugRenderVerbose)                    \
      mulleui_log_object_method( self, (char *) __PRETTY_FUNCTION__,        \
                                       (char *) format, ## __VA_ARGS__);    \
}                                                                           \
while( 0)

#define UIWindowThreadLog( format, ...)                                     \
do                                                                          \
{                                                                           \
   assert( [self __isUIWindow]);                                            \
   if( self->_debugEnabled & UIWindowDebugThread)                           \
      mulleui_log_object_method( self, (char *) __PRETTY_FUNCTION__,        \
                                       (char *) format, ## __VA_ARGS__);    \
}                                                                           \
while( 0)

#define UIWindowThreadLogVerbose( format, ...)                              \
do                                                                          \
{                                                                           \
   assert( [self __isUIWindow]);                                            \
   if( self->_debugEnabled & UIWindowDebugThreadVerbose)                    \
      mulleui_log_object_method( self, (char *) __PRETTY_FUNCTION__,        \
                                       (char *) format, ## __VA_ARGS__);    \
}                                                                           \
while( 0)


#define UIWindowSwapLog( format, ...)                                       \
do                                                                          \
{                                                                           \
   assert( [self __isUIWindow]);                                            \
   if( self->_debugEnabled & UIWindowDebugSwap)                             \
      mulleui_log_object_method( self, (char *) __PRETTY_FUNCTION__,        \
                                       (char *) format, ## __VA_ARGS__);    \
}                                                                           \
while( 0)


#define UIWindowDisplayBitsLog( format, ...)                                \
do                                                                          \
{                                                                           \
   assert( [self __isUIWindow]);                                            \
   if( self->_debugEnabled & UIWindowDebugDisplayBits)                      \
      mulleui_log_object_method( self, (char *) __PRETTY_FUNCTION__,        \
                                       (char *) format, ## __VA_ARGS__);    \
}                                                                           \
while( 0)

#define UIWindowRefreshBitsLog( format, ...)                                \
do                                                                          \
{                                                                           \
   assert( [self __isUIWindow]);                                            \
   if( self->_debugEnabled & UIWindowDebugRefreshBits)                      \
      mulleui_log_object_method( self, (char *) __PRETTY_FUNCTION__,        \
                                       (char *) format, ## __VA_ARGS__);    \
}                                                                           \
while( 0)


#define UIWindowEventLog( event, format, ...)                               \
do                                                                          \
{                                                                           \
   assert( [self __isUIWindow]);                                            \
   if( self->_debugEnabled & UIWindowDebugEvent)                            \
      if( [event eventType] != UIEventTypeMotion)                           \
         mulleui_log_object_method( self, (char *) __PRETTY_FUNCTION__,     \
                                          (char *) format, ## __VA_ARGS__); \
}                                                                           \
while( 0)


#define UIWindowEventLogVerbose( event, format, ...)                        \
do                                                                          \
{                                                                           \
   assert( [self __isUIWindow]);                                            \
   if( self->_debugEnabled & UIWindowDebugEventVerbose)                     \
      if( [event eventType] != UIEventTypeMotion)                           \
         mulleui_log_object_method( self, (char *) __PRETTY_FUNCTION__,     \
                                          (char *) format, ## __VA_ARGS__); \
}                                                                           \
while( 0)

#define UIWindowMouseMotionEventLog( event, format, ...)                    \
do                                                                          \
{                                                                           \
   assert( [self __isUIWindow]);                                            \
   if( self->_debugEnabled & UIWindowDebugMouseMotionEvent)                 \
      if( [event eventType] == UIEventTypeMotion)                           \
         mulleui_log_object_method( self, (char *) __PRETTY_FUNCTION__,     \
                                          (char *) format, ## __VA_ARGS__); \
}                                                                           \
while( 0)

#define UIWindowWindowEventLog( format, ...)                                \
do                                                                          \
{                                                                           \
   assert( [self __isUIWindow]);                                            \
   if( self->_debugEnabled & UIWindowDebugWindowEvent)                      \
      mulleui_log_object_method( self, (char *) __PRETTY_FUNCTION__,        \
                                       (char *) format, ## __VA_ARGS__);    \
}                                                                           \
while( 0)


#else

#define UIWindowLog( format, ...)                         do {} while( 0)
#define UIWindowLogVerbose( format, ...)                  do {} while( 0)
#define UIWindowRenderLog( format, ...)                   do {} while( 0)
#define UIWindowRenderLogVerbose( format, ...)            do {} while( 0)
#define UIWindowThreadLog( format, ...)                   do {} while( 0)
#define UIWindowThreadLogVerbose( format, ...)            do {} while( 0)
#define UIWindowSwapLog( format, ...)                     do {} while( 0)
#define UIWindowDisplayBitsLog( format, ...)              do {} while( 0)
#define UIWindowRefreshBitsLog( format, ...)              do {} while( 0)
#define UIWindowEventLog( event, format, ...)             do {} while( 0)
#define UIWindowEventLogVerbose( event, format, ...)      do {} while( 0)
#define UIWindowMouseMotionEventLog( event, format, ...)  do {} while( 0)
#define UIWindowWindowEventLog( format, ...)              do {} while( 0)

#endif


