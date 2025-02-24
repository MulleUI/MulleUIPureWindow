//
// Copyright (c) 2024 Nat!, Mulle kybernetiK
//
#import "UIWindow+RenderQueue.h"

#import "import-private.h"

#import "UIWindow+DebugPrivate.h"
#import "UIView+RenderQueue.h"
#import "CGFrameInfo+UTF8String.h"


@implementation UIWindow ( RenderQueue)

- (UIWindowDisplayBits) willRenderWithAbsoluteTime:(mulle_absolutetime_t) renderStart
{
   UIView               *view;
   UIWindowDisplayBits  displayBits;
   UIWindowDisplayBits  bits;

   UIWindowRenderLog( "%.6f", renderStart);

   displayBits = 0;
   mulle_pointerarray_for( &_renderDelegates, view)
   {
      bits         = [view willRenderWithAbsoluteTime:renderStart];
      UIWindowDisplayBitsLog( "-[%@ willRenderWithAbsoluteTime:] returned (0x%tx)", view, bits);
      displayBits |= bits;
   }

   UIWindowRenderLog( "%s returns (0x%tx)", __FUNCTION__, displayBits);
   return( displayBits);
}


- (void) createDrawingQueueForFrame:(struct CGFrameInfo *) info
{
   UIWindowRenderLog( "%s", CGFrameInfoUTF8String( info));

   MulleWindowProfileBegin();

   _mulle_pointerarray_reset( &_drawingQueue);
   [self createRenderQueue:&_drawingQueue];
   if( _didCreateRenderQueueCallback)
      (*_didCreateRenderQueueCallback)( self, info);

   MulleWindowProfileEnd();
}


- (void) setClipsToBounds:(BOOL) flag
{
   assert( ! flag);
}


//
// not UIView because of the clipping rectangle and identity transform
// start
//
- (void) createRenderQueue:(struct mulle_pointerarray *) renderQueue
{
   struct UIRenderQueueContext  v;

   v.xform    = CGAffineTransformMakeIdentity();
   v.clipRect = CGRectMake( -INFINITY, -INFINITY, INFINITY, INFINITY);
   v.alpha    = 1.0;

   //UIViewSubviewsFor( self->_view, view)
   {
      [self->_view createRenderQueue:renderQueue
                            context:&v];
   }
}

@end
