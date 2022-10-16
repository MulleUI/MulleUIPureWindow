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



struct UIResponderSearch
{
   UIView        *referenceView;
   CGRect        referenceViewFrame;

   UIView        *best;
   CGRect        bestScreenFrame;

   CGDirection   primaryDirection;
   CGDirection   secondaryDirection;

   CGFloat       fummelX;
   CGFloat       fummelY;
};


void  UIResponderSearchInit( struct UIResponderSearch *p, 
                             id <UIResponder> responder,
                             CGDirection primaryDirection,
                             CGDirection secondaryDirection);


static inline UIView   *UIResponderSearchGetResult( struct UIResponderSearch *p)
{
   return( p ? p->best : nil);
}


static inline void  UIResponderSearchDone( struct UIResponderSearch *p)
{
}


@interface UIView( UIResponderSearch)

- (void) _firstResponderSearch:(struct UIResponderSearch *) search;

@end
