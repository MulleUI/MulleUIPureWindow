//
//  UIPureWindow+ThreadRefresh.m
//  MulleUIPureWindow
//
//  Copyright (c) 2025 Nat! - Mulle kybernetiK.
//  All rights reserved.
//
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  Redistributions of source code must retain the above copyright notice, this
//  list of conditions and the following disclaimer.
//
//  Redistributions in binary form must reproduce the above copyright notice,
//  this list of conditions and the following disclaimer in the documentation
//  and/or other materials provided with the distribution.
//
//  Neither the name of Mulle kybernetiK nor the names of its contributors
//  may be used to endorse or promote products derived from this software
//  without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
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
//     if( [self refresh])
//        [self swapBuffers];
//  }
//
- (BOOL) refresh
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
   char                     *nameUTF8String;
   char                     *s;

   MulleWindowProfileBegin();

   assert( [NSThread mulleIsMainThread]);
   assert( _backingStore != UIWindowBackingStoreVolatile);

   @autoreleasepool
   {
      context = [self activateWindowGraphicsContext];
      assert( context == _context);

      // TODO: voodoo barrier, should be useless
      // [_offscreenContext barrier];
      framebuffer = [_offscreenContext acquireRenderedFramebuffer];
      if( framebuffer)
      {
         UIWindowSwapLog( "Acquired freshly drawn framebuffer %#@", framebuffer);
         [self setLastOffscreenFramebuffer:framebuffer];
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
            [self deactivateGraphicsContext:context];
            MulleWindowProfileEnd();
            return( NO);  // cold indicate "no need to swap" here
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
         {
            refreshContentMode = [self refreshContentMode];
            isScaling          = CGContentModeIsScaling( refreshContentMode);
            if( ! isScaling)
            {
               color = [self backgroundHexColor];
               [context clearFramebufferWithHexColor:color];
            }

            rect.origin = CGPointZero;
            rect.size   = frameInfo.window.frame.size;
#ifdef DEBUG
            {
               static NSUInteger   counter;  // just for debugging

               nameUTF8String = MulleObjC_asprintf( "%s refresh image #%td", [self titleUTF8String], counter++);
            }
#else
            nameUTF8String = NULL;
#endif
            image      = [context imageWithFramebuffer:framebuffer
                                        nameUTF8String:nameUTF8String];
            imageSize  = [image size];
            imageFrame = CGSizePlaceInRect( imageSize, rect, refreshContentMode);
            assert( image);
            assert( [image performSelector:@selector( context)] == context);

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
               mulle_buffer_do( buffer)
               {
                  mulle_buffer_add_string( buffer, "refresh-image");
                  s = [self titleUTF8String];
                  if( *s)
                  {
                     mulle_buffer_add_char( buffer, '-');
                     mulle_buffer_slugify_utf8data( buffer, mulle_utf8data_make( s, -1));
                  }
                  MulleUIWriteImageToPNGFileSequenceAsync( image, mulle_buffer_get_string( buffer));
               }
               // Can NOT dump "framebuffer" here as it's owned (thread affine)
               // to the render thread, not this (calling) thread. "image" is
               // the CGImage just blitted into our own window context, so
               // it's safe.
            }

            UIWindowSwapLog( "Drew image %#@ of size %.1f %.1f into %.1f %.1f %.1f %.1f for refresh",
                              image,
                              imageSize.width, imageSize.height,
                              imageFrame.origin.x, imageFrame.origin.y,
                              imageFrame.size.width, imageFrame.size.height);
         }
         [context endRender];
         UIWindowSwapLog( "Finished render");
      }
      UIWindowSwapLog( "AutoreleasePool cleaned");
   }
   [self deactivateGraphicsContext:context];

   MulleWindowProfileEnd();
   return( YES);
}


- (void) setLastOffscreenFramebuffer:(id <UIFramebuffer>) framebuffer
{
   // recycle our old framebuffer
   assert( ! framebuffer || _lastOffscreenFramebuffer != framebuffer);

   // when we recycle the old framebuffer, the framebuffer can then
   // be picked up and overwritten again by the other thread. What could
   // possibly go wrong ? If for some reason the "blit" below has not
   // yet completed, there might be ugliness as the old framebuffer
   // contents are cleared. I deem this as a) super-super unlikely
   // b) acceptable. I mean you have to run with a framerate of 1000s and
   // the blit has to be slower than two frames of rendering...
   [_offscreenContext recycleAcquiredRenderedFramebuffer:_lastOffscreenFramebuffer];
   [_lastOffscreenFramebuffer autorelease];
   _lastOffscreenFramebuffer = [framebuffer retain];
}

@end
