
#import "UIView+UIResponder.h"

#import "UIView+UIWindow.h"
#import "UIWindow+UIResponder.h"


@implementation UIView( UIResponder)


- (id <UIResponder>) nextResponder
{
   return( _superview);  // AppKit also does direct reads here
}


- (void) didBecomeFirstResponder
{
}


- (BOOL) becomeFirstResponder
{
   UIWindow           *window;
   id <UIResponder>   firstResponder;

   // I think calling this too often is not good, as it does too much
   // (later: not so much now)
   if( [self isFirstResponder])
      return( YES);
   
   window         = (UIWindow *) _window;
   firstResponder = [window firstResponder];
   if( firstResponder)
   {   
      if( firstResponder == self)
         return( YES);
      if( ! [firstResponder canResignFirstResponder])
         return( NO);
      if( ! [firstResponder resignFirstResponder])
         return( NO);
   }
   
   if( [(UIWindow *) _window makeFirstResponder:self])
   {
      [self didBecomeFirstResponder];
      return( YES);
   }
   return( NO);
}


- (void) didResignFirstResponder
{
}


- (BOOL) resignFirstResponder
{
   if( ! [self isFirstResponder])
      return( YES);

   if( [(UIWindow *) _window makeFirstResponder:nil])
   {
      [self didResignFirstResponder];
      return( YES);
   }
   return( NO);
}


- (BOOL) isFirstResponder
{
   id    responder;

   responder = [(UIWindow *) _window firstResponder];
   return( responder == self);
}


- (id <UIResponder>) previousFirstResponder
{
   return( nil);
}


- (id <UIResponder>) nextFirstResponder
{
   return( nil);
}

@end
