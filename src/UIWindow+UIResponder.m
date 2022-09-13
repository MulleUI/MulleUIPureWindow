#import "UIWindow+UIResponder.h"


#define FIRST_RESPONDER_DEBUG


@implementation UIWindow( UIResponder)

- (id <UIResponder>) firstResponder
{
   return( _firstResponder);
}

- (id <UIResponder>) modalResponder
{
   return( _modalResponder);
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

- (BOOL) makeModalResponder:(id <UIResponder>) responder
{
   // the original _firstResponder if present must have resigned before
   // we can set any non-nil value
   assert( ! responder || ! _modalResponder);

#ifdef FIRST_RESPONDER_DEBUG
   if( responder != _modalResponder)
      MulleUILog( "change modalResponder to %#@", responder);
#endif

   _modalResponder = responder;
   return( YES);
}


@end
