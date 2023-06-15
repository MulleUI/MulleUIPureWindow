#import "UITrackingArea.h"

#import "import-private.h"



@implementation UITrackingArea 


+ (instancetype) trackingAreaWithRect:(CGRect) rect
{
   return( [[[self alloc] initWithRect:rect 
                                 owner:nil 
                                cursor:NULL
                              userInfo:nil 
                               options:0] autorelease]);
}


+ (instancetype) trackingAreaWithRect:(CGRect) rect
                                owner:(id) owner 
                               cursor:(UICursor *) cursor
                             userInfo:(id) userInfo
                              options:(NSUInteger) options
{
   return( [[[self alloc] initWithRect:rect 
                                 owner:owner 
                                cursor:cursor
                              userInfo:userInfo 
                               options:options] autorelease]);
}


- (instancetype) initWithRect:(CGRect) rect 
                        owner:(id) owner 
                       cursor:(UICursor *) cursor
                     userInfo:(id) userInfo
                      options:(NSUInteger) options
{
   if( cursor)
      options |= UITrackingSetCursor;

   self->_owner    = owner;
   self->_rect     = rect;
   if( ! (options & UITrackingAssignUserInfo))
      userInfo = [userInfo retain];
   self->_userInfo = userInfo;
   self->_cursor   = cursor;
   self->_options  = options;
   return( self);
}


- (instancetype) initWithRect:(CGRect) rect 
                      options:(NSUInteger) options
                        owner:(id) owner 
                     userInfo:(id) userInfo
{
   return( [self initWithRect:rect  
                        owner:owner
                       cursor:NULL
                     userInfo:userInfo
                      options:options]);
}


- (void) dealloc
{
   if( ! (self->_options & UITrackingAssignUserInfo))
      [self->_userInfo release];
   [super dealloc];
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

@end 
