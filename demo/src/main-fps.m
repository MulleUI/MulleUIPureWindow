#define _GNU_SOURCE

#import "import.h"

#include <stdio.h>
#include <time.h>


static void   drawColorwheel(NVGcontext* vg, float x, float y, float w, float h, NSUInteger frameNumber)
{
   int i;
   float r0, r1, ax,ay, bx,by, cx,cy, aeps, r;
   float fummel = fmod( frameNumber / 100.0, NVG_PI * 2.0) == 0.0 ? 1.0 : fmod( frameNumber / 100.0, NVG_PI * 2.0);
   float hue = sinf( fummel * 0.12);
   float rot;
   NVGpaint paint;

   // stolen from the nanovg demo and stupedified

   // RING
   nvgSave(vg);
   {
      cx = x + w*0.5f;
      cy = y + h*0.5f;
      r1 = (w < h ? w : h) * 0.5f - 5.0f;
      r0 = r1 - 20.0f;
      aeps = 0.5f / r1; // half a pixel arc length in radians (2pi cancels out).

      nvgTranslate(vg, cx,cy);
      rot = -fummel;
      nvgRotate(vg, rot);
      nvgTranslate(vg, -cx,-cy);

      for (i = 0; i < 6; i++) {
         float a0 = (float)i / 6.0f * NVG_PI * 2.0f - aeps;
         float a1 = (float)(i+1.0f) / 6.0f * NVG_PI * 2.0f + aeps;
         nvgBeginPath(vg);
         nvgArc(vg, cx,cy, r0, a0, a1, NVG_CW);
         nvgArc(vg, cx,cy, r1, a1, a0, NVG_CCW);
         nvgClosePath(vg);
         ax = cx + cosf(a0) * (r0+r1)*0.5f;
         ay = cy + sinf(a0) * (r0+r1)*0.5f;
         bx = cx + cosf(a1) * (r0+r1)*0.5f;
         by = cy + sinf(a1) * (r0+r1)*0.5f;
         paint = nvgLinearGradient(vg, ax,ay, bx,by, nvgHSLA(a0/(NVG_PI*2),1.0f,0.55f,255), nvgHSLA(a1/(NVG_PI*2),1.0f,0.55f,255));
         nvgFillPaint(vg, paint);
         nvgFill(vg);
      }

      nvgBeginPath(vg);
      nvgCircle(vg, cx,cy, r0-0.5f);
      nvgCircle(vg, cx,cy, r1+0.5f);
      nvgStrokeColor(vg, nvgRGBA(0,0,0,64));
      nvgStrokeWidth(vg, 1.0f);
      nvgStroke(vg);
   }
   nvgRestore(vg);

   // TRIANGLE
   nvgSave(vg);
   {
      nvgTranslate(vg, cx,cy);
      rot = fummel;
      nvgRotate(vg, rot);

      r = r0 - 6;
      ax = cosf(120.0f/180.0f*NVG_PI) * r;
      ay = sinf(120.0f/180.0f*NVG_PI) * r;
      bx = cosf(-120.0f/180.0f*NVG_PI) * r;
      by = sinf(-120.0f/180.0f*NVG_PI) * r;
      nvgBeginPath(vg);
      nvgMoveTo(vg, r,0);
      nvgLineTo(vg, ax,ay);
      nvgLineTo(vg, bx,by);
      nvgClosePath(vg);
      paint = nvgLinearGradient(vg, r,0, ax,ay, nvgHSLA(hue,1.0f,0.5f,255), nvgRGBA(255,255,255,255));

      nvgFillPaint(vg, paint);
      nvgFill(vg);
      paint = nvgLinearGradient(vg, (r+ax)*0.5f,(0+ay)*0.5f, bx,by, nvgRGBA(0,0,0,0), nvgRGBA(0,0,0,255));
      nvgFillPaint(vg, paint);
      nvgFill(vg);
      nvgStrokeColor(vg, nvgRGBA(0,0,0,64));
      nvgStroke(vg);
   }
   nvgRestore(vg);
}


static BOOL  drawStuff( CALayer *layer, void *_context)
{
   CGContext  *context = _context;
   CGFloat    diameter;
   CGRect     canvas;
   CGRect     rect;
   CGPoint    a;
   CGPoint    b;

   canvas      = [layer canvas];
   rect        = UIEdgeInsetsInsetRect( canvas, UIEdgeInsetsMake( 50, 50, 50, 50));
   diameter    = CGFloatMinimum( CGRectGetWidth( rect), CGRectGetHeight( rect));
   rect.origin = CGSizeGetCenterPointInRect( CGSizeMake( diameter, diameter), rect);
   rect.size   = CGSizeMake( diameter, diameter);

   drawColorwheel( CGContextGetNVGContext( context),
                   rect.origin.x,
                   rect.origin.y,
                   diameter,
                   diameter,
                   [context numberOfFrames]);

#if 0
   {
      struct timespec         sleep;

      sleep.tv_sec  = 0.0;
      sleep.tv_nsec = 10000 * (rand() % 1000);
      nanosleep( &sleep, NULL);

   }
#endif
   return( YES);
}


static void   setupSceneInView( UIView *contentPlane)
{
   UIView   *view;
   CGRect   frame;

   frame = [contentPlane contentRect];
   frame = UIEdgeInsetsInsetRect( frame, UIEdgeInsetsMake( 40, 40, 40, 40));

   view  = [[[UIView alloc] initWithFrame:frame] autorelease];
   [view setBackgroundColor:CGColorMakeWithRGBA( 0.0, 0.0, 0.0, 1.0)];
   [(CALayer *) [view layer] setDrawCallback:drawStuff];
   [contentPlane addSubview:view];
}


static void  usage( void)
{
   fprintf( stderr, "Usage: fps <refresh rate>\n"
"Refresh rate can be a floating point refresh rate in HZ or one of the\n"
"following words:\n"
"   synced   : synced to (primary) monitor refresh rate\n"
"   async    : runs as fast as possible\n"
"   unsynced : waits for events (like mouse movements)\n");
   exit( 1);
}

int   main( int argc, char *argv[])
{
   UIWindow        *window;
   UIApplication   *app;
   MulleUIPerf     *perf;
   CGFloat         rate;

   if( argc > 2)
      usage();

   rate = UIWindowFrameRateSynced;
   if( argc > 1)
      switch( argv[ 1][ 0])
      {
      case 'a' : rate = UIWindowFrameRateAsync; break;
      case 's' : rate = UIWindowFrameRateSynced; break;
      case 'u' : rate = UIWindowFrameRateUnsynced; break;
      default  : rate = atof( argv[ 1]);
                 if( rate == 0.0)
                    usage();
                 rate = 1.0/rate;
      }

   app = [UIApplication sharedInstance];
   {
      window = [UIWindow windowWithFrame:CGRectMake( 0.0, 0.0, 800.0, 600.0)];
      assert( window);

      [window setBackgroundColor:CGColorMakeWithRGBA( 1.0, 1.0, 1.0, 1.0)];

      [window setFrameRate:rate];
      setupSceneInView( [window contentView]);

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

