//
// Copyright (c) 2020 Nat!, Mulle kybernetiK
//
// prefer a local UIView over one in import.h
#import "import.h"


@interface UIView( RenderQueue)

// all layers (are placed into the render queue, the layers get their
// transform and alpha set
- (void) createRenderQueue:(struct mulle_pointerarray *) renderQueue;

- (void) dumpRenderQueue:(struct mulle_pointerarray *) renderQueue;

@end

