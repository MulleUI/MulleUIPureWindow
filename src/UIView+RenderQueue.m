//
// Copyright (c) 2020 Nat!, Mulle kybernetiK
//
#import "UIView+RenderQueue.h"

#import "import-private.h"

#import "UIWindow.h"


@interface NSObject (Forward)

- (void) dumpWithIndent:(NSUInteger) indent;

@end


@implementation UIView ( RenderQueue)


static void   renderQueueAddLayer( struct mulle_pointerarray *renderQueue,
                                   id <UILayer> layer,
                                   struct UIRenderQueueContext *v)
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


#ifndef CG_COLOR_H__

static inline int   CGAlphaIsTransparentWithBitDepth( float a, unsigned int depth)
{
   return( a < 0.5 / (1LL << depth));  // (((1LL << depth) / 2) - 1));
}

static inline int   CGAlphaIsTransparent( float a)
{
   return( CGAlphaIsTransparentWithBitDepth( a, 16));
}

#endif

//
// the transform is the concatenation of the superviews transforms
// the clipRect is in window space (window bounds)
//
- (void) createRenderQueue:(struct mulle_pointerarray *) renderQueue
                   context:(struct UIRenderQueueContext *) ctx
{
   id <UILayer>                  layer;
   CGAffineTransform             projection;
   CGRect                        bounds;
   CGRect                        frame;
   CGRect                        screenRect;
   CGRect                        transformedRect;
   CGFloat                       memo;
   struct UIRenderQueueContext   v;
   UIView                        *view;

   if( [self isHidden] || [self isCulledByLayout])
      return;

   v.alpha = _alpha * ctx->alpha;
   if( CGAlphaIsTransparent( v.alpha))  // assume rounding up and 16 bit color depth
      return;

   bounds     = [self bounds];
   projection = CGAffineTransformMakeProjection( _frame, bounds);
   v.xform    = CGAffineTransformConcat( projection, ctx->xform);

   v.clipRect = ctx->clipRect;
   if( _clipsToBounds)
   {
      // actually clips to frame... sorta...
      transformedRect = CGRectApplyAffineTransform( _frame, ctx->xform);
      v.clipRect      = CGRectIntersection( ctx->clipRect, transformedRect);
   }

   //
   // if we clip to nothing we don't do anything
   // we use 0.1 for FP errors. An invalid intersection also produces
   // inf origins, which apparently is bad later on. This should implicitly
   // catch this too
   // TODO: why not check for 0.5 ?
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
      if( _shadowLayer)
      {
         // we don't clip the shadowLayer
         memo                  = v.clipRect.size.width;
         v.clipRect.size.width = INFINITY;
         renderQueueAddLayer( renderQueue, _shadowLayer, &v);
         v.clipRect.size.width = memo;
      }

      renderQueueAddLayer( renderQueue, _mainLayer, &v);

      mulle_pointerarray_for( &_layers, layer)
      {
         renderQueueAddLayer( renderQueue, layer, &v);
      }
   }

   /*
    * Subviews
    */
   mulle_pointerarray_for( &_subviews, view)
   {
      // we cull clipped views completely here
      frame      = [view frame];
      screenRect = CGRectApplyAffineTransform( frame, v.xform);
      if( CGRectIntersectsRect( v.clipRect, screenRect))
         [view createRenderQueue:renderQueue
                         context:&v];
   }
}


- (void) createRenderQueue:(struct mulle_pointerarray *) renderQueue
{
   abort(); // only UIWindow can do this currently
}


- (void) dumpRenderQueue:(struct mulle_pointerarray *) renderQueue
{
   id   layer;

   mulle_pointerarray_for( renderQueue, layer)
   {
      [layer dumpWithIndent:1];
   }
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
   UIView                       *view;
   struct UIRenderQueueContext  v;

   v.xform    = CGAffineTransformMakeIdentity();
   v.clipRect = CGRectMake( -INFINITY, -INFINITY, INFINITY, INFINITY);
   v.alpha    = 1.0;

   mulle_pointerarray_for( &_subviews, view)
   {
      [view createRenderQueue:renderQueue
                      context:&v];
   }
}

@end
