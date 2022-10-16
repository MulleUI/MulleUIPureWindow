#define _GNU_SOURCE

#import "import.h"

#include <math.h>


//#define RECORD_GIF
#define RECORD_FRAMECOUNT  20

/*
 * @name Star
 * @description The star() function created for this example is capable of
 * drawing a wide range of different forms. Try placing different numbers
 * into the star() function calls within draw() to explore.
 */

static void   starPath( NVGcontext *vg, CGFloat x, CGFloat y,
                                        CGFloat radius1, CGFloat radius2,
                                        NSUInteger npoints)
{
   CGFloat   a;
   CGFloat   angle;
   CGFloat   halfAngle;
   CGFloat   sx;
   CGFloat   sy;

   halfAngle = M_PI / npoints;
   angle     = halfAngle * 2.0f;

   nvgBeginPath( vg);
   for( a = 0; a < M_PI * 2.0f; a += angle)
   {
      sx = x + cosf( a) * radius2;
      sy = y + sinf( a) * radius2;

      if( a == 0.0)
         nvgMoveTo( vg, sx, sy);
      else
         nvgLineTo( vg, sx, sy);

      sx = x + cosf(a + halfAngle) * radius1;
      sy = y + sinf(a + halfAngle) * radius1;
      nvgLineTo( vg, sx, sy);
  }
  nvgClosePath( vg);
}

// the three pronged star, we need only a rotation
// of PI * 2 / 3, as then it will look the same

static CGFloat  rotation( NSUInteger frameCount, CGFloat divisor)
{
#ifdef RECORD_GIF
   CGFloat   value;
          // 1. rotation with 1 s
   value   = (M_PI * 2) * frameCount / 60.0;
          // only need 1/3 rotation though
   value  /= 3.0;
          // speed it up so third rotation is in RECORD_FRAMECOUNT
   value *= 60.0 / RECORD_FRAMECOUNT;
          // speed it up / down / reverse according to divisor
          // divisor is in frameRate and 200.0 is the speed of tri-star
   value *= (divisor / 200.0);

   fprintf( stderr, "%tu %g %g\n", frameCount, divisor, value);
   return( value);
#else
   return( frameCount / divisor);
#endif
}

static void   draw( CALayer *layer, CGContext *context)
{
   CGRect       canvas;
   NSUInteger   frameCount;
   NVGcontext   *vg;

   vg         = CGContextGetNVGContext( context);
   canvas     = [layer canvas];
   frameCount = [context numberOfFrames];
   nvgSave( vg);
   {
      nvgTranslate( vg, canvas.size.width * 0.2, canvas.size.height * 0.5);
      nvgRotate( vg, rotation( frameCount, 200.0));
      starPath( vg, 0, 0, 5, 70, 3);
      nvgStrokeColor( vg, CGColorMakeWithGrayByte( 0));
      nvgStroke( vg);
      nvgFillColor( vg, CGColorMakeWithGrayByte( 160));
      nvgFill( vg);
   }
   nvgRestore( vg);

   nvgSave( vg);
   {
      nvgTranslate( vg, canvas.size.width * 0.5, canvas.size.height * 0.5);
      nvgRotate( vg, rotation( frameCount, 50.0));
      starPath( vg, 0, 0, 80, 100, 40);
      nvgStrokeColor( vg, CGColorMakeWithGrayByte( 0));
      nvgStroke( vg);
      nvgFillColor( vg, CGColorMakeWithGrayByte( 160));
      nvgFill( vg);
   }
   nvgRestore( vg);

   nvgSave( vg);
   {
      nvgTranslate( vg, canvas.size.width * 0.8, canvas.size.height * 0.5);
#ifdef RECORD_GIF
      nvgRotate( vg, rotation( frameCount, -200.0 * 3 / 5));
#else
      nvgRotate( vg, rotation( frameCount, -100.0));
#endif
      starPath( vg, 0, 0, 30, 70, 5);
      nvgStrokeColor( vg, CGColorMakeWithGrayByte( 0));
      nvgStroke( vg);
      nvgFillColor( vg, CGColorMakeWithGrayByte( 160));
      nvgFill( vg);
   }
   nvgRestore( vg);
}


static void  didDraw( UIWindow *window,
                      id <UIGraphicsContext> context,
                      struct CGFrameInfo *info)
{
   UIAnimatedGIF     *gif;
   struct CGBitmap   screenshotBitmap;
   NSUInteger        frameCount;

   gif        = [window userInfo];
   frameCount = [(CGContext *) context numberOfFrames];

   if( frameCount == RECORD_FRAMECOUNT)
   {
      [gif close];
      [window setUserInfo:nil];
      [UIApp requestTerminate];
      return;
   }

   // can happen...
   if( frameCount > RECORD_FRAMECOUNT)
      return;

   screenshotBitmap = [context framebufferBitmap];
   [gif addBitmap:screenshotBitmap
     freeWhenDone:YES];
}


int   main( int argc, char *argv[])
{
   UIWindow        *window;
   UIApplication   *app;
   UIAnimatedGIF   *gif;

   app = [UIApplication sharedInstance];
   {
      window = [UIWindow windowWithFrame:CGRectMake( 0.0, 0.0, 720.0, 400.0)
                         titleUTF8String:"Demo"
                               styleMask:UIWindowStyleMaskDefault];

      [window setBackgroundColor:CGColorMakeWithGrayByte( 102)];
      [window setDrawCallback:(CALayerDrawCallback_t *) draw];
      [window setFrameRateHz:60.0];
      [app addWindow:window];

#ifdef RECORD_GIF
      gif = [UIAnimatedGIF animatedGIFWithUTF8String:"animated.gif"
                                          bitmapSize:MulleIntegerSizeMake( 360, 200)
                                           frameRate:1.0 / 60.0
                                                loop:YES];
      [window setUserInfo:gif];
      [window setDidDrawCallback:didDraw];
#endif
   }
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

