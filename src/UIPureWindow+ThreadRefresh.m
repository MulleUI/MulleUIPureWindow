//
// Copyright (c) 2022 Nat!, Mulle kybernetiK
//
#define _GNU_SOURCE

#import "UIPureWindow+ThreadRefresh.h"

#import "import-private.h"

#import "UIPureWindow+DebugPrivate.h"
#import "UIPureWindow+Frame.h"
#import "UIPureWindow+FrameInfo.h"
#import "UIPureWindow+Render.h"
#import "UIPureWindow+UIGraphicsContext.h"

/////// If we acquire a framebuffer from the other context, then we will get it
/////// autoreleased into our context. We must create a shared image from it.
/////// (already have the code for that). The problem in general is, that the
/////// Layer may get either finalized in this thread or the originator thread.
/////// Since it is thread-affine, there maybe a complaint.


//#define MISSING_BARRIER_DEBUG



@implementation UIPureWindow ( ThreadRefresh)


// ** THIS PART IS RUNNING IN THE MAIN THREAD ***
// The refresh is called during event window refresh and in the main
// loop when a refresh is needed for thread windows.
// The main loop redraw does not refresh.
// The actual caller is usually -displayFrameIfNeeded: which does:
//
//  if( needsRefresh)
//  {
//     [self refresh];
//     [self swapBuffers];
//  }
//
- (void) refresh
{
   BOOL                     isScaling;
   NSUInteger               color;
   CGRect                   imageFrame;
   CGRect                   rect;
   CGSize                   imageSize;
   id <UIGraphicsContext>   context;
   id <UIImage>             image;
   id <UIFramebuffer>       framebuffer;
   CGContentMode            refreshContentMode;
   struct CGFrameInfo       frameInfo;

   assert( [NSThread mulleIsMainThread]);
   assert( _backingStore != UIWindowBackingStoreVolatile);

   @autoreleasepool
   {
      context = [self activateWindowGraphicsContext];

      // TODO: voodoo barrier, should be useless
      // [_offscreenContext barrier];
      framebuffer = [_offscreenContext acquireOffscreenFramebuffer];
      if( framebuffer)
      {
         UIWindowSwapLog( "Acquired freshly drawn framebuffer %#@", framebuffer);
         // recycle our old framebuffer
         assert( _lastOffscreenFramebuffer != framebuffer);

         UIWindowSwapLog( "Recycle old framebuffer %#@", _lastOffscreenFramebuffer);
         [_offscreenContext recycleFramebuffer:_lastOffscreenFramebuffer];

         [_lastOffscreenFramebuffer autorelease];
         _lastOffscreenFramebuffer = [framebuffer retain];
      }
      else
      {
         // TODO: what happens if the render thread finalized this framebuffer ?
         //       should be OK, since we share the texture or ?

         // if we still have a framebuffer, use it
         framebuffer = _lastOffscreenFramebuffer;
         if( ! framebuffer)
         {
            UIWindowSwapLog( "There is nothing to display (yet ?)");
            return;
         }
         UIWindowSwapLog( "Reuse previously acquired offscreen framebuffer %#@", framebuffer);
      }

      //
      // MEMO: OK we got a framebuffer, but we can't do anything with it. It's
      // a CGImage but it's from a different context. But we can make a CGImage
      // in our context with it.
      // TODO: why do we not immediately recycle the framebuffer, once we got
      // an image from it ? Gotta explain better that CGImage is always single
      // threaded. And how we are sharing the GPU texture here from a different
      // context.
      //
      @autoreleasepool // THIS IS IMPORTANT TO COLLECT CGLAYERS WHILE CONTEXT IS ALIVE
      {
         [self getFrameInfo:&frameInfo];

         UIWindowSwapLog( "Begin render");
         // TODO: voodoo barrier, possibly useless
         // [context barrier];
         [context beginRender:&frameInfo];

         refreshContentMode = [self refreshContentMode];
         isScaling          = CGContentModeIsScaling( refreshContentMode);
         if( ! isScaling)
         {
            color = [self backgroundHexColor];
            [context clearFramebufferWithHexColor:color];
         }

         rect.origin = CGPointZero;
         rect.size   = frameInfo.window.frame.size;
         image       = [context imageWithFramebuffer:framebuffer];
         assert( image);
         imageSize   = [image size];
         imageFrame  = CGSizePlaceInRect( imageSize, rect, refreshContentMode);

#ifdef MISSING_BARRIER_DEBUG
         {
            id   bitmapImage;

            bitmapImage = [image bitmapImage];
            if( [bitmapImage isFullyTransparent])
            {
               fprintf( stderr, "missing barrier ?\n");
               abort();
            }
         }
#endif
         UIWindowSwapLog( "Refresh with image %#@", image);

         // this can likely transfer directly into the framebuffer, any nvg
         // drawing issued before (and after) will appear on top of it
         // in other words: DO NOT emit drawing code before this. Afterwards it
         // is OK.
         [(id <UIGraphicsDrawing>) context blitRect:imageFrame
                                              image:image
                                              scale:isScaling];

         if( _debuggingFlags & UIWindowDebugFramebufferIdRect)
         {
            if( [context conformsToProtocol:@protocol( UIGraphicsDrawing)])
            {
               rect = CGRectInset( rect, 20, 20);
               [(id <UIGraphicsDrawing>) context strokeRect:rect
                                                strokeWidth:4.0
                                                   hexColor:0x20A080FF];
            }
         }

         if( _debuggingFlags & UIWindowDebugDumpFrameToFile)
         {
            MulleUIWriteImageToPNGFileSequenceAsync( image, "refresh-image");
            // Can't do this as framebuffer owned by other thread really
            // MulleUIWriteImageToPNGFileSequenceAsync( framebuffer, "refresh-framebuffer");
         }

         UIWindowSwapLog( "Drew image %#@ of size %.1f %.1f into %.1f %.1f %.1f %.1f for refresh",
                           image,
                           imageSize.width, imageSize.height,
                           imageFrame.origin.x, imageFrame.origin.y,
                           imageFrame.size.width, imageFrame.size.height);
         [context endRender];
         UIWindowSwapLog( "Finished render");
      }
      UIWindowSwapLog( "AutoreleasePool cleaned");
   }
   [self deactivateGraphicsContext:context];
}

@end
