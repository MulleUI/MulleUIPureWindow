//
// Copyright (c) 2021 Nat!, Mulle kybernetiK
//
#import "UIView+UIWindow.h"

#import "import-private.h"


@interface NSObject ( UIWindow)

- (BOOL) __isUIWindow;

@end


@implementation UIView ( UIWindow)

- (UIWindow *) window
{
   UIView   *view;
   UIView   *parent;

   for( view = self; (parent = view->_superview); view = parent)
   {
   }

   if( [view __isUIWindow])
      return( (UIWindow *) view);
   return( nil);
}

@end
