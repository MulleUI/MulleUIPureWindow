#import <MulleUIWindow/MulleUIWindow.h>


int   main( void)
{
   UIWindowMoveEvent   *event;

   event = [[[UIWindowMoveEvent alloc] initWithMouseLocation:CGPointMake( 2, 3)
                                                   modifiers:4
                                                      origin:CGBitmapPointMake( 5, 6)] autorelease];
   printf( "type          : %td\n", [event eventType]);
   printf( "mouseLocation : %s\n",  CGPointUTF8String( [event mouseLocationInView:nil]));
   printf( "modifiers     : %td\n", [event modifiers]);
   printf( "origin        : %s\n",  CGBitmapPointUTF8String( [event origin]));

   return( 0);
}