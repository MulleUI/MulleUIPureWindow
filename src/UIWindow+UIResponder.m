#import "UIWindow+UIResponder.h"


#import "UIView+UIResponder.h"
#import "UIView+UIResponderSearch.h"

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


- (id <UIResponder>) firstResponderSearchInPrimaryDirection:(CGDirection) primaryDirection
                                         secondaryDirection:(CGDirection) secondaryDirection
{
   struct UIResponderSearch   search;
   id <UIResponder>           best;

   UIResponderSearchInit( &search, _firstResponder, primaryDirection, secondaryDirection);
   [[self contentPlane] _firstResponderSearch:&search];
   best = UIResponderSearchGetResult( &search);
   UIResponderSearchDone( &search);
   
   return( best);
}


- (id <UIResponder>) previousFirstResponder
{
   id <UIResponder>  responder;

   if( [_firstResponder respondsToSelector:_cmd])
   {
      responder = [(id) _firstResponder previousFirstResponder];
      if( responder)
         return( responder);
   }

   return( [self firstResponderSearchInPrimaryDirection:CGDirectionTop
                                     secondaryDirection:CGDirectionLeft]);
}


- (id <UIResponder>) nextFirstResponder
{
   id <UIResponder>  responder;

   if( [_firstResponder respondsToSelector:_cmd])
   {
      responder = [(id) _firstResponder nextFirstResponder];
      if( responder)
         return( responder);
   }
   return( [self firstResponderSearchInPrimaryDirection:CGDirectionBottom
                                     secondaryDirection:CGDirectionRight]);
}


- (UIInputEvent *) handleKeyboardEvent:(UIKeyboardEvent *) event
{
   NSUInteger   key;
   NSUInteger   modifiers;

#ifdef DEBUG
   MulleUILog( "key: %ld scanCode: %ld modifiers: %ld", 
                        (long) [event key], 
                        (long) [event scanCode],
                        (long) [event keyModifiers]);
#endif 

   key       = [event key];
   modifiers = [event keyModifiers];
   switch( key)
   {
   case 258  : // TAB
      if( modifiers & UIEventKeyModifierShift)
         [[self previousFirstResponder] becomeFirstResponder];
      else
         [[self nextFirstResponder] becomeFirstResponder];
      return( nil);
   }
   return( event);
}

@end
