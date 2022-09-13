#import <MulleUIWindow/MulleUIWindow.h>


int   main( void)
{
   UIMouseScrollEvent   *event;

   event = [[[UIMouseScrollEvent alloc] initWithLocationInWindow:CGPointMake( 2, 3)
                                                    modifiers:4
                                                 scrollOffset:CGPointMake( 5, 6)] autorelease];
   printf( "type          : %td\n", [event eventType]);
   printf( "mouseLocation : %s\n",  CGPointUTF8String( [event locationInView:nil]));
   printf( "modifiers     : %td\n", [event modifiers]);
   printf( "scrollOffset  : %s\n",  CGPointUTF8String( [event scrollOffset]));

   return( 0);
}