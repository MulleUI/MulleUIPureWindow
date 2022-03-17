#import "import.h"


static void  usage( void)
{
   fprintf( stderr, "Usage: frames [frame frequency] [display mode] [other flags]\n"
"Frame frequency\n"
"   async    : runs as fast as possible\n"
"   synced   : synced to (primary) monitor refresh rate\n"
"   unsynced : waits for events (like mouse movements)\n"
"   <number> : frequency in Hertz\n"
"\n"
"Display mode\n"
"   main     : draw offscreen in main thread, copy to window  in main thread\n"
"   retained : draw offscreen in render thread, copy to window in main thread\n"
"   volatile : draw in window in main thread (volatile)\n"
"\n"
"Other flags\n"
"   double   : use doublebuffer in volatile display mode\n"
"   interval : set swap interval to 1 (0)\n"
"   limiter  : use frequency as limiting frequency\n"
"\n");
   exit( 1);
}


#define SMALL_FONT      24
#define LARGE_FONT      32


static void   drawStuff( CALayer *layer, CGContext *context)
{
   auto char            buf[ 64];
   CGFont               *font;
   CGRect               canvas;
   char                 *s;
   double               frameRate;
   GLFWOSWindow         *osWindow;
   NSUInteger           counter;
   struct CGFrameInfo   *info;
   struct NVGcontext    *vg;
   UIWindow             *window;

   osWindow = [context OSWindow];
   window   = [osWindow parentWindow];
   assert( window);

   canvas  = [layer canvas];

   vg = CGContextGetNVGContext( context);

   nvgTextColor( vg, CGColorMakeWithHexColor( 0x0000000FF), CGColorMakeWithHexColor( 0xFFFFFFFF));
   nvgTextAlign( vg, NVG_ALIGN_CENTER | NVG_ALIGN_MIDDLE);

   font = [context fontWithNameUTF8String:"sans"];
   [context setFont:font];

   nvgFontSize( vg, SMALL_FONT);
   sprintf( buf, "frameRateLimiter : %s", [window frameRateLimiter] ? "YES" : "NO");
   nvgText( vg, CGRectGetMidX( canvas), CGRectGetMinY( canvas) + SMALL_FONT * 1 + 2, buf, NULL);

   sprintf( buf, "swapInterval : %td", [window swapInterval]);
   nvgText( vg, CGRectGetMidX( canvas), CGRectGetMinY( canvas) + SMALL_FONT * 2 + 2, buf, NULL);

   frameRate = [window frameRate];
   if( frameRate == UIWindowFrameRateAsync)
      sprintf( buf, "frameRate : async");
   else
      if( frameRate == UIWindowFrameRateUnsynced)
         sprintf( buf, "frameRate : unsynced");
      else
         if( frameRate == UIWindowFrameRateSynced)
            sprintf( buf, "frameRate : synced");
         else
            sprintf( buf, "frameRate : %.2f Hz", 1.0 / frameRate);

   nvgText( vg, CGRectGetMidX( canvas), CGRectGetMinY( canvas) + SMALL_FONT * 3 + 2, buf, NULL);

   sprintf( buf, "slowestFrameRate : %.3f  (%.2f Hz)", [window slowestFrameRate], 1.0 / [window slowestFrameRate]);
   nvgText( vg, CGRectGetMidX( canvas), CGRectGetMinY( canvas) + SMALL_FONT * 4 + 2, buf, NULL);

   sprintf( buf, "fastestFrameRate : %.3f (%.2f Hz)", [window fastestFrameRate],  1.0 / [window fastestFrameRate]);
   nvgText( vg, CGRectGetMidX( canvas), CGRectGetMinY( canvas) + SMALL_FONT * 5 + 2, buf, NULL);

   sprintf( buf, "OSContextInfo : %s", [osWindow os_contextInfoUTF8String]);
   nvgText( vg, CGRectGetMidX( canvas), CGRectGetMinY( canvas) + SMALL_FONT * 6 + 2, buf, NULL);

   sprintf( buf, "OSWindowInfo : %s", [osWindow os_windowInfoUTF8String]);
   nvgText( vg, CGRectGetMidX( canvas), CGRectGetMinY( canvas) + SMALL_FONT * 7 + 2, buf, NULL);


   nvgFontSize( vg, LARGE_FONT);
   sprintf( buf, "%td frames", [context numberOfRenderedFrames]);
   nvgText( vg, CGRectGetMidX( canvas), CGRectGetMidY( canvas), buf, NULL);

   sprintf( buf, "%.3f s", [context secondsSinceFirstRender]);
   nvgText( vg, CGRectGetMidX( canvas), CGRectGetMidY( canvas) + LARGE_FONT + 8, buf, NULL);

   sprintf( buf, "%.2f FPS", [context numberOfRenderedFrames] / [context secondsSinceFirstRender]);
   nvgText( vg, CGRectGetMidX( canvas), CGRectGetMidY( canvas) + LARGE_FONT * 2 + 8, buf, NULL);

   sprintf( buf, "%.6f display+refresh", [window displayAndRefreshRate]);
   nvgText( vg, CGRectGetMidX( canvas), CGRectGetMidY( canvas) + LARGE_FONT * 3 + 8, buf, NULL);
}



static UIEvent   *handleEvent( UIView *view, UIEvent *event)
{
   UIWindow   *window;

   window = [view window];
   mulle_fprintf( stderr, "*** %@ : force refresh @ %.6f\n", window, mulle_absolutetime_now());
   [window setNeedsDisplay];
   return( nil);
}


static void   setupSceneInWindow( UIWindow *window)
{
   UIView   *view;
   CGRect   frame;
   UIView   *contentPlane;

   contentPlane = [window contentPlane];

   frame = [contentPlane contentRect];

   view  = [UIView viewWithFrame:frame];
   [view setBackgroundColor:CGColorMakeRGBA( 1.0, 1.0, 1.0, 1.0)];
   [(CALayer *) [view layer] setDrawCallback:(CALayerDrawCallback_t *) drawStuff];
   [view setUserInteractionEnabled:YES];
   [contentPlane addSubview:view];
}


int   main( int argc, char *argv[])
{
   UIWindow        *window;
   UIApplication   *app;
   MulleUIPerf     *perf;
   CGFloat         rate;
   BOOL            limiter;
   int             i;
   NSUInteger      swapInterval;
   BOOL            isRetained;
   BOOL            isMainThread;
   BOOL            isDoubleBuffered;
   NSUInteger      styleMask;
   
   rate             = UIWindowFrameRateSynced;
   limiter          = NO;
   isRetained       = NO;
   isMainThread     = YES;
   isDoubleBuffered = NO;
   swapInterval     = 0;

   for( i = 1; i < argc; i++)
      switch( argv[ i][ 0])
      {
      default  : usage();
      case 'a' : rate = UIWindowFrameRateAsync; break;
      case 's' : rate = UIWindowFrameRateSynced; break;
      case 'u' : rate = UIWindowFrameRateUnsynced; break;

      case 'm' : isRetained = YES; isMainThread = YES; break;
      case 'r' : isRetained = YES; isMainThread = NO; break;
      case 'v' : isRetained = NO; isMainThread = YES; break;

      case 'd' : isDoubleBuffered = YES; break;
      case 'i' : swapInterval = 1; break;
      case 'l' : limiter = YES; break;
      case '0' :
      case '1' :
      case '2' :
      case '3' :
      case '4' :
      case '5' :
      case '6' :
      case '7' :
      case '8' :
      case '9' :
                 rate = atof( argv[ i]);
                 if( rate == 0.0)
                    usage();
                 rate = 1.0 / rate;
                 break;
      }


   //
   // MEMO: the framerate for windows in one-thread scenario is additive
   //       the app should probably handle that
   //
   app = [UIApplication sharedInstance];
   {
      // UIWindowStyleRenderNonRetainedOnly
      styleMask  = UIWindowStyleMaskDefault;
      if( ! isRetained)
         styleMask &= ~UIWindowStyleRetained;
      else
         if( isMainThread)
            styleMask |= UIWindowStyleRetainedOnMainThread;

      if( ! isDoubleBuffered)
         styleMask |= UIWindowStyleSingleBuffer;

      styleMask |= UIWindowStyleResizable;

      window = [UIWindow windowWithFrame:CGRectMake( 0.0, 0.0, 800, 600)
                         titleUTF8String:"Demo"
                               styleMask:styleMask];

      setupSceneInWindow( window);
      [window setFrameRate:rate];
      [window setFrameRateLimiter:limiter];
      [window setSwapInterval:swapInterval];
      // grab mouse motion events here
      [window setEventCallback:handleEvent];

      [app addWindow:window];
   }

   perf = [MulleUIPerf object];
   [window setFrameDelegate:perf];

   return( [app run]);
}



//
//                           ,╓≤æKª╨╙╙▓█D"╙╙╙*╨¥W▄╓,
//                      ╓▄ª╙└╧▓        █           ⁿ▓▓ª╦w
//                  ╓#╜^*█⌐   `╕       █           ╓▌    `╙%w
//               ╓ΦΓ      █    ╙⌐     ,█,,,Φ      ╓▌         ╙¥▄
//            ,▄▀ █▄       █µ,╓╝,╓≤╗≡≡ª╨╨╨¥≡∞╗w╓,ª█,  ,       ]▄▀V,
//          ,Φ└   ║"▀▄     ,▄▀╨"                 "╙¥▓▓       ▄▀  º▄¥,
//        ,#▌Φ▓▄╓  Φ `█Q▄M╙                           ╙¥▄ ,▄▀ ╙▄⌐`  `Φ
//       ▄▀   `V,"▀▀¼╓╩└                                 ╙¥▓╗ ,       ╙▄
//      Φ       `¥═▄▀                            ╒          ▀▄          ▓
//    .▓         ╓▓]V▄H       ▓                 ,Å            ▀,         ▀
//    █      ,-ª▓╛  `██▀½      "▄  ,╓╓╓╓;╓▄▄▄▄╗▄█,             ╙▄         ▀
//   █  `██▄   ▓. - Φ█═.~     ,≤█▄▀-      `   █└"▀▀▀▀▄╓╓╓╓       ▌    ██▄, █
//  ║⌐  " ▀   ▓╨⌐   }▀`      ,█  `           █      .█▀▄▄███▄     ▌  ` ▀    ▌
//  ▌        ▐M A   '┴      ▌                ▀        ╙█▌████▌    ╙▄        ║⌐
// ║⌐        █⌐'║▄ Γr2«    ║▀                 ▄▄▄      ╙▌▄███      █         ▌
// █]     ,▄▐H  ██████═ª  ╓` ▄█▀▀▀▀█▄        ████     ╓███` `╙╙║█  ▐H        █
// █ "% ,▄▀ ║░╠K█═╣███^   ╛╓█▀      ▐█         ,╓╓═ª╙└   █      ╙█▄▐▌▓######▌╫
// █║▄▄▄█▄▄▄║H:  "╙▀███▄╓▄,█▌╓▄,,▄∩  ██p$ΦΦ▀▀▀▀▀ΦΦΦR≡≥▄╓ ║▄       ╙j▌` ▄▀╙╗ `╫
// █"      ╙▐H-═M ▄███████¥█H "^╙    '█, ,«^``     `     ║▌        ▐M▄▀    "Φ█
// ║        !█▄▄████≤═^`╓█ █▌╓▀╦▄▀█   ╙█⌐               ╓█▌        ▓ `       █
//  ▌      ,▄██╫██ ▄█═╜" █▌▐█╣Hj⌐ █    █▌╙¥w,           ██▄       ╓▌        ▐M
//  ╢"▄▄#▀▀╙╟█Ü███▀`▀█  ║██J█▄▌jH █    ██    ╙▀W▄;    ,██  `╙w,   █▄     ,╓ █
//   █╙     ▐███▌▀█w ▀█ ╠██████j▌║█▌   ▀██▄       `╙▓██▀w,     ╙╗█'`"▀█▀╙"`║`
//   ╙▌     Φ████████▄██ ███████████    ═██▀W▄,   ╓█▀└         ╓▀ "    ╙▄ ╓▀
//    ╙▄     ╙▀███╙█▄▐██▄,╙▀█████▄▀▄▀▄   ,█M╗ ▀▄██▀╙""*ⁿ═─≈-,,▄▌,        ▄▀
//     `▌╙µ,▄Φ▀x███▄██████████▀V███▀╙└ ,▄#▌████▀`"*«,      .█▀▄▀▄,      ▄╛
//       ▀Ö█  ;▓████████▄▄█▀▄╙W "V▄██▀▀│▄███▀└ ▀╦     "*═╥▄▀ ║,  ║▀▄  ,▓
//        ╙W▀ '█████╨▀▀█████████   "▀▀████└      ╙▄   ,▄▀'   `▀▀╣H ▐▀▄▀
//          ╙▄  ▀▀Γ╓▌  ▄▀ⁿ`╙▀███      ██▌         ╓█R▀▄A█        ▀▀▄▀
//            ╙W,Φ╙  ║█        ▄╙╙ª%≡╦██≤≤╗╗≡≡╜▀▀   ╣▌   █╕     ,▄▀
//              `▀▄M█┘        ║▀▌   ╫"    *Φ▄  █       Φ` ▀▌, ▄M╙
//                 "▀╦,       M ╙▌  ▀       `█W▐▌       wæQ▄▀╙
//                     ╙▀W╥,╓╣   ╙█║        ╫M  █    ,╓▄╝╙`
//                          ╙╙▀%▄▄▄▌,≤▄_▄≡,▐▓▓▄▄#ª▀"`

