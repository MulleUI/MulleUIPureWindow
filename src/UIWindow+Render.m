//
// Copyright (c) 2021 Nat!, Mulle kybernetiK
//
#define _GNU_SOURCE

#import "UIWindow.h"

#import "import-private.h"

#import "UIWindow+UIEvent.h"
#import "UIView+RenderQueue.h"


// #define LAYOUT_ANIMATIONS
//#define SWAP_DEBUG


@implementation UIWindow ( RenderingAddAllLayoutsToRenderQueue)

// can only be called from main thread :()
- (void) getFrameInfo:(struct CGFrameInfo *) info
{
   float      scale_x, scale_y;
   CGRect     rect;

   assert( info);

   // glfwGetWindowContentScale( _window, &scale_x, &scale_y);
   scale_x = 1.0;
   scale_y = 1.0;

   //
   // assumption is, the optimizing compiler will inline this with -O3
   // and then combine with settings
   //
   memset( info, 0, sizeof( *info));

   rect = CGRectIntegral( _frame);

   info->size               = _frame.size;
   info->framebufferSize    = _framebufferSize;
   info->viewportFrame.size = info->framebufferSize;

   info->UIScale            = CGVectorMake( scale_x, scale_y);
	info->pixelRatio         = info->framebufferSize.width / _frame.size.width;
   info->now                = mulle_timeinterval_now();
}


- (void) syncFrameAndFramebufferSizeWithOSWindow
{
   _frame           = [_os_window os_windowFrame];
   _framebufferSize = [_os_window os_framebufferSize];
}


// unused...
- (void) waitForEndOfResize
{
   double   waitEnd;

   //
   // keep viewport as is, so that resize scales the window
   // hopefully
   //
   for(;;)
   {
      waitEnd = glfwGetTime() + 1.0 / 5.0;
      glfwWaitEventsTimeout( 1.0 / 5.0);
      if( waitEnd >= glfwGetTime())
      {
         glViewport( 0.0, 0.0, _resizeSize.width, _resizeSize.height);
         _isResizing = NO;
         break;
      }
   }
}


- (CGFloat) primaryMonitorRefreshRate
{
   CGFloat   rate;

   rate = [_os_window os_primaryMonitorRefreshRate];
   if( rate == 0.0)
      return( 60.0);
   return( rate);
}


- (NSUInteger) processEvents:(CAAbsoluteTime) now
                   frameRate:(CGFloat) frameRate
{
   CARelativeTime   timeout;

   // Four cases:
   // UIWindowFrameRateUnsynced (0.0), UIWindowFrameRateAsync (INFINITE)
   // UIWindowFrameRateSynced (which is the primary monitor refresh rate)
   // or a framerate like 1/60.0 for 60 Hz
   //
   // UIWindowFrameRateAsynced:  timout == INFINITE, returnsEarly: YES
   // UIWindowFrameRateUnsynced: timout == 0.0  returnsEarly: YES
   // Else timeout: returnsEarly: NO
   assert( frameRate == UIWindowFrameRateUnsynced ||
           frameRate == UIWindowFrameRateAsync ||
           frameRate == UIWindowFrameRateSynced ||
           frameRate > 0.0);

   return( [self waitForEvents:frameRate == UIWindowFrameRateSynced
                                 ? 1.0 / [self primaryMonitorRefreshRate]
                                 : frameRate
                           now:now
                  returnsEarly:frameRate == UIWindowFrameRateUnsynced||
                               frameRate == UIWindowFrameRateAsync]);

}


- (void) willRender:(CAAbsoluteTime) renderStart
{
   struct mulle_pointerarrayenumerator   rover;
   UIView                                *view;

#ifdef RENDER_VERBOSE_DEBUG
   fprintf( stderr, "%s %s\n", __PRETTY_FUNCTION__, [self UTF8String]);
#endif

   rover = mulle_pointerarray_enumerate( &_delegateViews);
   while(  mulle_pointerarrayenumerator_next( &rover, (void **) &view))
      [view willRenderWithAbsoluteTime:renderStart];
   mulle_pointerarrayenumerator_done( &rover);
}


- (id <UIOSGraphicsContext>) activateWindowGraphicsContext
{
   Class   osGraphicsContextClass;

   [_os_window os_activateContext];

   if( ! _context)
   {
      osGraphicsContextClass = [[self class] osGraphicsContextClass];
      _context               = [[osGraphicsContextClass alloc] initWithEdgeAntialiasing:(_styleMask & UIWindowStyleEdgeAntialias)
                                                                      useStencilStrokes:(_styleMask & UIWindowStyleStencilStrokes)];
   }
   [_context setActive:YES];

   return( _context);
}


- (void) deactivateWindowGraphicsContext:(id <UIOSGraphicsContext>) context
{
   assert( context);
   assert( _context == context);

   [context setActive:NO];
   [_os_window os_deactivateContext];
}



// TODO: memo, maybe the context triggers os_activateContext ?
- (id <UIOSGraphicsContext>) activateRenderGraphicsContext
{
   id <UIOSGraphicsContext>   context;
   Class                      cls;

   // take renderlock here, relinquish later when wating for events
   // or when someone closes the window

   if( _backingStore == UIWindowBackingStoreNonRetained)
      return( [self activateWindowGraphicsContext]);

   assert( _offscreen_os_window);

   [_offscreen_os_window os_activateContext];
   if( ! _offscreenContext)
   {
      cls               = [[self class] osGraphicsContextClass];
      _offscreenContext = [[cls alloc] initWithEdgeAntialiasing:(_offscreenStyleMask & UIWindowStyleEdgeAntialias)
                                              useStencilStrokes:(_offscreenStyleMask & UIWindowStyleStencilStrokes)];
      [_offscreenContext setRendersOffScreen:YES];
   }
   [_offscreenContext setActive:YES];                        // just a flag

   return( _offscreenContext);
}


- (void) deactivateRenderGraphicsContext:(id <UIOSGraphicsContext>) context
{
   assert( context);

   [context setActive:NO];
   if( context == _offscreenContext)
      [_offscreen_os_window os_deactivateContext];
   else
      [_os_window os_deactivateContext];
}


- (struct CGFramebufferBitmap)
   lastRenderedFramebufferBitmapType:(enum CGFramebufferBitmapType) type
                            inFlight:(BOOL) inFlight
                           allocator:(struct mulle_allocator *) allocator
{
   id <UIOSGraphicsContext>     context;
   struct CGFramebufferBitmap   fb;

   context = [self activateRenderGraphicsContext];
   {
     // need to blit from offscreen window to onscreen here
     // get image of offscreen framebuffer
     // can do this only, if we have rendered something last frame
     fb = [context lastRenderedFramebufferBitmapType:type
                                            inFlight:(BOOL) inFlight
                                           allocator:allocator];
   }
   [self deactivateRenderGraphicsContext:context];

   return( fb);
}


- (struct CGFramebufferBitmap) lastRenderedFramebuffer
{
   return( [self lastRenderedFramebufferBitmapType:CGFramebufferRGBABytes
                                          inFlight:NO
                                         allocator:NULL]);
}


- (struct CGFramebufferBitmap)
   lastRenderedOffscreenFramebufferBitmapType:(enum CGFramebufferBitmapType) type
                                    allocator:(struct mulle_allocator *) allocator
{
   id <UIOSGraphicsContext>     context;
   struct CGFramebufferBitmap   fb;

   context = [self activateRenderGraphicsContext];
   {
     // need to blit from offscreen window to onscreen here
     // get image of offscreen framebuffer
     // can do this only, if we have rendered something last frame
     fb = [context lastRenderedOffscreenFramebufferBitmapType:type
                                                    allocator:allocator];
   }
   [self deactivateRenderGraphicsContext:context];

   return( fb);
}


- (struct CGFramebufferBitmap) lastRenderedOffscreenFramebuffer
{
   return( [self lastRenderedOffscreenFramebufferBitmapType:CGFramebufferRGBABytes
                                                  allocator:NULL]);
}


- (void) copyBackingStore
{
   struct CGFramebufferBitmap   fb;
   struct CGFrameInfo           info;
   id <UIOSGraphicsContext>     context;

   fb = [self lastRenderedOffscreenFramebuffer];
   // if there has nothing been rendered yet, we decline the swap
   if( fb.bytes == 0)
      return;

   // mulle_rgba_dump( fb.bytes, fb.info.size.width, fb.info.size.height);

   //
   // draw the image we got from the framebuffer into the window
   //
   context = [self activateWindowGraphicsContext];
   {
      [self syncFrameAndFramebufferSizeWithOSWindow];
      [self getFrameInfo:&info];

      [context beginRender:&info];
      [context clearFramebufferMinimally]; // probably even not needed
      [context drawFramebufferBitmap:&fb];
      [context endRender];
   }
   [self deactivateWindowGraphicsContext:context];

   CGFramebufferBitmapDone( &fb);
}


- (void) renderBackingStore
{
   id                         framebufferImage;
   id                         image;
   CGRect                     rect;
   id <UIOSGraphicsContext>   context;
   id <UIOSGraphicsContext>   renderContext;
   struct CGFrameInfo         info;

   // get size of framebuffer
   renderContext = [self activateRenderGraphicsContext];
   {
     framebufferImage = [renderContext framebufferImage];
   }
   [self deactivateRenderGraphicsContext:renderContext];
   if( ! framebufferImage)
      return;

   context = [self activateWindowGraphicsContext];
   {
      [self syncFrameAndFramebufferSizeWithOSWindow];
      [self getFrameInfo:&info];

      [context beginRender:&info];
      [context clearFramebufferMinimally];

      image = [renderContext shareImage:framebufferImage
                            withContext:context];
      assert( image);

      rect.origin = CGPointZero;
      rect.size   = info.size;

      [context drawRect:rect
                  image:image
                  scale:YES];
#if DEBUG
      [context strokeRect:CGRectInset( rect, 20, 20)
                 hexColor:0x20A080FF
                    width:8.0];
#endif
      [context endRender];
   }
   [self deactivateWindowGraphicsContext:context];
}


//
// Can only swap buffers if we have rendered at least once
// An early incoming windows refresh request needs to be discarded
//
- (void) swapBuffers
{
   id <UIOSGraphicsContext>   context;

   if( _backingStore == UIWindowBackingStoreBuffered)
   {
//      [self copyBackingStore];  // copies pixels from GPU to CPU to GPU
      [self renderBackingStore];  // uses GPU pixels as texture,
   }

   if( _willSwapCallback)
      (*_willSwapCallback)( self);

   // context needs to be set here
   if( _swapInterval != _oldSwapInterval)
   {
      context = [self activateWindowGraphicsContext];
      {
         [_os_window os_setSwapInterval:_swapInterval];  // need 0 for smooth pointer/control sync
      }
      [self deactivateWindowGraphicsContext:context];

      _oldSwapInterval = _swapInterval;
   }

   [_os_window os_swapBuffers];
   _lastDidFramebufferSwapTimestamp = CAAbsoluteTimeNow();
   if( _didSwapCallback)
      (_didSwapCallback)( self);

   //
   // from here on CGImages should be safe to be reaped by autorelease pool
   // or ?
   //
}


//
// TODO: too much "render" going on. Clearly define the phases and what
//       evertything is called.
//
// UIWindow render chain
//
//    Creates a queue of CALayers from the UIView hierarchy. Layers are
//    setup so they draw themselves into the window coordinate space.
//
//                                                  UIWindow Delegate Views
//  .----------------------------------------.      .---.---.
//  | UIWindow willRenderWithAbsoluteTime:   |      | B | C |
//  '----------------------------------------'      '---'---'
//                       |
//                       |
//                       v                          UIView hierarchy tree
//  .-----------------------------------------.           .---.
//  | UIView layout                           |           | A |-.
//  '-----------------------------------------'           '---' |
//                       |                                |     |
//                       |                          .---. |     |
//                       v                          | B |<'     v
//  .-----------------------------------------.     '---'     .---.
//  | UIView createRenderQueue:               |               | C |
//  '-----------------------------------------'               '---'
//                       |                                  |
//    From here on the   |                                  |
//    only hierarchy     |                                  |
//    is the order       |                                  |
//    of the layers in   |                                  v
//    the queue.         |
//                       v                          CALayer Render Queue
//  .------------------------------------------.    .---.---.---.---.---.----.
//  | CGAnimation animateObjects:absoluteTime: |    | A1| B1| B2| C1| C2| C3 |
//  '------------------------------------------'    '---'---'---'---'---'----'
//                       |
//                       |
//                       v
//  .-----------------------------------------.
//  | CGContext renderObjects:                |
//  '-----------------------------------------'
//
// glitch hunt:
//
// a) we sometimes overflow the current frame
// b) we are doublebuffering
// c) the glitch occurs when there is already drawing on the screen
// d) the glitch looks like the buffer is cleared and then not swapped
//
// With the parameters, you should be able to render into a different
// context from the window context, with all the delegate calls intact.
//
// A window must not run two renderFrames concurrently!
// A view calling [[self window] context] could get the wrong context
// though. Maybe need a -renderContext ?
// Or should
//
- (void) layoutFrame:(struct CGFrameInfo *) info
             context:(id <UIOSGraphicsContext>) context
{
   /*
    * Layout
    */
   [self willRender:info->now];

   [_preLayoutAnimator animateWithAbsoluteTime:info->now];

   if( _didAnimateCallback)
      (*_didAnimateCallback)( self, context, info, 0);

   if( _willLayoutCallback)
      (*_willLayoutCallback)( self, context, info);

   //
   // do layout before the animation step, as this may generate animations
   //
#if LAYOUT_ANIMATIONS
   [self beginLayout:info];
#endif
   [self layoutIfNeeded];
#if LAYOUT_ANIMATIONS
   [self endLayout];
#endif
   if( _didLayoutCallback)
      (*_didLayoutCallback)( self, context, info);

   [_postLayoutAnimator animateWithAbsoluteTime:info->now];

   if( _didAnimateCallback)
      (*_didAnimateCallback)( self, context, info, 1);
}


- (void) animateFrame:(struct CGFrameInfo *) info
             context:(id <UIOSGraphicsContext>) context
{
   /*
    * Animate
    */
   //
   // create the renderQueue. This will set the transforms for all
   // the layer and calculate the actual opacity, which is then stored
   // in layer transform and layer alpha.
   //
   _mulle_pointerarray_reset( &_renderQueue);
   [self createRenderQueue:&_renderQueue];
   if( _didCreateRenderQueueCallback)
      (*_didCreateRenderQueueCallback)( self, context, info);

   [CAAnimation animateObjects:&_renderQueue
                  absoluteTime:info->now];

   //
   // can animations add and subtract layers and views ?
   // they may, but they won't show up this render
   //
   // have no didAnimate callback, because we would like to pipeline
   // with rendering, or but the animation step into the render part ?
   //
   if( _didAnimateCallback)
      (*_didAnimateCallback)( self, context, info, 2);
}


- (void) renderFrame:(struct CGFrameInfo *) info
             context:(id <UIOSGraphicsContext>) context
{
   /*
    * Render
    */
    // don't pool this, autoreleased stuff needs to hang on until
    // swap buffers

   [context beginRender:info];
   {
      if( _willRenderCallback)
         (*_willRenderCallback)( self, context, info);

      if( [self clearsFramebuffer])  // default yes
         [context clearFramebufferWithHexColor:_backgroundHexColor];  //?? useful
      [context renderObjects:&_renderQueue];

      [_renderDelegate windowWillEndRender:self
                                    context:context];
      if( _willEndRenderCallback)
         (*_willEndRenderCallback)( self, context, info);
   }
   [context suspendRender];

   // context is still active though and framebuffer is bound
   if( _didRenderCallback)
      (*_didRenderCallback)( self, context, info);

   [context _endRender];
   //
   // just don't want to keep dangling stuff here
   // It's nice to see the renderQueue wthe F11 though
   //mulle_pointerarray_reset( &_renderQueue);
}


// 0 is forever
- (BOOL) renderUpToNumberOfFrames:(NSUInteger) maxFrames
{
   struct CGFrameInfo          info;
   CAAbsoluteTime              timestamp;
   id <UIOSGraphicsContext>    context;
   CGFloat                     frameRate;
   NSUInteger                  eventTypes;
   NSUInteger                  frames;
   BOOL                        rval;

   frames      = 0;
   rval        = NO;
   context     = nil;

   for( frames = 0; ! maxFrames || frames != maxFrames; frames++)
   {
      if( _shouldClose)
      {
         rval = YES;
         break;
      }

      /*
       * Rendering
       */

      // it's important that autoreleased stuff is kept alive until swap
      // buffers, so that for example textures aren't accidentally reaped
      // before their time
      // After swapBuffer they should be reaped though, so they don't
      // accumulate.
      @autoreleasepool
      {
         context = [self activateRenderGraphicsContext];
         {
            [self getFrameInfo:&info];  // retrieve newest geometry

            [_renderDelegate windowWillBeginRender:self
                                          context:context];

            [self layoutFrame:&info
                     context:context];
            [self animateFrame:&info
                     context:context];
            [self renderFrame:&info
                      context:context];

            [_renderDelegate windowDidEndRender:self];
         }
         [self deactivateRenderGraphicsContext:context];
         context = nil;         // idiot protection

      /*
       * swap
       */
#ifdef SWAP_DEBUG
         fprintf( stderr, "%s %s swaps framebuffer (frame: %s, buffer: %ld, %ld)\n",
                        __PRETTY_FUNCTION__,
                        [self UTF8String],
                        CGSizeUTF8String( info.size),
                        info.framebufferSize.width, info.framebufferSize.height);
#endif
         [self swapBuffers];
      }

      // now no openGL or CGContext calls should happen
      // as the context has been detached from this thread

      /*
       * Event handling.
       */
      @autoreleasepool
      {
         //
         // TODO: More useful to this when a mouse event hits on demand ?
         //       But then how can we be sure, that the tree is 100%
         //       identical to what is shown and that no changes have been
         //       done inbetween ?
         //
         [self setupQuadtree];

         // we can get to 29.98 fps when we feed it the last timestamp
         // but is it desirable ?
         timestamp = _lastDidProcessEventsTimestamp
                        ? _lastDidProcessEventsTimestamp
                        : _lastDidFramebufferSwapTimestamp;
         frameRate = _frameRate;

         // just push next one through ASAP or ?
         if( _isResizing)
         {
            _isResizing = NO;
            frameRate   = UIWindowFrameRateUnsynced;
         }

         eventTypes = [self processEvents:timestamp
                                frameRate:frameRate];
         _lastDidProcessEventsTimestamp = CAAbsoluteTimeNow();
      }
   }

   return( rval);
}


- (void) renderLoop
{
   [self renderUpToNumberOfFrames:0];   // FOREVER (or until close :))
}


- (BOOL) renderFrameWaitForNeedsDisplay
{
   BOOL flag;

   [_needsDisplayLock lockWhenCondition:1];
   flag = [self renderUpToNumberOfFrames:1];
   [_needsDisplayLock unlockWithCondition:0];
   return( flag);
}

@end
