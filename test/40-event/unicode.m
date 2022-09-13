#import <MulleUIWindow/MulleUIWindow.h>


int   main( void)
{
   UIUnicodeEvent   *event;

   event = [[[UIUnicodeEvent alloc] initWithLocationInWindow:CGPointMake( 2, 3)
                                                modifiers:4
                                                character:5] autorelease];
   printf( "type          : %td\n", [event eventType]);
   printf( "mouseLocation : %s\n",  CGPointUTF8String( [event locationInView:nil]));
   printf( "modifiers     : %td\n", [event modifiers]);
   printf( "character     : %td\n", [event character]);

   return( 0);
}