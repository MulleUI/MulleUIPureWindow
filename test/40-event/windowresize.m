#import <MulleUIWindow/MulleUIWindow.h>


int   main( void)
{
   UIWindowResizeEvent   *event;

   event = [[[UIWindowResizeEvent alloc] initWithLocationInWindow:CGPointMake( 2, 3)
                                                     modifiers:4
                                                          size:MulleIntegerSizeMake( 5, 6)] autorelease];
   printf( "type          : %td\n", [event eventType]);
   printf( "mouseLocation : %s\n",  CGPointUTF8String( [event locationInView:nil]));
   printf( "modifiers     : %td\n", [event modifiers]);
   printf( "size          : %s\n",  MulleIntegerSizeUTF8String( [event size]));

   return( 0);
}