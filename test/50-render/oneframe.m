#import <MulleUICore/MulleUICore.h>


int   main( void)
{
   UIApplication   *app;
   UIWindow        *window;
   NSUInteger      styleMask;

   styleMask = UIWindowStyleMaskDefault;
   styleMask = UIWindowsStyleMaskBySetting( styleMask, UIWindowStyleRetained, NO);
   styleMask = UIWindowsStyleMaskBySetting( styleMask, UIWindowStyleInvisible, YES);

   app    = [UIApplication sharedInstance];
   window = [UIWindow windowWithFrame:CGRectMake( 0, 0, 128, 128)
                      titleUTF8String:"Demo"
                            styleMask:styleMask];
   [app addWindow:window];
   [window runOneFrame];
   [app terminate];

   return( 0);
}