//
// Copyright (c) 2021 Nat!, Mulle kybernetiK
//
#import "UIView+Render.h"

#import "import-private.h"

#import "UIView+RenderQueue.h"


@implementation UIView ( Render)

- (void) renderInContext:(id <UIOSGraphicsContext>) context
{
   struct mulle_pointerarray   renderQueue;

   assert( ![self needsLayout]);

   _mulle_pointerarray_init( &renderQueue, 0, NULL);

   @autoreleasepool
   {
      [self createRenderQueue:&renderQueue]; // 
      [context renderObjects:&renderQueue];
   }

   _mulle_pointerarray_done( &renderQueue);
}

@end
