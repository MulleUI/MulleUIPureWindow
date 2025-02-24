//
// Copyright (c) 2024 Nat!, Mulle kybernetiK
//
// prefer a local UIWindow over one in import.h
#ifdef __has_include
# if __has_include( "UIWindow.h")
#  import "UIWindow.h"
# endif
#endif

// we want "import.h" always anyway
#import "import.h"



@interface UIWindow( RenderQueue)

- (UIWindowDisplayBits) willRenderWithAbsoluteTime:(mulle_absolutetime_t) renderStart;

- (void) createDrawingQueueForFrame:(struct CGFrameInfo *) info;

- (void) createRenderQueue:(struct mulle_pointerarray *) renderQueue;

@end
