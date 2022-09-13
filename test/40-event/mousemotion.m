#import <MulleUIWindow/MulleUIWindow.h>


int   main( void)
{
   UIMouseMotionEvent   *event;

   event = [[[UIMouseMotionEvent alloc] initWithLocationInWindow:CGPointMake( 2, 3)
                                                    modifiers:4
                                                 buttonStates:5] autorelease];
   printf( "type          : %td\n", [event eventType]);
   printf( "mouseLocation : %s\n",  CGPointUTF8String( [event locationInView:nil]));
   printf( "modifiers     : %td\n", [event modifiers]);
   printf( "buttonStates  : %td\n", [event buttonStates]);

   return( 0);
}