#import "UITrackingArea.h"

#import "import-private.h"

#import "UIWindow.h"
#import "UIView+UIWindow.h"
#import "UIView+UIResponder.h"
#import "UIWindow+UIResponder.h"


@implementation UITrackingArea 


+ (instancetype) trackingAreaWithRect:(CGRect) rect
{
   return( [[[self alloc] initWithRect:rect
                               options:0
                                 owner:nil 
                              userInfo:nil] autorelease]);
}


+ (instancetype) trackingAreaWithRect:(CGRect) rect
                              options:(NSUInteger) options
                                owner:(id) owner 
                             userInfo:(id) userInfo
{
   return( [[[self alloc] initWithRect:rect 
                               options:options
                                 owner:owner 
                              userInfo:userInfo] autorelease]);
}


- (instancetype) initWithRect:(CGRect) rect 
                      options:(NSUInteger) options
                        owner:(id) owner 
                     userInfo:(id) userInfo
{
   if( CGRectGetArea( rect) == 0.0f)
   {
      [self release];
      return( nil);
   }

   self->_owner    = owner;
   self->_rect     = rect;
   if( ! (options & UITrackingAssignUserInfo))
      userInfo = [userInfo retain];
   self->_userInfo = userInfo;
   self->_options  = options;
   return( self);
}


- (void) dealloc
{
   if( ! (self->_options & UITrackingAssignUserInfo))
      [self->_userInfo release];
   [super dealloc];
}


- (BOOL) isTrackingActiveAtLocation:(CGPoint) location
                           inWindow:(UIWindow *) window
{
   CGRect   visibleRect;
   CGRect   rect;
   UIView   *hitView;

   if( _options & UITrackingActiveWhenFirstResponder)
   {
      if( [window firstResponder] != _view)
         return( NO);
   }

   if( _options & UITrackingAreaReceivesObscuredEvents)
      return( YES);

   // try to keep it as cheap as possible
   visibleRect = [_view visibleWindowRect];
   if( ! CGRectContainsPoint( visibleRect, location))
      return( NO);

   rect = [_view convertRect:_rect
                      toView:nil];
   if( ! CGRectContainsPoint( rect, location))
      return( NO);

   if( _options & UITrackingVisibleRectOnly)
   {
      hitView = [window hitTest:location
                      withEvent:nil];
      return( hitView == _view);
   }
   return( YES);
}


- (char  *) UTF8String
{
   char   *s;

   s = MulleObjC_asprintf( "{%.2f %.2f %.2f %.2f owner=%#@ cursor=%p}",
            self->_rect.origin.x, 
            self->_rect.origin.y, 
            self->_rect.size.width, 
            self->_rect.size.height,
            self->_owner, 
            self->_cursor); 
   return( s);
}


- (CGRect) frame
{
   return( _rect);
}


- (void) setCursor:(UICursor *) cursor
{
   if( cursor)
      _options |= UITrackingSetCursor;
   else
      _options &= ~UITrackingSetCursor;

   _cursor = cursor;
}


- (void) setUserInfo:(id) userInfo
{
   if( ! (self->_options & UITrackingAssignUserInfo))
   {
      [self->_userInfo autorelease];
      userInfo = [userInfo retain];
   }

   _userInfo = userInfo;
}


@end 
