#import <MulleUIPureWindow/MulleUIPureWindow.h>

#include "../fake-ui-application-glue.inc"

int   main( void)
{
   [UIPureWindow windowWithFrame:CGRectMake( 0, 0, 100, 50)
                 titleUTF8String:"non-standard"
                       styleMask:UIWindowStyleMaskDefault];

   [UIPureWindow windowWithFrame:CGRectMake( 0, 0, 100, 50)
                 titleUTF8String:NULL
                       styleMask:UIWindowStyleMaskDefault];


   return( 0);
}
