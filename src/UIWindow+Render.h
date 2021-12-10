//
// Copyright (c) 2021 Nat!, Mulle kybernetiK
//

#import "UIWindow.h"

@class CGContext;


@interface UIWindow( Render)

- (void) renderLoop;
- (BOOL) renderUpToNumberOfFrames:(NSUInteger) maxFrames;
- (void) renderFrame:(struct CGFrameInfo *) info;
- (BOOL) renderFrameWaitForNeedsDisplay;

- (void) addToDelegateViews:(UIView *) view;
- (void) removeFromDelegateViews:(UIView *) view;

- (void) getFrameInfo:(struct CGFrameInfo *) info;

- (id <UIOSGraphicsContext>) activateWindowGraphicsContext;
- (void) deactivateWindowGraphicsContext:(id <UIOSGraphicsContext>) context;
- (id <UIOSGraphicsContext>) activateRenderGraphicsContext;
- (void) deactivateRenderGraphicsContext:(id <UIOSGraphicsContext>) context;

- (void) swapBuffers;

// this will activate the window context!
- (struct CGFramebufferBitmap)
   lastRenderedFramebufferBitmapType:(enum CGFramebufferBitmapType) type
                            inFlight:(BOOL) inFlight
                           allocator:(struct mulle_allocator *) allocator;
@end

