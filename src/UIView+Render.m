//
// Copyright (c) 2021 Nat!, Mulle kybernetiK
//
#import "UIView+Render.h"

#import "import-private.h"

#import "UIView+RenderQueue.h"
#import <MulleUIView/UIView+DebugPrivate.h>


@implementation UIView ( Render)

- (void) renderInContext:(id <UIGraphicsContext>) context
{
   struct mulle_pointerarray   renderQueue;

   UIViewLog( "%#@", context);

   _mulle_pointerarray_init( &renderQueue, 0, NULL);

   @autoreleasepool
   {
      [self createRenderQueue:&renderQueue]; //
      [context drawObjects:&renderQueue];
   }

   _mulle_pointerarray_done( &renderQueue);
}

@end
