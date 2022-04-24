#import <MulleUIWindow/MulleUIWindow.h>


int   main( void)
{
   UIWindowResizeEvent   *event;

   event = [[[UIWindowResizeEvent alloc] initWithMouseLocation:CGPointMake( 2, 3)
                                                     modifiers:4
                                                          size:CGBitmapSizeMake( 5, 6)] autorelease];
   printf( "type          : %td\n", [event eventType]);
   printf( "mouseLocation : %s\n",  CGPointUTF8String( [event mouseLocationInView:nil]));
   printf( "modifiers     : %td\n", [event modifiers]);
   printf( "size          : %s\n",  CGBitmapSizeUTF8String( [event size]));

   return( 0);
}