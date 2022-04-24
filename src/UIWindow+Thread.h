//
// Copyright (c) 2022 Nat!, Mulle kybernetiK
//
// prefer a local UIWindow over one in import.h
#ifdef __has_include
# if __has_include( "UIWindow.h")
#  import "UIWindow.h"
# endif
#endif

// we want "import.h" always anyway
#import "import.h"


@interface UIWindow( Thread)

- (void) initWindowThreadMainIfNeeded;
- (void) finalizeWindowThread;
- (void) wakeupWindowThread;
- (mulle_relativetime_t) windowThreadTimeoutIsAnimating:(BOOL) flag;

- (void) refresh;

@end

