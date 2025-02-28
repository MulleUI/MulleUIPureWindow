#import <MulleUIPureWindow/MulleUIPureWindow.h>

#include "../fake-ui-application-glue.inc"

int   main( void)
{
   [UIPureWindow windowWithFrame:CGRectMake( 0, 0, 100, 50)
                 titleUTF8String:"non-standard"
                       styleMask:0x0];

   [UIPureWindow windowWithFrame:CGRectMake( 0, 0, 100, 50)
                 titleUTF8String:NULL
                       styleMask:0x0];


   return( 0);
}
