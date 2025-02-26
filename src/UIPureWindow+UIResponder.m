#import "UIPureWindow+UIResponder.h"

#import "UIPureWindow+DebugPrivate.h"

//#define FIRST_RESPONDER_DEBUG

@implementation UIPureWindow( UIResponder)

- (id <UIResponder>) firstResponder
{
   return( _firstResponder);
}


- (BOOL) makeFirstResponder:(id <UIResponder>) responder
{
   BOOL   changed;

   // the original _firstResponder if present must have resigned before
   // we can set any non-nil value
   assert( ! responder || ! _firstResponder);

   changed = responder != _firstResponder;
   _firstResponder = responder;

   if( changed)
   {
      UIWindowEventLog( nil, "change firstResponder to %#@", responder);

      // MEMO: this is obscure, but for views that do mouse tracking, they
      //       need to have the window subscribed to mouse motion events.
      //       But mouse motion events subscription is only passed down to
      //       the OSWindow when a display occurs. If you do
      //       makeFirstResponder: in mouseDown: and no other changes, the
      //       request for mouseMotion events will not propagate.
      [self setNeedsDisplay];
   }
   return( YES);
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

   return( nil);
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
   return( nil);
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
