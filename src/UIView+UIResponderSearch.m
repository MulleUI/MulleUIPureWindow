//
// Copyright (c) 2022 Nat!, Mulle kybernetiK
//
#import "UIView+UIResponderSearch.h"

#import "import-private.h"

#import "UIView+UIResponder.h"


// #define SEARCH_DEBUG      

//
// 1. get coordinates, where we want the responder to be 
//    near. Find best matching candidate who is before
//    or after.
//


#define FUMMEL_X_DEFAULT   2.0
#define FUMMEL_Y_DEFAULT   8.0
#define FUMMEL_Y_FACTOR    4.0


//
// add fuzzy factor to these comparisons, os that same Level
// actually is +/- a couple of pixels
//
// static inline BOOL  isBetter( CGFloat a, CGFloat b)
// {
//    return( a > b);
// }

static inline BOOL  isWorse( CGFloat a, CGFloat b)
{
   return( a < b);
}


static inline BOOL  isCloser( CGFloat a, CGFloat b)
{
   return( a < b);
}


static inline BOOL  isSame( CGFloat a, CGFloat b)
{
   return( a == b);
}


static inline BOOL  isSameLevel( CGFloat a)
{
   return( a == 0.0);
}


static inline BOOL  isWrongDirection( CGFloat a)
{
   return( a < 0.0);
}


static inline BOOL  isRightDirection( CGFloat a)
{
   return( a >= 0.0);
}


void  UIResponderSearchInit( struct UIResponderSearch *p, 
                             id <UIResponder> responder,
                             CADirection primaryDirection,
                             CADirection secondaryDirection)
{
   CGRect   frame;
   UIView   *view;

   if( ! p)
      return;

   view = nil;
   memset( p, 0, sizeof( *p));
   if( responder && [responder isKindOfClass:[UIView class]])
   {
      view                  = (UIView *) responder;
      p->referenceView      = view;
      frame                 = [view frame];
      p->referenceViewFrame = [view convertRect:frame 
                                         toView:nil];

      if( p->referenceViewFrame.size.width <= 0.0)
         p->referenceViewFrame.size.width = 1.0;
      if( p->referenceViewFrame.size.height < FUMMEL_Y_FACTOR)
         p->referenceViewFrame.size.height = FUMMEL_Y_FACTOR;
   }

   p->best               = nil;
   p->bestScreenFrame    = CGRectNull;

   p->primaryDirection   = primaryDirection;
   p->secondaryDirection = secondaryDirection;

   p->fummelX            = roundf( FUMMEL_X_DEFAULT);
   p->fummelY            = roundf( view ? (p->referenceViewFrame.size.height / FUMMEL_Y_FACTOR) 
                                       : FUMMEL_Y_DEFAULT);
}


//
// to get rid of small errors in placement and rounding only 
// make the floats more coarse. Be more coarse in Y direction
// 
static inline CGFloat   UIResponderSearchFummelFloatX( struct UIResponderSearch *p, 
                                                       CGFloat value)
{
   return( roundf( value / p->fummelX) * p->fummelX);
} 


static inline CGFloat   UIResponderSearchFummelFloatY( struct UIResponderSearch *p, 
                                                       CGFloat value)
{
   return( roundf( value / p->fummelY) * p->fummelY);
} 


static void  UIResponderSearchAddView( struct UIResponderSearch *p, 
                                            UIView *view)
{
   CGRect   screenFrame;
   CGFloat  x;
   CGFloat  bestX;
   CGFloat  referenceX;
   CGFloat  y;
   CGFloat  bestY;
   CGFloat  referenceY;
   BOOL     bestIsWorst;

   screenFrame = [view convertRect:[view frame]
                            toView:nil];

   if( ! p->best)
   {
      p->best            = view;
      p->bestScreenFrame = screenFrame;
#ifdef SEARCH_DEBUG      
      MulleUICLog( "first");
#endif      
      return;  
   }

   // MEMO: the code is written for CADirectionBottom/CADirectionRight.
   //       For other directions we use different axis information and
   //       flip things around
   switch( p->primaryDirection)
   {
   case CADirectionLeft   :
      referenceY = CGRectGetMidX( p->referenceViewFrame);
      y          = referenceY - CGRectGetMidX( screenFrame);
      bestY      = referenceY - CGRectGetMidX( p->bestScreenFrame);
      break;

   case CADirectionRight  :
      referenceY = CGRectGetMidX( p->referenceViewFrame);
      y          = CGRectGetMidX( screenFrame) - referenceY;
      bestY      = CGRectGetMidX( p->bestScreenFrame) - referenceY;
      break;

   case CADirectionTop    :
      referenceY = CGRectGetMidY( p->referenceViewFrame);
      y          = referenceY - CGRectGetMidY( screenFrame);
      bestY      = referenceY - CGRectGetMidY( p->bestScreenFrame);
      break;

   case CADirectionBottom :
      referenceY = CGRectGetMidY( p->referenceViewFrame);
      y          = CGRectGetMidY( screenFrame) - referenceY;
      bestY      = CGRectGetMidY( p->bestScreenFrame) - referenceY;
      break;
   }    

   switch( p->secondaryDirection)
   {
   case CADirectionLeft   :
      referenceX = CGRectGetMidX( p->referenceViewFrame);
      x          = referenceX - CGRectGetMidX( screenFrame);
      bestX      = referenceX - CGRectGetMidX( p->bestScreenFrame);
      break;

   case CADirectionRight  :
      referenceX = CGRectGetMidX( p->referenceViewFrame);
      x          = CGRectGetMidX( screenFrame) - referenceX;
      bestX      = CGRectGetMidX( p->bestScreenFrame) - referenceX;
      break;

   case CADirectionTop    :
      referenceX = CGRectGetMidY( p->referenceViewFrame);
      x          = referenceX - CGRectGetMidY( screenFrame);
      bestX      = referenceX - CGRectGetMidY( p->bestScreenFrame);
      break;

   case CADirectionBottom :
      referenceX = CGRectGetMidY( p->referenceViewFrame);
      x          = CGRectGetMidY( screenFrame) - referenceX;
      bestX      = CGRectGetMidY( p->bestScreenFrame) - referenceX;
      break;
   }

#ifdef SEARCH_DEBUG      
   MulleUICLog( "x: %.1f y: %.1f bestX: %.1f bestY: %.1f", x, y, bestX, bestY);
#endif
   x     = UIResponderSearchFummelFloatX( p, x);
   y     = UIResponderSearchFummelFloatY( p, y);
   bestX = UIResponderSearchFummelFloatX( p, bestX);
   bestY = UIResponderSearchFummelFloatY( p, bestY);

#ifdef SEARCH_DEBUG      
   MulleUICLog( "x: %.1f y: %.1f bestX: %.1f bestY: %.1f", x, y, bestX, bestY);
#endif
   //
   // if best is not really best, try to actually make best the worst
   //
   bestIsWorst = NO;
   if( isWrongDirection( bestY) || (isSameLevel( bestY) && isWrongDirection( bestX)))
   {  
      bestIsWorst = YES;  
      if( isWorse( y, bestY) || (isSame( y, bestY) && isWorse( x, bestX)))
      {
         p->best            = view;
         p->bestScreenFrame = screenFrame;  
#ifdef SEARCH_DEBUG      
         MulleUICLog( "worst");
#endif         
         return;
      }
   }

   // if y is above ignore
   if( isWrongDirection( y))
   {
#ifdef SEARCH_DEBUG      
      MulleUICLog( "bad primary direction");
#endif      
      return;
   }

   // if y on the same row 
   if( isSameLevel( y))
   {
      if( ! isRightDirection( x))
      {
#ifdef SEARCH_DEBUG      
         MulleUICLog( "wrong x direction");
#endif         
         return;
      }

      if( ! isSameLevel( bestY))
      {
#ifdef SEARCH_DEBUG      
         MulleUICLog( "on same row and right direction, best is not on same row");
#endif         
         p->best            = view;
         p->bestScreenFrame = screenFrame;  
         return;
      }

      // best is also on same row
      if( ! isRightDirection( bestX) || isCloser( x, bestX))
      {
#ifdef SEARCH_DEBUG      
         MulleUICLog( "better on same row");
#endif         
         p->best            = view;
         p->bestScreenFrame = screenFrame;  
         return;
      }
   }

   if( bestIsWorst)
   {
#ifdef SEARCH_DEBUG      
      MulleUICLog( "valid and better than best");
#endif      
      p->best            = view;
      p->bestScreenFrame = screenFrame;  
      return;
   }

   // gotta be on a row below 
   if( isCloser( y, bestY) || (isSame( y, bestY) && isCloser( x, bestX)))
   {
#ifdef SEARCH_DEBUG      
      MulleUICLog( "better than bestX");
#endif      
      p->best            = view;
      p->bestScreenFrame = screenFrame;  
      return;
   }

#ifdef SEARCH_DEBUG      
   MulleUICLog( "further away");
#endif   
}


@implementation UIView( UIResponderSearch)


- (void) _firstResponderSearch:(struct UIResponderSearch *) search
{
   UIView   *view;

   assert( search);

#ifdef SEARCH_DEBUG      
   MulleUILog( "%s", CGRectUTF8String( [self convertRect:[self frame] toView:nil]));
#endif
   if( self != search->referenceView)
   {
      if( [self canBecomeFirstResponder])
         UIResponderSearchAddView( search, self);
      else
      {
#ifdef SEARCH_DEBUG      
         MulleUILog( "can't become firstResponder");
#endif         
      }
   }
   else
   {
#ifdef SEARCH_DEBUG      
      MulleUILog( "is firstResponder already");
#endif      
   }
   mulle_pointerarray_for( &_subviews, view)
   {
      [view _firstResponderSearch:search];
   }
}

@end 

