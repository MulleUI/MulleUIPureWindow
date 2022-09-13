#import <MulleUIWindow/MulleUIWindow.h>


int   main( void)
{
   UIMouseButtonEvent   *event;

   event = [[[UIMouseButtonEvent alloc] initWithLocationInWindow:CGPointMake( 2, 3)
                                                    modifiers:4
                                                       button:5
                                                       action:6] autorelease];
   printf( "type          : %td\n", [event eventType]);
   printf( "mouseLocation : %s\n",  CGPointUTF8String( [event locationInView:nil]));
   printf( "modifiers     : %td\n", [event modifiers]);
   printf( "button        : %td\n", [event button]);
   printf( "action        : %td\n", [event action]);

   return( 0);
}