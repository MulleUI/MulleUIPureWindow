#import "UITrackingArea.h"

#import "import-private.h"

#import "UIWindow.h"
#import "UIView+UIWindow.h"
#import "UIView+UITrackingArea.h"
#import "UIView+UIFirstResponder.h"
#import "UIWindow+NSTimer.h"
#import "UIWindow+UIResponder.h"
#import "UIWindow+UITrackingArea.h"


@implementation UITrackingArea 


+ (instancetype) trackingAreaWithRect:(CGRect) rect
{
   return( [[[self alloc] initWithRect:rect
                               options:0
                                 owner:nil 
                              userInfo:nil] autorelease]);
}


+ (instancetype) trackingAreaWithRect:(CGRect) rect
                              options:(UITrackingAreaOptions) options
                                owner:(id) owner 
                             userInfo:(id) userInfo
{
   return( [[[self alloc] initWithRect:rect 
                               options:options
                                 owner:owner 
                              userInfo:userInfo] autorelease]);
}


- (instancetype) initWithRect:(CGRect) rect 
                      options:(UITrackingAreaOptions) options
                        owner:(id) owner 
                     userInfo:(id) userInfo
{
   if( CGRectGetArea( rect) == 0.0f)
   {
      [self release];
      return( nil);
   }

   self->_owner                = owner;
   self->_rect                 = rect;
   self->_trackingAreaOptions  = options;

   if( ! (options & UITrackingAssignUserInfo))
      userInfo = [userInfo retain];
   self->_userInfo = userInfo;
   return( self);
}


- (void) finalize
{
   [_hoverTimer mullePerformFinalize]; // oughta be superflous or ?
   [super finalize];
}


- (void) dealloc
{
   if( ! (self->_trackingAreaOptions & UITrackingAssignUserInfo))
      [self->_userInfo release];
   [super dealloc];
}


- (BOOL) isTrackingActiveAtLocation:(CGPoint) location
                           inWindow:(UIWindow *) window
{
   CGRect   visibleRect;
   CGRect   rect;
   UIView   *hitView;

   if( _trackingAreaOptions & UITrackingActiveWhenFirstResponder)
   {
      if( [window firstResponder] != _view)
         return( NO);
   }

   if( _trackingAreaOptions & UITrackingAreaReceivesObscuredEvents)
      return( YES);

   // try to keep it as cheap as possible
   visibleRect = [_view visibleWindowRect];
   if( ! CGRectContainsPoint( visibleRect, location))
      return( NO);

   rect = [_view convertRect:_rect
                      toView:nil];
   if( ! CGRectContainsPoint( rect, location))
      return( NO);

   if( _trackingAreaOptions & UITrackingVisibleRectOnly)
   {
      hitView  = [window contentView];
      hitView  = [hitView hitTest:location
                        withEvent:nil];
      return( hitView == _view);
   }
   return( YES);
}


- (CGRect) frame
{
   return( _rect);
}


- (void) setCursor:(UICursor *) cursor
{
   if( cursor)
      _trackingAreaOptions |= UITrackingSetCursor;
   else
      _trackingAreaOptions &= ~UITrackingSetCursor;

   _cursor = cursor;
}


- (void) setUserInfo:(id) userInfo
{
   if( ! (self->_trackingAreaOptions & UITrackingAssignUserInfo))
   {
      [self->_userInfo autorelease];
      userInfo = [userInfo retain];
   }

   _userInfo = userInfo;
}


static void   UITrackingAreaHoverTimerCallback( NSTimer *inTimer, id userInfo)
{
   UITrackingArea   *self = userInfo;
   UIWindow         *window;

   MulleUICLog( "timer=%#@ userInfo=%#@", inTimer, userInfo);

   window = MULLE_OBJC_CLASS_CAST( UIWindow, [self->_view window]);
   [window startMouseHoverOverTrackingArea:self];
}


/*
 * Hover support
 */

- (void) stopHoverTimerWithWindow:(UIWindow *) window
{
   if( self->_hoverTimer)
   {
      [window removeTimer:self->_hoverTimer];
      self->_hoverTimer = nil;
   }
}


// MEMO could also put _hoverTimer on UITrackingArea really and do all
// of this in UIWindow or ?
- (void) startHoverTimerWithWindow:(UIWindow *) window
{
   if( self->_hoverTimer)
      [self stopHoverTimerWithWindow:window];

   assert( ! self->_hoverTimer);
   self->_hoverTimer = [[NSTimer alloc] mulleInitWithRelativeTimeInterval:[_view hoverTimeInterval]
                                                           repeatInterval:0.0
                                                                 callback:UITrackingAreaHoverTimerCallback
                                                                 userInfo:self];

   window = MULLE_OBJC_CLASS_CAST( UIWindow, [_view window]);
   [window addTimer:self->_hoverTimer];
}


- (void) resetHoverTimerWithWindow:(UIWindow *) window
{
   if( ! self->_hoverTimer)
   {
      [self startHoverTimerWithWindow:window];
      return;
   }

   [window resetTimer:self->_hoverTimer];
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


- (void) dumpWithIndent:(NSUInteger) indent
                   FILE:(FILE *) fp
{
   NSUInteger   i;

   for( i = 0; i < indent; i++)
      fputc( ' ', fp);

   fprintf( fp, "<%s %p>: rect=[%s] tag=[%td]\n",
               MulleObjCObjectGetClassNameUTF8String( self),
               self,
               CGRectUTF8String( [self rect]),
               [self tag]);
}

@end 
