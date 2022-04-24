#import <MulleUIWindow/MulleUIWindow.h>


int   main( void)
{
   UIApplication   *app;
   UIWindow        *window;
   UIView          *view;
   NSUInteger      styleMask;

   styleMask = UIWindowStyleMaskDefault;
   styleMask = UIWindowsStyleMaskBySetting( styleMask, UIWindowStyleRetained, NO);
   styleMask = UIWindowsStyleMaskBySetting( styleMask, UIWindowStyleOffscreen, YES);

   app    = [UIApplication sharedInstance];
   window = [UIWindow windowWithFrame:CGRectMake( 0, 0, 128, 128)
                      titleUTF8String:"Demo"
                            styleMask:styleMask];

   view = [UIView viewWithFrame:CGRectMake( 32, 32, 64, 64)];
   if( ! view)
   {
      fprintf( stderr, "viewWithFrame: failed\n");
      exit( 1);
   }
   [window addSubview:view];

   [app addWindow:window];
   [app terminate];

   return( 0);
}