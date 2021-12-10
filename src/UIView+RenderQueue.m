//
// Copyright (c) 2020 Nat!, Mulle kybernetiK
//
#import "UIView+RenderQueue.h"

#import "import-private.h"

#import "UIWindow.h"


@implementation UIView ( RenderQueue)

struct RenderQueueContext
{
   CGAffineTransform   xform;
   CGRect              clipRect;
   CGFloat             alpha;
};


static void   renderQueueAddLayer( struct mulle_pointerarray *renderQueue,
                                   id <UILayer> layer,
                                   struct RenderQueueContext *v)
{
   [layer setTransform:v->xform];
   [layer setAlpha:v->alpha];

//   if( v->clipRect.size.width != INFINITY)
//      fprintf( stderr, "%p setClipRect: %s  transform: %s\n",
//               layer,
//               CGRectUTF8String( v->clipRect),
//               CGAffineTransformUTF8String( v->xform));
   [layer setClipRect:v->clipRect];

   mulle_pointerarray_add( renderQueue, layer);
}


//
// the transform is the concatenation of the superviews transforms
// the clipRect is in window space (window bounds)
//
- (void) createRenderQueue:(struct mulle_pointerarray *) renderQueue
                    context:(struct RenderQueueContext *) ctx
{
   id <UILayer>                          layer;
   CGAffineTransform                     projection;
   CGRect                                bounds;
   CGRect                                frame;
   CGRect                                screenRect;
   CGRect                                transformedRect;
   struct mulle_pointerarrayenumerator   rover;
   struct RenderQueueContext             v;
   UIView                                *view;

   if( [self isCulledByLayout])
      return;

   v.alpha = _alpha * ctx->alpha;
   // TODO: this is same as CGAlphaIsTransparent. Could check actual bit
   //       depth of context here though
   if( v.alpha < 0.5 / 32767.0)  // assume rounding up and 16 bit color depth
      return;

   bounds     = [self bounds];
   projection = CGAffineTransformMakeProjection( _frame, bounds);
   v.xform    = CGAffineTransformConcat( ctx->xform, projection);

   v.clipRect = ctx->clipRect;
   if( _clipsToBounds)
   {
      // actually clips to frame... sorta...
      transformedRect = CGRectApplyAffineTransform( _frame, ctx->xform);
      v.clipRect      = CGRectIntersection( ctx->clipRect, transformedRect);
   }

   //
   // if we clip to nothing we don't do anything
   // we use 0.1 for FP errors. An invalid intersetion also produces
   // inf origins, which apparently is bad later on. This should implicitly
   // catch this too
   //
   if( v.clipRect.size.width < 0.1 || v.clipRect.size.height < 0.1)
      return;

#ifdef HAVE_RENDER_CACHE
   if( _cacheLayer)
   {
      renderQueueAddLayer( renderQueue, _cacheLayer, &v);
   }
   else
#endif
   {
      /*
      * Layers
      */
      renderQueueAddLayer( renderQueue, _mainLayer, &v);

      rover = mulle_pointerarray_enumerate( _layers);
      while( _mulle_pointerarrayenumerator_next( &rover, (void **) &layer))
      {
         renderQueueAddLayer( renderQueue, layer, &v);
      }
      mulle_pointerarrayenumerator_done( &rover);
   }

   /*
    * Subviews
    */
   rover = mulle_pointerarray_enumerate( _subviews);
   while( _mulle_pointerarrayenumerator_next( &rover, (void **) &view))
   {
      // we cull clipped views completely here
      frame      = [view frame];
      screenRect = CGRectApplyAffineTransform( frame, v.xform);
      if( CGRectIntersectsRect( v.clipRect, screenRect))
         [view createRenderQueue:renderQueue
                         context:&v];
   }
   mulle_pointerarrayenumerator_done( &rover);
}


- (void) createRenderQueue:(struct mulle_pointerarray *) renderQueue
{
   abort(); // only UIWindow can do this currently
}


- (void) dumpRenderQueue:(struct mulle_pointerarray *) renderQueue
{
   struct mulle_pointerarrayenumerator   rover;
   id <UILayer>                          layer;

   rover = mulle_pointerarray_enumerate( renderQueue);
   while( _mulle_pointerarrayenumerator_next( &rover, (void **) &layer))
   {
      [layer dumpWithIndent:1];
   }
   mulle_pointerarrayenumerator_done( &rover);
}


@end


@implementation UIWindow( RenderQueue)

- (void) setClipsToBounds:(BOOL) flag
{
   assert( ! flag);
}


// not UIView because of the clipping rectangle and identity transform
// start
- (void) createRenderQueue:(struct mulle_pointerarray *) renderQueue
{
   struct mulle_pointerarrayenumerator   rover;
   UIView                                *view;
   struct RenderQueueContext             v;

   v.xform    = CGAffineTransformMakeIdentity();
   v.clipRect = CGRectMake( -INFINITY, -INFINITY, INFINITY, INFINITY);
   v.alpha    = 1.0;

   rover = mulle_pointerarray_enumerate( _subviews);
   while( _mulle_pointerarrayenumerator_next( &rover, (void **) &view))
   {
      [view createRenderQueue:renderQueue
                      context:&v];
   }
   mulle_pointerarrayenumerator_done( &rover);
}

@end
