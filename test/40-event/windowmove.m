#import <MulleUIWindow/MulleUIWindow.h>


int   main( void)
{
   UIWindowMoveEvent   *event;

   event = [[[UIWindowMoveEvent alloc] initWithLocationInWindow:CGPointMake( 2, 3)
                                                   modifiers:4
                                                      origin:MulleIntegerPointMake( 5, 6)] autorelease];
   printf( "type          : %td\n", [event eventType]);
   printf( "mouseLocation : %s\n",  CGPointUTF8String( [event locationInView:nil]));
   printf( "modifiers     : %td\n", [event modifiers]);
   printf( "origin        : %s\n",  MulleIntegerPointUTF8String( [event origin]));

   return( 0);
}