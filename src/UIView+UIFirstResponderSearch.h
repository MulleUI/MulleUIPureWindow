//
// Copyright (c) 2022 Nat!, Mulle kybernetiK
//
// prefer a local UIView over one in import.h
#ifdef __has_include
# if __has_include( "UIView.h")
#  import "UIView.h"
# endif
#endif

// we want "import.h" always anyway
#import "import.h"


struct UIFirstResponderSearch
{
   UIView        *referenceView;
   CGRect        referenceViewFrame;

   UIView        *best;
   CGRect        bestScreenFrame;

   CADirection   primaryDirection;
   CADirection   secondaryDirection;

   CGFloat       fummelX;
   CGFloat       fummelY;
};


void  UIFirstResponderSearchInit( struct UIFirstResponderSearch *p,
                             id <UIResponder> responder,
                             CADirection primaryDirection,
                             CADirection secondaryDirection);


static inline UIView   *UIFirstResponderSearchGetResult( struct UIFirstResponderSearch *p)
{
   return( p ? p->best : nil);
}


static inline void  UIFirstResponderSearchDone( struct UIFirstResponderSearch *p)
{
}


@interface UIView( UIFirstResponderSearch)

- (void) _firstResponderSearch:(struct UIFirstResponderSearch *) search;

@end
