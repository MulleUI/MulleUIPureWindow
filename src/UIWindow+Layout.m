//
// Copyright (c) 2024 Nat!, Mulle kybernetiK
//
#import "UIWindow+Layout.h"

#import "import-private.h"

#import "CGFrameInfo+UTF8String.h"
#import "UIWindow+RenderQueue.h"
#import "UIWindow+UIWindow.h"
#import "UIWindow+DebugPrivate.h"

#ifdef DEBUG
# ifndef DEBUG_DUPLICATE_LAYOUT
#  define DEBUG_DUPLICATE_LAYOUT 1
# endif
#endif
#ifndef DEBUG_DUPLICATE_LAYOUT
#  define DEBUG_DUPLICATE_LAYOUT 0
#endif


@implementation UIWindow ( Layout)

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


- (UIWindowDisplayBits) preLayoutAnimations:(struct CGFrameInfo *) info
{
   BOOL                   didAnimate;
   mulle_relativetime_t   animationRate;
   UIWindowDisplayBits    displayBits;

   UIWindowRenderLog( "");

   MulleWindowProfileBegin();

   animationRate = UIWindowGetAnimationRate( self);
   didAnimate    = [_preLayoutAnimator animateWithAbsoluteTime:info->now
                                                 animationRate:animationRate];
   if( _didAnimateCallback)
      (*_didAnimateCallback)( self, info, 0);

   MulleWindowProfileEnd();

   UIWindowRenderLog( "preLayoutAnimator did %sanimate", didAnimate ? "" : "not ");

   displayBits = didAnimate ? UIWindowDisplayDidAnimate : 0;
   UIWindowDisplayBitsLog( "%s returns (0x%tx)", __FUNCTION__, displayBits);
   return( displayBits);
}


- (UIWindowDisplayBits) postLayoutAnimations:(struct CGFrameInfo *) info
{
   BOOL                   didAnimate;
   mulle_relativetime_t   animationRate;
   UIWindowDisplayBits    displayBits;

   UIWindowRenderLog( "");

   MulleWindowProfileBegin();

   //
   // Layout changing animations should be place into the preLayoutAnimator
   //
#ifdef DEBUG
   if( [_postLayoutAnimator hasLayoutChangingAnimations])
   {
      static BOOL   warn;

      if( ! warn)
      {
         MulleUILog( "Layout changing animation should be placed into the preLayoutAnimator");
         warn = YES;
      }
   }
#endif

   animationRate = UIWindowGetAnimationRate( self);
   didAnimate    = [_postLayoutAnimator animateWithAbsoluteTime:info->now
                                                  animationRate:animationRate];
   if( _didAnimateCallback)
      (*_didAnimateCallback)( self, info, 1);

   MulleWindowProfileEnd();

   UIWindowRenderLog( "postLayoutAnimator did %sanimate", didAnimate ? "" : "not ");

   displayBits = didAnimate ? UIWindowDisplayDidAnimate : 0;
   UIWindowDisplayBitsLog( "%s returns (0x%tx)", __FUNCTION__, displayBits);
   return( displayBits);
}



- (void) layout
{
   CGRect   bounds;

#if DEBUG_DUPLICATE_LAYOUT
   assert( ! _isLayouting);
   _isLayouting = YES;
   _mulle__pointerset_done( &_layoutedViews, MulleObjCInstanceGetAllocator( self));
   _mulle__pointerset_init( &_layoutedViews, 64, MulleObjCInstanceGetAllocator( self));
#endif

   bounds = [self bounds];
   [self->_view setFrame:bounds];
   [self->_view layout];

#if DEBUG_DUPLICATE_LAYOUT
   _mulle__pointerset_reset( &_layoutedViews);
   _isLayouting = NO;
#endif
   _quadtreeNeedsSetup = YES;
}


- (void) _dealloc
{
#if DEBUG_DUPLICATE_LAYOUT
   _mulle__pointerset_done( &_layoutedViews, MulleObjCInstanceGetAllocator( self));
#endif
}


- (void) layoutFrame:(struct CGFrameInfo *) info
{
   UIWindowRenderLog( "%s", CGFrameInfoUTF8String( info));

   MulleWindowProfileBegin();
   /*
    * Layout
    */
   if( _willLayoutCallback)
      (*_willLayoutCallback)( self, info);

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
      (*_didLayoutCallback)( self, info);

   MulleWindowProfileEnd();
}


//
// will be followed by "UIWindowDefaultPrepareRenderQueue", which will 
// call animateFrame: below after setting up the drawing queue
//
UIWindowDisplayBits
   UIWindowDefaultLayout( UIWindow *self,
                          struct CGFrameInfo *info,
                          UIWindowDisplayBits displayBits)
{
   //_viewsNeedTrackingAreaUpdate = NO;

   displayBits |= [self willRenderWithAbsoluteTime:info->now];
   displayBits |= [self preLayoutAnimations:info];

   if( (displayBits & (UIWindowDisplayNeedsLayout|UIWindowDisplayDidAnimate)))
   {
      [self layoutFrame:info];
      displayBits |= UIWindowDisplayNeedsRedraw | UIWindowDisplayNeedsAnimation;

      // MEMO: this gets triggered too often
      displayBits |= UIWindowDisplayNeedsMouseEvent;
   }

   displayBits |= [self postLayoutAnimations:info];
   //if( _viewsNeedTrackingAreaUpdate)
   //   displayBits |= UIWindowDisplayNeedsMouseEvent;

   UIWindowDisplayBitsLog( "%s augments (0x%tx)", __FUNCTION__, displayBits);
   return( displayBits);
}


- (UIWindowDisplayBits) animateFrame:(struct CGFrameInfo *) info
                         displayBits:(UIWindowDisplayBits) displayBits
{
   BOOL                   didAnimate;
   mulle_relativetime_t   animationRate;

   UIWindowRenderLog( "%s", CGFrameInfoUTF8String( info));

   /*
    * Animate
    */
   if( ! (displayBits & UIWindowDisplayNeedsAnimation))
      return( displayBits);

   animationRate = UIWindowGetAnimationRate( self);
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
      didAnimate |= (*_didAnimateCallback)( self, info, 2);

   if( didAnimate)
   {
      displayBits |= UIWindowDisplayDidAnimate;
      displayBits |= UIWindowDisplayNeedsRedraw;
   }
   UIWindowDisplayBitsLog( "%s returns (0x%tx)", __FUNCTION__, displayBits);
   return( displayBits);
}

@end
