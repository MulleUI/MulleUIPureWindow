#include <GLFW/glfw3.h>
#import "import-private.h"
#import "MulleUIPureWindow.h"

#include "ui-application-glue.inc"
#include "graphics-hints.inc"
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
"   single   : use single buffering in volatile display mode (likely broken)\n"
"   interval : set swap interval to 1 (0)\n"
"   limiter  : use frequency as limiting frequency\n"
"\n");
   exit( 1);
}
#define SMALL_FONT      24
#define LARGE_FONT      32
static BOOL   drawStuff( CGContext *context, CGRect canvas)
{
   auto char               buf[ 256];
   CGFont                  *font;
   char                    *s;
   double                  frameRate;
   GLFWOSWindow            *osWindow;
   NSUInteger              counter;
   struct CGFrameInfo      *info;
   struct UIOSWindowInfo   windowInfo;
   UIPureWindow            *window;

   osWindow = MULLE_OBJC_CLASS_CAST( GLFWOSWindow, [context OSWindow]);
   window   = MULLE_OBJC_CLASS_CAST( UIPureWindow, [osWindow parentWindow]);
   assert( window);

   CGContextTextColor( context, CGColorMakeWhite());
   CGContextTextBackgroundColor( context, CGColorMakeChartreuse());
   CGContextCombinedTextAlignment( context, CGTextAlignCenter | CGTextAlignMiddle);

   font = [context fontWithNameUTF8String:"sans"];
   [context useFont:font];

   CGContextFontSize( context, SMALL_FONT);
   snprintf( buf, sizeof( buf), "frameRateLimiter : %s", [window frameRateLimiter] ? "YES" : "NO");
   CGContextText( context, CGPointMake( CGRectGetMidX( canvas), CGRectGetMinY( canvas) + SMALL_FONT * 1 + 2), buf, (size_t) -1);

   snprintf( buf, sizeof( buf), "swapInterval : %td", [window swapInterval]);
   CGContextText( context, CGPointMake( CGRectGetMidX( canvas), CGRectGetMinY( canvas) + SMALL_FONT * 2 + 2), buf, (size_t) -1);

   frameRate = [window frameRate];
   if( frameRate == UIWindowFrameRateAsync)
   snprintf( buf, sizeof( buf), "frameRate : async");
   else
   if( frameRate == UIWindowFrameRateUnsynced)
   snprintf( buf, sizeof( buf), "frameRate : unsynced");
   else
   if( frameRate == UIWindowFrameRateSynced)
   snprintf( buf, sizeof( buf), "frameRate : synced");
   else
   snprintf( buf, sizeof( buf), "frameRate : %.2f Hz", 1.0 / frameRate);
   CGContextText( context, CGPointMake( CGRectGetMidX( canvas), CGRectGetMinY( canvas) + SMALL_FONT * 3 + 2), buf, (size_t) -1);

   [window getOSWindowInfo:&windowInfo];

   snprintf( buf, sizeof( buf), "slowestFrameRate : %.3f  (%.2f Hz)", UIOSWindowInfoGetSlowestFrameRate( &windowInfo), 1.0 / UIOSWindowInfoGetSlowestFrameRate( &windowInfo));
   CGContextText( context, CGPointMake( CGRectGetMidX( canvas), CGRectGetMinY( canvas) + SMALL_FONT * 4 + 2), buf, (size_t) -1);

   snprintf( buf, sizeof( buf), "fastestFrameRate : %.3f (%.2f Hz)",  UIOSWindowInfoGetFastestFrameRate( &windowInfo),  1.0 /  UIOSWindowInfoGetFastestFrameRate( &windowInfo));
   CGContextText( context, CGPointMake( CGRectGetMidX( canvas), CGRectGetMinY( canvas) + SMALL_FONT * 5 + 2), buf, (size_t) -1);

   snprintf( buf, sizeof( buf), "OSContextInfo : %s", [NSThread mulleIsMainThread] ? [osWindow os_contextInfoUTF8String] : "N/A");
   CGContextText( context, CGPointMake( CGRectGetMidX( canvas), CGRectGetMinY( canvas) + SMALL_FONT * 6 + 2), buf, (size_t) -1);

   snprintf( buf, sizeof( buf), "OSWindowInfo : %s", [NSThread mulleIsMainThread] ? [osWindow os_windowInfoUTF8String] : "N/A");
   CGContextText( context, CGPointMake( CGRectGetMidX( canvas), CGRectGetMinY( canvas) + SMALL_FONT * 7 + 2), buf, (size_t) -1);

   mulle_sprintf( buf, "thread : %@", [NSThread currentThread]);
   CGContextText( context, CGPointMake( CGRectGetMidX( canvas), CGRectGetMinY( canvas) + SMALL_FONT * 8 + 2), buf, (size_t) -1);

   CGContextFontSize( context, LARGE_FONT);
   snprintf( buf, sizeof( buf), "%td frames", [context numberOfFrames]);
   CGContextText( context, CGPointMake( CGRectGetMidX( canvas), CGRectGetMidY( canvas)), buf, (size_t) -1);

   snprintf( buf, sizeof( buf), "%.3f s", [context secondsSinceFirstRender]);
   CGContextText( context, CGPointMake( CGRectGetMidX( canvas), CGRectGetMidY( canvas) + LARGE_FONT + 8), buf, (size_t) -1);

   snprintf( buf, sizeof( buf), "%.2f FPS", [context numberOfFrames] / [context secondsSinceFirstRender]);
   CGContextText( context, CGPointMake( CGRectGetMidX( canvas), CGRectGetMidY( canvas) + LARGE_FONT * 2 + 8), buf, (size_t) -1);

//   sprintf( buf, "%.6f display+refresh", [window displayAndRefreshRate]);
//   CGContextText( context, CGRectGetMidX( canvas), CGRectGetMidY( canvas) + LARGE_FONT * 3 + 8, buf, NULL);

// need this for singlebuffer and also need to flush out drawing calls
// NO LONGER WELL SUPPORTED AS WAYLAND / EGL CAN'T DO IT

   glFlush();
   return( YES);
}
static UIWindowDisplayBits   display( UIPureWindow *window,
                                      id <UIGraphicsContext> context,
                                      struct CGFrameInfo *frameInfo,
                                      UIWindowDisplayBits displayBits)
{
   drawStuff( (CGContext *) context, CGFrameInfoGetContentRect( frameInfo));
   return( 1);
}
int   main( int argc, char *argv[])
{
   UIOSWindowGraphicsHints   hints;
   BOOL            isDoubleBuffered;
   BOOL            isMainThread;
   BOOL            isRetained;
   BOOL            limiter;
   CGFloat         rate;
   int             i;
   NSUInteger      styleMask;
   NSUInteger      swapInterval;
   UIApplication   *app;
   UIPureWindow    *window;

   rate             = UIWindowFrameRateSynced;
   limiter          = NO;
   isRetained       = NO;
   isMainThread     = YES;
   isDoubleBuffered = YES;
   swapInterval     = 0;

   if( ! UIConfigureGraphicsHints( argc, argv, &hints))
      usage();

   for( i = 1; i < argc; i++)
   {
      if( ! argv[ i])
         continue;
      switch( argv[ i][ 0])
      {
      default  : usage();
      case 'a' : rate = UIWindowFrameRateAsync; break;
      case 's' :
         switch( argv[ i][ 1])
         {
         case 'i' :
            isDoubleBuffered = NO; break;
         default :
            rate = UIWindowFrameRateSynced; break;
         }
         break;
      case 'u' : rate = UIWindowFrameRateUnsynced; break;

      case 'm' : isRetained = YES; isMainThread = YES; break;
      case 'r' : isRetained = YES; isMainThread = NO; break;
      case 'v' : isRetained = NO;  isMainThread = YES; break;

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
   }
   //
   // MEMO: the framerate for windows in one-thread scenario is additive
   //       the app should probably handle that
   //
   app = [UIApplication sharedInstance];
   {
      // UIWindowStyleRenderNonRetainedOnly
      styleMask = UIWindowStyleMaskDefault;
      if( ! isRetained)
         styleMask &= ~UIWindowStyleRetained;
      else
         if( isMainThread)
            styleMask |= UIWindowStyleRetainedOnMainThread;

      if( ! isDoubleBuffered)
      {
         if( isRetained == NO && isMainThread == YES)
         {
            styleMask |= UIWindowStyleSingleBuffer;
         }
         else
         {
            mulle_fprintf( stderr, "single buffer only supported for volatile mode\n");
            return( 1);
         }
      }

      styleMask |= UIWindowStyleResizable;
      //
      // spacing looks nicer with subsequent window output
      //
      mulle_fprintf( stderr, "frameRate               : %s\n", UIWindowFrameRateUTF8String( rate));
      mulle_fprintf( stderr, "styleMask               : %s\n", UIWindowStyleUTF8String( styleMask));
      mulle_fprintf( stderr, "swapInterval            : %ld\n", swapInterval);
      mulle_fprintf( stderr, "limiter                 : %bld\n", limiter);
      mulle_fprintf( stderr, "mainThread              : %bld\n", isMainThread);
      mulle_fprintf( stderr, "retained                : %bld\n", isRetained);
      mulle_fprintf( stderr, "double buffer           : %bld\n", isDoubleBuffered);

      window = [UIPureWindow windowWithFrame:CGRectMake( 0.0, 0.0, 800, 600)
                             titleUTF8String:"Demo"
                                   styleMask:styleMask];

      [window setBackgroundHexColor:0x7F00EEFF];
      [window setFrameRate:rate];
      [window setFrameRateLimiter:limiter];
      [window setFrameCallback:display];
      [window setSwapInterval:swapInterval];
      // grab mouse motion events here
//      [window setEventCallback:handleEvent];

#ifdef HAVE_MULLE_UI
      {
         MulleUIPerf   *perf;

         perf = [MulleUIPerf instance];
         [window setFrameDelegate:perf];
      }
#endif
      [app addWindow:window];
   }
   return( [app runApp]);
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
