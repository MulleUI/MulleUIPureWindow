#import "UIWindow+UIResponder.h"


#define FIRST_RESPONDER_DEBUG


@implementation UIWindow( UIResponder)

- (id <UIResponder>) firstResponder
{
   return( _firstResponder);
}


- (BOOL) makeFirstResponder:(id <UIResponder>) responder
{
   // the original _firstResponder if present must have resigned before
   // we can set any non-nil value
   assert( ! responder || ! _firstResponder);

#ifdef FIRST_RESPONDER_DEBUG
   if( responder != _firstResponder)
      MulleUILog( "change firstResponder to %#@", responder);
#endif

   _firstResponder = responder;
   return( YES);
}

@end
