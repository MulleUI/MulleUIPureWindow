
#import "UIView+UIResponder.h"

#import "UIView+UIWindow.h"
#import "UIWindow+UIResponder.h"
#import <MulleUIView/UIView+DebugPrivate.h>


@interface NSObject( UIResponder)

- (UIMouseMotionEvent *) handleMouseMotionEvent:(UIMouseMotionEvent *) event;
- (UIEvent *) handleEvent:(UIEvent *) event;

@end


@implementation UIView( UIResponder)

MULLE_OBJC_DEPENDS_ON_CATEGORY( UIView, UIEvent);


- (id <UIResponder>) nextResponder
{
   return( _superview);  // AppKit also does direct reads here
}


- (void) didBecomeFirstResponder
{
   UIViewEventLog( nil,  "");
}


- (void) didResignFirstResponder
{
   UIViewEventLog( nil,  "");
}


- (BOOL) becomeFirstResponder
{
   UIWindow           *window;
   id <UIResponder>   firstResponder;

   // I think calling this too often is not good, as it does too much
   // (later: not so much now)
   if( [self isFirstResponder])
      return( YES);
   
   UIViewEventLog( nil,  "");

   // if window is nil, the function will eventually return NO
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


- (BOOL) resignFirstResponder
{
   if( ! [self isFirstResponder])
      return( YES);

   UIViewEventLog( nil, "");

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

   // if not part of a window, no problem
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


- (UIMouseMotionEvent *) handleMouseMotionEvent:(UIMouseMotionEvent *) event
{
   // _eventCallback is never nil
   event = (self->_mouseMotionEventCallback)( self, event);
   if( ! event)
      return( event);

   // this will end up in UIResponder, which we will inherit later
   // in UIWindow
   return( [super handleMouseMotionEvent:event]);
}


- (UIEvent *) handleEvent:(UIEvent *) event
{
   // _eventCallback is never nil
   event = (self->_eventCallback)( self, event);
   if( ! event)
      return( event);

   // end up in UIResponder
   return( [super handleEvent:event]);
}


@end
