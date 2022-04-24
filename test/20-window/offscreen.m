#import <MulleUIWindow/MulleUIWindow.h>


int   main( void)
{
   UIApplication   *app;
   UIWindow        *window;
   NSUInteger      styleMask;

   styleMask = UIWindowStyleMaskDefault;
   styleMask = UIWindowsStyleMaskBySetting( styleMask, UIWindowStyleRetained, NO);
   styleMask = UIWindowsStyleMaskBySetting( styleMask, UIWindowStyleOffscreen, YES);

   app    = [UIApplication sharedInstance];
   window = [UIWindow windowWithFrame:CGRectMake( 0, 0, 128, 128)
                      titleUTF8String:"Demo"
                            styleMask:styleMask];
   if( ! window)
   {
      fprintf( stderr, "windowWithFrame: failed\n");
      exit( 1);
   }
   [app addWindow:window];
   [app terminate];

   return( 0);
}