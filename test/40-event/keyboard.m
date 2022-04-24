#import <MulleUIWindow/MulleUIWindow.h>


int   main( void)
{
   UIKeyboardEvent   *event;

   event = [[[UIKeyboardEvent alloc] initWithMouseLocation:CGPointMake( 2, 3)
                                                 modifiers:4
                                                       key:5
                                                  scanCode:6
                                                    action:7] autorelease];
   printf( "type          : %td\n", [event eventType]);
   printf( "mouseLocation : %s\n",  CGPointUTF8String( [event mouseLocationInView:nil]));
   printf( "modifiers     : %td\n", [event modifiers]);
   printf( "key           : %td\n", [event key]);
   printf( "scanCode      : %td\n", [event scanCode]);
   printf( "action        : %td\n", [event action]);

   return( 0);
}