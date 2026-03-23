#define _GNU_SOURCE
#ifndef M_PI
# define M_PI 3.14159265358979323846
#endif

#import "import-private.h"
#import "MulleUIPureWindow.h"

#include <stdio.h>
#include <time.h>

#include "ui-application-glue.inc"
static void   drawColorwheel(CGContext* context, float x, float y, float w, float h, NSUInteger frameNumber)
{
   int i;
   float r0, r1, ax,ay, bx,by, cx,cy, aeps, r;
   float fummel = fmod( frameNumber / 100.0, M_PI * 2.0) == 0.0 ? 1.0 : fmod( frameNumber / 100.0, M_PI * 2.0);
   float hue = sinf( fummel * 0.12);
   float rot;

   // stolen from a demo and stupedified

   // RING
   CGContextSave( context);
   {
      cx = x + w*0.5f;
      cy = y + h*0.5f;
      r1 = (w < h ? w : h) * 0.5f - 5.0f;
      r0 = r1 - 20.0f;
      aeps = 0.5f / r1; // half a pixel arc length in radians (2pi cancels out).

      CGContextTranslate( context, CGPointMake( cx, cy));
      rot = -fummel;
      CGContextRotate( context, rot);
      CGContextTranslate( context, CGPointMake( -cx, -cy));

      for (i = 0; i < 6; i++) {
         float a0 = (float)i / 6.0f * M_PI * 2.0f - aeps;
         float a1 = (float)(i+1.0f) / 6.0f * M_PI * 2.0f + aeps;
         CGContextBeginPath( context);
         CGContextArcRadians( context, CACircleMakeWithCenterAndRadius( CGPointMake( cx, cy), r0), a0, a1, CARotationDirectionClockWise);
         CGContextArcRadians( context, CACircleMakeWithCenterAndRadius( CGPointMake( cx, cy), r1), a1, a0, CARotationDirectionCounterClockWise);
         CGContextClosePath( context);
         ax = cx + cosf(a0) * (r0+r1)*0.5f;
         ay = cy + sinf(a0) * (r0+r1)*0.5f;
         bx = cx + cosf(a1) * (r0+r1)*0.5f;
         by = cy + sinf(a1) * (r0+r1)*0.5f;
         CGContextSetFillLinearGradient( context, CGPointMake( ax, ay),
                                               CGPointMake( bx, by),
                                               CGColorMakeWithHSLA( a0/(M_PI*2), 1.0f, 0.55f, 1.0f),
                                               CGColorMakeWithHSLA( a1/(M_PI*2), 1.0f, 0.55f, 1.0f));
         CGContextFill( context);
      }

      CGContextBeginPath( context);
      CGContextCircle( context, CACircleMakeWithCenterAndRadius( CGPointMake( cx, cy), r0-0.5f));
      CGContextCircle( context, CACircleMakeWithCenterAndRadius( CGPointMake( cx, cy), r1+0.5f));
      CGContextStrokeColor( context, CGColorMakeWithRGBA( 0, 0, 0, 0.25f));
      CGContextStrokeWidth( context, 1.0f);
      CGContextStroke( context);
   }
   CGContextRestore( context);

   // TRIANGLE
   CGContextSave( context);
   {
      CGContextTranslate( context, CGPointMake( cx, cy));
      rot = fummel;
      CGContextRotate( context, rot);

      r = r0 - 6;
      ax = cosf(120.0f/180.0f*M_PI) * r;
      ay = sinf(120.0f/180.0f*M_PI) * r;
      bx = cosf(-120.0f/180.0f*M_PI) * r;
      by = sinf(-120.0f/180.0f*M_PI) * r;
      CGContextBeginPath( context);
      CGContextMoveTo( context, CGPointMake( r, 0));
      CGContextLineTo( context, CGPointMake( ax, ay));
      CGContextLineTo( context, CGPointMake( bx, by));
      CGContextClosePath( context);

      CGContextSetFillLinearGradient( context, CGPointMake( r, 0),
                                            CGPointMake( ax, ay),
                                            CGColorMakeWithHSLA( hue, 1.0f, 0.5f, 1.0f),
                                            CGColorMakeWithRGBA( 1.0f, 1.0f, 1.0f, 1.0f));
      CGContextFill( context);
      CGContextSetFillLinearGradient( context, CGPointMake( (r+ax)*0.5f, (0+ay)*0.5f),
                                            CGPointMake( bx, by),
                                            CGColorMakeWithRGBA( 0, 0, 0, 0),
                                            CGColorMakeWithRGBA( 0, 0, 0, 1.0f));
      CGContextFill( context);
      CGContextStrokeColor( context, CGColorMakeWithRGBA( 0, 0, 0, 0.25f));
      CGContextStroke( context);
   }
   CGContextRestore( context);
}
static BOOL   drawStuff( CGContext *context, CGRect canvas)
{
   CGFloat      diameter;
   CGRect       rect;
   CGPoint      a;
   CGPoint      b;

   // black box
   CGContextBeginPath( context);
   CGContextRect( context, canvas);
   CGContextFillColor( context, CGColorMakeBlack());
   CGContextFill( context);

   rect        = UIEdgeInsetsInsetRect( canvas, UIEdgeInsetsMake( 50, 50, 50, 50));
   diameter    = CGFloatMinimum( CGRectGetWidth( rect), CGRectGetHeight( rect));
   rect.origin = CGSizeGetCenterInRect( CGSizeMake( diameter, diameter), rect);
   rect.size   = CGSizeMake( diameter, diameter);

   drawColorwheel( context,
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
static UIWindowDisplayBits   display( UIPureWindow *window,
                                      id <UIGraphicsContext> context,
                                      struct CGFrameInfo *frameInfo,
                                      UIWindowDisplayBits displayBits)
{
   CGRect   canvas;

   canvas = CGFrameInfoGetContentRect( frameInfo);
   canvas = CGRectInset( canvas, 40, 40);

   drawStuff( (CGContext *) context, canvas);
   return( 1);
}
int   main( int argc, char *argv[])
{
   UIPureWindow    *window;
   UIApplication   *app;
   CGFloat         rate;
   NSUInteger      swapInterval;

   swapInterval = 0;
   rate = UIWindowFrameRateSynced;
   if( argc > 1)
      swapInterval = atoi( argv[ 1]);

   app = [UIApplication sharedInstance];
   {
      window = [UIPureWindow windowWithFrame:CGRectMake( 0.0, 0.0, 800.0, 600.0)];
      assert( window);

      [window setBackgroundHexColor:CGHexColorWhite];
      [window setFrameCallback:display];
      [window setFrameRate:UIWindowFrameRateSynced];
      [window setSwapInterval:swapInterval];

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

