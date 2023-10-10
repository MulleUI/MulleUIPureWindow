#import "UIWindow+UIResponder.h"

#import "UIWindow+DebugPrivate.h"

#import "UIView+UIResponder.h"
#import "UIView+UIResponderSearch.h"

//#define FIRST_RESPONDER_DEBUG

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

   if( responder != _firstResponder)
      UIWindowEventLog( nil, "change firstResponder to %#@", responder);

   _firstResponder = responder;
   return( YES);
}


- (id <UIResponder>) firstResponderSearchInPrimaryDirection:(CADirection) primaryDirection
                                         secondaryDirection:(CADirection) secondaryDirection
{
   struct UIResponderSearch   search;
   id <UIResponder>           best;

   UIResponderSearchInit( &search, _firstResponder, primaryDirection, secondaryDirection);
   [[self contentView] _firstResponderSearch:&search];
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

   return( [self firstResponderSearchInPrimaryDirection:CADirectionTop
                                     secondaryDirection:CADirectionLeft]);
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
   return( [self firstResponderSearchInPrimaryDirection:CADirectionBottom
                                     secondaryDirection:CADirectionRight]);
}


- (UIInputEvent *) acceptKeyboardEvent:(UIKeyboardEvent *) event
{
   NSUInteger   key;
   NSUInteger   modifiers;

   UIWindowEventLog( event, "key: %ld scanCode: %ld modifiers: %ld",
                        (long) [event key], 
                        (long) [event scanCode],
                        (long) [event keyModifiers]);

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
