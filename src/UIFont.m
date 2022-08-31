#define _GNU_SOURCE // for strrchr
#import "UIFont.h"


@implementation UIFont


+ (instancetype) fontWithNameUTF8String:(char *) name
{
   return( [self fontWithNameUTF8String:name
                                   size:12.0]);
}


+ (instancetype) fontWithNameUTF8String:(char *) name
                                   size:(CGFloat) pointSize
{
   UIFont   *font;

   font = [[[self alloc] init] autorelease];
   [font setFontNameUTF8String:name];
   [font setPointSize:pointSize];
   return( font);
}


+ (instancetype) boldSystemFontOfSize:(CGFloat) pointSize
{
   return( [self fontWithNameUTF8String:"sans"
                                   size:pointSize]);
}


- (void) dealloc
{
   struct mulle_allocator  *allocator;

   allocator = MulleObjCInstanceGetAllocator( self);
   mulle_allocator_free( allocator, _fontNameUTF8String);
   [super dealloc];
}


- (void) setFontNameUTF8String:(char *) s
{
   MulleObjCObjectSetDuplicatedUTF8String( self, &_fontNameUTF8String, s);
}

@end
