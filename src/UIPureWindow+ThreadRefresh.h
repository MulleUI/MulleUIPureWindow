//
// Copyright (c) 2022 Nat!, Mulle kybernetiK
//
// prefer a local UIWindow over one in import.h
#ifdef __has_include
# if __has_include( "UIPureWindow.h")
#  import "UIPureWindow.h"
# endif
#endif

// we want "import.h" always anyway
#import "import.h"


@interface UIPureWindow( ThreadRefresh)

- (void) refresh     MULLE_OBJC_THREADSAFE_METHOD;
- (void) setLastOffscreenFramebuffer:(id <UIFramebuffer>) framebuffer   MULLE_OBJC_THREADSAFE_METHOD;

@end

