//
// Copyright (c) 2021 Nat!, Mulle kybernetiK
//
#import "UIWindow+Render.h"

#import "import-private.h"

#import "UIView+RenderQueue.h"
#import "CGFrameInfo+UTF8String.h"

//#define LAYOUT_ANIMATIONS
//#define RENDER_DEBUG
//#define RENDER_DEBUG_VERBOSE
//#define RENDER_FRAMEINFO_DEBUG
#ifdef DEBUG
# ifndef DEBUG_DUPLICATE_LAYOUT
#  define DEBUG_DUPLICATE_LAYOUT 1
# endif
#endif
#ifndef DEBUG_DUPLICATE_LAYOUT
#  define DEBUG_DUPLICATE_LAYOUT 0
#endif
// #define DRAW_FRAMEBUFFER_ID_RECT


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
//  | CGContext drawObjects:                  |
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
// A view calling [(UIWindow *) [self window] context] could get the wrong context
// though. Maybe need a -renderContext ?
// Or should
//

@implementation UIWindow ( Render)

- (void) willRenderWithAbsoluteTime:(mulle_absolutetime_t) renderStart
{
   struct mulle_pointerarrayenumerator   rover;
   UIView                                *view;

#ifdef RENDER_DEBUG
   MulleUILogThisMethod();
#endif

   rover = mulle_pointerarray_enumerate( &_delegateViews);
   while(  mulle_pointerarrayenumerator_next( &rover, (void **) &view))
      [view willRenderWithAbsoluteTime:renderStart];
   mulle_pointerarrayenumerator_done( &rover);
}


static mulle_relativetime_t    determineAnimationRate( UIWindow *self)
{
   mulle_relativetime_t    animationRate;
   mulle_relativetime_t    fastestFrameRate;
   struct UIOSWindowInfo   windowInfo;

   [self->_OSWindow getOSWindowInfo:&windowInfo];
   fastestFrameRate   = UIOSWindowInfoGetFastestFrameRate( &windowInfo);

   animationRate = fastestFrameRate;
   if( animationRate == UIWindowFrameRateAsync)
      animationRate = self->_asyncAnimationRate;
   return( animationRate);
}


- (BOOL) preLayoutAnimations:(struct CGFrameInfo *) info
             graphicsContext:(id <UIGraphicsContext>) context
{
   BOOL                   didAnimate;
   mulle_relativetime_t   animationRate;

#ifdef RENDER_DEBUG
   MulleUILogThisMethod();
#endif
   animationRate = determineAnimationRate( self);
   didAnimate    = [_preLayoutAnimator animateWithAbsoluteTime:info->now
                                                 animationRate:animationRate];
   if( _didAnimateCallback)
      (*_didAnimateCallback)( self, context, info, 0);

   return( didAnimate);
}


- (BOOL) postLayoutAnimations:(struct CGFrameInfo *) info
              graphicsContext:(id <UIGraphicsContext>) context
{
   BOOL                   didAnimate;
   mulle_relativetime_t   animationRate;

#ifdef RENDER_DEBUG
   MulleUILogThisMethod();
#endif

   animationRate = determineAnimationRate( self);
   didAnimate    = [_postLayoutAnimator animateWithAbsoluteTime:info->now
                                                  animationRate:animationRate];
   if( _didAnimateCallback)
      (*_didAnimateCallback)( self, context, info, 1);

   return( didAnimate);
}


- (BOOL) isLayoutedView:(UIView *) view
{
#if DEBUG_DUPLICATE_LAYOUT
   return( _mulle__pointerset_get( &_layoutedViews, view) ? YES : NO);
#else
   return( NO);
#endif
}


- (void) addLayoutedView:(UIView *) view
{
#if DEBUG_DUPLICATE_LAYOUT
   assert( ! _mulle__pointerset_get( &_layoutedViews, view));
   if( _isLayouting)
      _mulle__pointerset_insert( &_layoutedViews, view, MulleObjCInstanceGetAllocator( self));
#endif
}


- (void) layout 
{
#if DEBUG_DUPLICATE_LAYOUT
   assert( ! _isLayouting);
   _isLayouting = YES;
   _mulle__pointerset_init( &_layoutedViews, 64, MulleObjCInstanceGetAllocator( self));
#endif

   [super layout];

#if DEBUG_DUPLICATE_LAYOUT
   _mulle__pointerset_reset( &_layoutedViews);
   _isLayouting = NO;
#endif
   _quadtreeNeedsSetup = YES;
}


- (void) layoutFrame:(struct CGFrameInfo *) info
     graphicsContext:(id <UIGraphicsContext>) context
{
#ifdef RENDER_DEBUG
   MulleUILogThisMethod();
#endif
   /*
    * Layout
    */
   if( _willLayoutCallback)
      (*_willLayoutCallback)( self, context, info);

   //
   // do layout before the animation step, as this may generate animations
   //
#if LAYOUT_ANIMATIONS
   [self beginLayout:info];
#endif
   [self layout];
#if LAYOUT_ANIMATIONS
   [self endLayout];
#endif
   if( _didLayoutCallback)
      (*_didLayoutCallback)( self, context, info);
}


- (BOOL) animateFrame:(struct CGFrameInfo *) info
      graphicsContext:(id <UIGraphicsContext>) context
{
   BOOL                   didAnimate;
   mulle_relativetime_t   animationRate;

#ifdef RENDER_DEBUG
   MulleUILogThisMethod();
#endif

   /*
    * Animate
    */
   //
   animationRate = determineAnimationRate( self);
   didAnimate    = [CAAnimation animateObjects:&_drawingQueue
                                  absoluteTime:info->now
                                 animationRate:animationRate];
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


- (void) clearFrame:(struct CGFrameInfo *) info
    graphicsContext:(id <UIGraphicsContext>) context
{
   BOOL   doClearFramebufferColor;

   if( _willClearCallback && ! (*_willClearCallback)( self, context, info))
      return;

   //
   // if window is Opaque, clear is superflous, except if this is the very
   // first frame of a new or corrupted framebuffer
   //
   doClearFramebufferColor = YES;
   if( [context isInitializedFramebuffer]) // now we can be smarter..
      doClearFramebufferColor = info->alpha == 1.0 && ! [self isOpaque];

#ifdef RENDER_DEBUG_VERBOSE
   MulleUILog( "clearing framebuffer color=%btd", doClearFramebufferColor);
#endif
   // we have to clear some of the framebuffer for nanovg anyway
   // like the stencil bits
   if( doClearFramebufferColor)
      [context clearFramebufferWithHexColor:[self backgroundHexColor]];
   else
      [context clearFramebufferNoColor];

#ifdef RENDER_DEBUG_VERBOSE
   MulleUILog( "cleared framebuffer");
#endif
}


- (void) drawFrame:(struct CGFrameInfo *) info
   graphicsContext:(id <UIGraphicsContext>) context
{
#ifdef RENDER_DEBUG
   MulleUILog( "%s", CGFrameInfoUTF8String( info));
#endif

   /*
    * Render
    */
    // don't pool this, autoreleased stuff needs to hang on until
    // swap buffers

//   _renderInfo.lastStartTime = _renderInfo.startTime;
//   _renderInfo.startTime     = info->now;
   [context beginRender:info];
   { 
      [self clearFrame:info 
       graphicsContext:context];

      [self->_frameDelegate window:self
                     willDrawFrame:info
                  graphicsContext:context];

      if( _willDrawCallback)
         (*_willDrawCallback)( self, context, info);

#ifdef RENDER_DEBUG_VERBOSE
      MulleUILog( "drawing objects");
#endif
      [context drawObjects:&_drawingQueue];
#ifdef RENDER_DEBUG_VERBOSE
      MulleUILog( "drew objects");
#endif

      if( _didDrawObjectsCallback)
         (*_didDrawObjectsCallback)( self, context, info);

      if( _debugEnabled & UIWindowDrawFramebufferIdRect)
      {
         if( [context conformsToProtocol:@protocol( UIGraphicsDrawing)])
         {
            CGRect   rect;

            [context resetTransform];
            [context resetScissor];

            rect.origin = CGPointZero;
            rect.size   = info->window.frame.size;
            [(id <UIGraphicsDrawing>) context
                     strokeRect:CGRectInset( rect, 24, 24)
                          width:4.0
                       hexColor:0xE04020FF];
         }
      }

      [self->_frameDelegate window:self
                      didDrawFrame:info
                   graphicsContext:context];
#ifdef RENDER_FRAMEINFO_DEBUG
      [self renderFrameInfo:info
                  atPoint:CGPointMake( 20, 20)
                     color:CGColorMakeRed()
            graphicsContext:context];
#endif

      [context suspendRender];

   // context is still active though and framebuffer is bound
      if( _didDrawCallback)
         (*_didDrawCallback)( self, context, info);
   }
//   _renderInfo.lastFrameInfo = *info;
//   _renderInfo.numberOfFrames++;

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
   MulleUILogThisMethod();
#endif

   _mulle_pointerarray_reset( &_drawingQueue);
   [self createRenderQueue:&_drawingQueue];
   if( _didCreateRenderQueueCallback)
      (*_didCreateRenderQueueCallback)( self, context, info);
}


// use very basic drawing
// render everything line by line
//
// typedef struct CGFrameInfo
// {
//    struct CGWindowInfo    window;
//    struct MulleIntegerRect    viewportFrame;    // used for the viewport (use: 0, 0, frameSize)
//    CGFloat                alpha;            // set to 1.0
//    mulle_absolutetime_t   now;              // mulle_absolutetime_t
// } CGFrameInfo;
//
// typedef struct CGWindowInfo
// {
//    CGRect                 frame;            // window coordinates frame
//    struct MulleIntegerSize    framebufferSize;  // actual pixels (frameSize * pixelRatio)
//    CGVector               UIScale;
//    CGFloat                pixelRatio;
// } CGWindowInfo;

- (void) renderFrameInfo:(struct CGFrameInfo *) info
                 atPoint:(CGPoint) point
                hexColor:(NSUInteger) color
         graphicsContext:(id <UIGraphicsDrawing>) context
{
   struct mulle_buffer    buffer;

   assert( info);

   mulle_buffer_init( &buffer, NULL);
   {
      mulle_buffer_sprintf( &buffer, "frame           : %s\n",   CGRectUTF8String( info->window.frame));
      mulle_buffer_sprintf( &buffer, "framebufferSize : %s\n",   MulleIntegerSizeUTF8String( info->window.framebufferSize));
      mulle_buffer_sprintf( &buffer, "UIScale         : %s\n",   CGVectorUTF8String( info->window.UIScale));
      mulle_buffer_sprintf( &buffer, "pixelRatio      : %.3f\n", info->window.pixelRatio);
      mulle_buffer_sprintf( &buffer, "viewportFrame   : %s\n",   MulleIntegerRectUTF8String( info->viewportFrame));
      mulle_buffer_sprintf( &buffer, "alpha           : %.3f\n", info->alpha);
      mulle_buffer_sprintf( &buffer, "now             : %.6f\n", info->now);
      mulle_buffer_add_byte( &buffer, 0);

      [context drawAtPoint:point
            textUTF8String:mulle_buffer_get_bytes( &buffer)
        fontNameUTF8String:NULL
                  fontSize:12.0
                  hexColor:color];
   }
   mulle_buffer_done( &buffer);
}


//
// this is default renderFrame callback
//
BOOL   UIWindowDefaultRawFrameCallback( UIWindow *self,
                                        id <UIGraphicsContext> context,
                                        struct CGFrameInfo *info,
                                        NSUInteger displayBits)
{
   BOOL   didAnimate;

#ifdef RENDER_DEBUG
   MulleUILog( "(0x%tx)", displayBits);
#endif

   {
      if( self->_frameDelegate)
         [self->_frameDelegate window:self
                       willBeginFrame:info
                      graphicsContext:context];

      if( self->_frameCallback)
      {
         [context beginRender:info];
         {
            [self clearFrame:info
            graphicsContext:context];

            [self->_frameDelegate window:self
                           willDrawFrame:info
                        graphicsContext:context];

            didAnimate = (*self->_frameCallback)( self, context, info);

            [self->_frameDelegate window:self
                           didDrawFrame:info
                        graphicsContext:context];
         }
         [context endRender];
      }
      else 
      {
         [self willRenderWithAbsoluteTime:info->now];

         didAnimate = [self preLayoutAnimations:info
                                graphicsContext:context];

         if( displayBits & UIWindowNeedsLayout)
         {
            [self layoutFrame:info
            graphicsContext:context];
            displayBits |= UIWindowNeedsRedraw;
         }

         didAnimate |= [self postLayoutAnimations:info
                                  graphicsContext:context];

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
         didAnimate |= [self animateFrame:info
                          graphicsContext:context];

         if( didAnimate)
            displayBits |= UIWindowNeedsRedraw;

         // drawFrame: does beginRender/endRender...
         if( displayBits & UIWindowNeedsRedraw)
         {
            [self drawFrame:info
            graphicsContext:context];
         }
      }

      [self->_frameDelegate window:self
                       didEndFrame:info
                   graphicsContext:context];
   }

   return( didAnimate);
}



BOOL   UIWindowDefaultDidRenderFrameCallback( UIWindow *self,
                                              id <UIGraphicsContext> context,
                                              struct CGFrameInfo *info,
                                              BOOL didAnimate)
{
   return( didAnimate);
}

@end
