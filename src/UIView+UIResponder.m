
#import "UIView+UIResponder.h"

#import "UIView+UIWindow.h"
#import "UIWindow+UIResponder.h"


@implementation UIView( UIResponder)

- (id <UIResponder>) nextResponder
{
   return( _superview);  // AppKit also does direct reads here
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
   [window makeFirstResponder:self];
   return( YES);
}


- (void) didResignFirstResponder
{
}


- (BOOL) resignFirstResponder
{
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


- (BOOL) becomeModalResponder
{
   UIWindow           *window;
   id <UIResponder>   modalResponder;

   // I think calling this too often is not good, as it does too much
   // (later: not so much now)
   if( [self isFirstResponder])
      return( YES);
   
   window         = (UIWindow *) _window;
   modalResponder = [window modalResponder];
   if( modalResponder)
   {   
      if( modalResponder == self)
         return( YES);
      if( ! [modalResponder canResignModalResponder])
         return( NO);
      if( ! [modalResponder resignModalResponder])
         return( NO);
   }
   [window makeModalResponder:self];
   return( YES);
}


- (void) didResignModalResponder
{
}


- (BOOL) resignModalResponder
{
   if( [(UIWindow *) _window makeModalResponder:nil])
   {
      [self didResignModalResponder];
      return( YES);
   }
   return( NO);
}


- (BOOL) isModalResponder
{
   id    responder;

   responder = [(UIWindow *) _window modalResponder];
   return( responder == self);
}


@end
