//
// Copyright (c) 2021 Nat!, Mulle kybernetiK
//
#import "UIWindow+Render.h"

#import "import-private.h"

#import "UIView+RenderQueue.h"


// #define RENDER_DEBUG

//
//
// UIWindow frame chain
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
//  | CGContext drawObjects:                |
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

@implementation UIWindow ( Render)

- (void) willRenderWithAbsoluteTime:(mulle_absolutetime_t) renderStart
{
   struct mulle_pointerarrayenumerator   rover;
   UIView                                *view;

#ifdef RENDER_DEBUG
   mulle_fprintf( stderr, "%#@: %s %@\n",
            [NSThread currentThread], __PRETTY_FUNCTION__, self);
#endif

   rover = mulle_pointerarray_enumerate( &_delegateViews);
   while(  mulle_pointerarrayenumerator_next( &rover, (void **) &view))
      [view willRenderWithAbsoluteTime:renderStart];
   mulle_pointerarrayenumerator_done( &rover);
}


- (void) layoutFrame:(struct CGFrameInfo *) info
     graphicsContext:(id <UIGraphicsContext>) context
{
#ifdef RENDER_DEBUG
   mulle_fprintf( stderr, "%#@: %s %@\n",
            [NSThread currentThread], __PRETTY_FUNCTION__, self);
#endif
   /*
    * Layout
    */
   [self willRenderWithAbsoluteTime:info->now];

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


- (BOOL) animateFrame:(struct CGFrameInfo *) info
      graphicsContext:(id <UIGraphicsContext>) context
{
   BOOL   didAnimate;

#ifdef RENDER_DEBUG
   mulle_fprintf( stderr, "%#@: %s %@\n",
            [NSThread currentThread], __PRETTY_FUNCTION__, self);
#endif

   /*
    * Animate
    */
   //
   didAnimate = [CAAnimation animateObjects:&_drawingQueue
                               absoluteTime:info->now];

   //
   // can animations add and subtract layers and views ?
   // they may, but they won't show up this render
   //
   // have no didAnimate callback, because we would like to pipeline
   // with rendering, or but the animation step into the render part ?
   //
   if( _didAnimateCallback)
      didAnimate |= (*_didAnimateCallback)( self, context, info, 2);

    return( didAnimate);
}


- (void) drawFrame:(struct CGFrameInfo *) info
   graphicsContext:(id <UIGraphicsContext>) context
{
   BOOL   clearFramebuffer;

#ifdef RENDER_DEBUG
   mulle_fprintf( stderr, "%#@: %s %@ %s\n",
            [NSThread currentThread], __PRETTY_FUNCTION__, self,
            CGFrameInfoUTF8String( info));
#endif

   /*
    * Render
    */
    // don't pool this, autoreleased stuff needs to hang on until
    // swap buffers

   _renderInfo.lastStartTime = _renderInfo.startTime;
   _renderInfo.startTime     = info->now;

   clearFramebuffer = YES;
   [context beginRender:info];
   {
      if( _willDrawCallback)
         clearFramebuffer = (*_willDrawCallback)( self, context, info);

      if( clearFramebuffer)
         [context clearFramebufferWithColor:[self backgroundColor]];

      [self->_frameDelegate window:self
                     willDrawFrame:info
                   graphicsContext:context];

      [context drawObjects:&_drawingQueue];

      if( _didDrawObjectsCallback)
         (*_didDrawObjectsCallback)( self, context, info);

#ifdef DEBUG
      if( [context rendersOffScreen])
      {
         CGRect   rect;

         [context resetTransform];
         [context resetScissor];

         rect.origin = CGPointZero;
         rect.size   = info->window.frame.size;
         [context strokeRect:CGRectInset( rect, 24, 24)
                       color:CGColorMakeWithHexColor( 0xE04020FF)
                       width:4.0];
      }
#endif

      [self->_frameDelegate window:self
                      didDrawFrame:info
                   graphicsContext:context];
   }
   [context suspendRender];

   // context is still active though and framebuffer is bound
   if( _didDrawCallback)
      (*_didDrawCallback)( self, context, info);

   _renderInfo.lastFrameInfo = *info;
   _renderInfo.numberOfRenderedFrames++;

   [context _endRender];
   //
   // just don't want to keep dangling stuff here
   // It's nice to see the renderQueue with F11 though
   //mulle_pointerarray_reset( &_drawingQueue);
}

- (void) createDrawingQueueForFrame:(struct CGFrameInfo *) info
                    graphicsContext:(id <UIGraphicsContext>) context
{
#ifdef RENDER_DEBUG
   mulle_fprintf( stderr, "%#@: %s %@\n",
            [NSThread currentThread], __PRETTY_FUNCTION__, self);
#endif

   _mulle_pointerarray_reset( &_drawingQueue);
   [self createRenderQueue:&_drawingQueue];
   if( _didCreateRenderQueueCallback)
      (*_didCreateRenderQueueCallback)( self, context, info);
}

//
// this is default renderFrame callback
//
void   UIWindowDefaultFrameCallback( UIWindow *self,
                                     id <UIGraphicsContext> context,
                                     struct CGFrameInfo *info,
                                     NSUInteger displayBits)
{
   if( self->_frameDelegate)
      [self->_frameDelegate window:self
                    willBeginFrame:info
                   graphicsContext:context];

   if( displayBits & UIWindowNeedsLayout)
   {
      [self layoutFrame:info
        graphicsContext:context];
      displayBits |= UIWindowNeedsRedraw;
   }

   //
   // create the renderQueue. This will set the transforms for all
   // the layer and calculate the actual opacity, which is then stored
   // in layer transform and layer alpha.
   //
   [self createDrawingQueueForFrame:info
                    graphicsContext:context];

   //
   // this animateFrame: runs unconditonally over the displayQueue
   // that will be then also be used by drawFrame:
   //
   if( [self animateFrame:info
         graphicsContext:context])
   {
      displayBits |= UIWindowNeedsRedraw;
   }

   // drawFrame: does beginRender/endRender...
   if( displayBits & UIWindowNeedsRedraw)
   {
      [self drawFrame:info
      graphicsContext:context];
   }

   [self->_frameDelegate window:self
                    didEndFrame:info
                graphicsContext:context];
}

@end
