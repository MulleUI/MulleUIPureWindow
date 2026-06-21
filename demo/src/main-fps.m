#define _GNU_SOURCE
#ifndef M_PI
# define M_PI 3.14159265358979323846
#endif

#import "import-private.h"
#import "MulleUIPureWindow.h"

#include "ui-application-glue.inc"
#include "graphics-hints.inc"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
//
// TODO: make this use the rawFrameCallback properly
//

static void   drawColorwheel(CGContext* context, float x, float y, float w, float h, NSUInteger frameNumber)
{
   int i;
   float r0, r1, ax,ay, bx,by, cx,cy, aeps, r;
   float fummel = fmod( frameNumber / 100.0, M_PI * 2.0) == 0.0 ? 1.0 : fmod( frameNumber / 100.0, M_PI * 2.0);
   float hue = sinf( fummel * 0.12);
   float rot;

   // stolen from a demo and stupidified

   // RING
   CGContextSave(context);
   {
      cx = x + w*0.5f;
      cy = y + h*0.5f;
      r1 = (w < h ? w : h) * 0.5f - 5.0f;
      r0 = r1 - 20.0f;
      aeps = 0.5f / r1; // half a pixel arc length in radians (2pi cancels out).

      CGContextTranslate( context, CGPointMake(cx, cy));
      rot = -fummel;
      CGContextRotate(context, rot);
      CGContextTranslate( context, CGPointMake(-cx, -cy));

      for (i = 0; i < 6; i++) {
         float a0 = (float)i / 6.0f * M_PI * 2.0f - aeps;
         float a1 = (float)(i+1.0f) / 6.0f * M_PI * 2.0f + aeps;
         CGContextBeginPath(context);
         CGContextArcRadians( context, CACircleMakeWithCenterAndRadius( CGPointMake(cx,cy), r0), a0, a1, CARotationDirectionClockWise);
         CGContextArcRadians( context, CACircleMakeWithCenterAndRadius( CGPointMake(cx,cy), r1), a1, a0, CARotationDirectionCounterClockWise);
         CGContextClosePath(context);
         ax = cx + cosf(a0) * (r0+r1)*0.5f;
         ay = cy + sinf(a0) * (r0+r1)*0.5f;
         bx = cx + cosf(a1) * (r0+r1)*0.5f;
         by = cy + sinf(a1) * (r0+r1)*0.5f;
         CGContextSetFillLinearGradient(context, CGPointMake(ax,ay),
                                              CGPointMake(bx,by),
                                              CGColorMakeWithHSLA(a0/(M_PI*2),1.0f,0.55f,1.0f),
                                              CGColorMakeWithHSLA(a1/(M_PI*2),1.0f,0.55f,1.0f));
         CGContextFill(context);
      }

      CGContextBeginPath(context);
      CGContextCircle( context, CACircleMakeWithCenterAndRadius( CGPointMake(cx, cy), r0-0.5f));
      CGContextCircle( context, CACircleMakeWithCenterAndRadius( CGPointMake(cx, cy), r1+0.5f));
      CGContextStrokeColor(context, CGColorMakeWithRGBA(0,0,0,0.25f));
      CGContextStrokeWidth(context, 1.0f);
      CGContextStroke(context);
   }
   CGContextRestore(context);

   // TRIANGLE
   CGContextSave(context);
   {
      CGContextTranslate( context, CGPointMake(cx, cy));
      rot = fummel;
      CGContextRotate(context, rot);

      r = r0 - 6;
      ax = cosf(120.0f/180.0f*M_PI) * r;
      ay = sinf(120.0f/180.0f*M_PI) * r;
      bx = cosf(-120.0f/180.0f*M_PI) * r;
      by = sinf(-120.0f/180.0f*M_PI) * r;
      CGContextBeginPath(context);
      CGContextMoveTo( context, CGPointMake(r, 0));
      CGContextLineTo( context, CGPointMake(ax, ay));
      CGContextLineTo( context, CGPointMake(bx, by));
      CGContextClosePath(context);

      CGContextSetFillLinearGradient( context, CGPointMake(r,0),
                                            CGPointMake(ax,ay),
                                            CGColorMakeWithHSLA(hue,1.0f,0.5f,1.0f),
                                            CGColorMakeWithRGBA(1.0f,1.0f,1.0f,1.0f));
      CGContextFill(context);

      CGContextSetFillLinearGradient( context, CGPointMake((r+ax)*0.5f,(0+ay)*0.5f),
                                            CGPointMake(bx,by),
                                            CGColorMakeWithRGBA(0,0,0,0),
                                            CGColorMakeWithRGBA(0,0,0,1.0f));
      CGContextFill(context);
      CGContextStrokeColor(context, CGColorMakeWithRGBA(0,0,0,0.25f));
      CGContextStroke(context);
   }
   CGContextRestore(context);
}
static BOOL   drawStuff( id <UIGraphicsContext> _context, CGRect canvas)
{
   CGContext  *context = (CGContext *) _context;
   CGFloat    diameter;
   CGRect     rect;
   CGPoint    a;
   CGPoint    b;

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
static UIWindowDisplayBits   rawDisplay( UIPureWindow *window,
                                         id <UIGraphicsContext> context,
                                         struct CGFrameInfo *frameInfo,
                                         UIWindowDisplayBits displayBits)
{
   [context beginRender:frameInfo];
   {
      [context clearFramebufferNoColor];
      drawStuff( context, CGFrameInfoGetContentRect( frameInfo));
   }
   [context endRender];

   return( 1);
}
static void  usage( void)
{
   fprintf( stderr, "Usage: fps [options] [refresh rate]\n"
"Refresh rate can be a floating point refresh rate in HZ or one of the\n"
"following words:\n"
"   synced   : synced to (primary) monitor refresh rate\n"
"   async    : runs as fast as possible\n"
"   unsynced : waits for events (like mouse movements)\n"
"\n");
   UIPrintGraphicsHintsUsage( stderr);
   exit( 1);
}


static void  reportWindowCreationFailure( UIOSWindowGraphicsHints hints)
{
   fprintf( stderr,
            "fps: failed to create demo window\n"
            "     requested graphics hints: lib=%u profile=%u forward=%u software=%u\n"
            "     this can happen if retained/offscreen and onscreen contexts use different creation APIs\n"
            "     try --native or --egl (or remove --osmesa and conflicting overrides)\n",
            hints.lib,
            hints.profile,
            hints.forward,
            hints.software);
}


static void  updateWindowTitleWithBackend( UIPureWindow *window)
{
   char   *info;
   char   *open;
   char   *close;
   char   *bopen;
   char   *bclose;
   char   *rendend;
   int    len;
   int    rendlen;
   char   buf[ 128];

   info = [window os_contextInfoUTF8String];
   if( ! info)
      return;

   open = strchr( info, '(');
   if( ! open)
      return;
   close = strchr( open + 1, ')');
   if( ! close || close <= open + 1)
      return;
   len = (int) (close - (open + 1));
   if( len <= 0)
      return;

   bopen = strchr( close, '[');
   if( ! bopen)
   {
      snprintf( buf, sizeof( buf), "fps (%.*s)", len, open + 1);
      [window setTitleUTF8String:buf];
      return;
   }

   bclose = strchr( bopen + 1, ']');
   if( ! bclose || bclose <= bopen + 1)
   {
      snprintf( buf, sizeof( buf), "fps (%.*s)", len, open + 1);
      [window setTitleUTF8String:buf];
      return;
   }

   rendend = strpbrk( bopen + 1, " (]");
   if( ! rendend || rendend > bclose)
      rendend = bclose;
   rendlen = (int) (rendend - (bopen + 1));
   if( rendlen > 0)
      snprintf( buf, sizeof( buf), "fps (%.*s, %.*s)", len, open + 1, rendlen, bopen + 1);
   else
      snprintf( buf, sizeof( buf), "fps (%.*s)", len, open + 1);

   [window setTitleUTF8String:buf];
}


int   main( int argc, char *argv[])
{
   UIPureWindow    *window;
   UIApplication   *app;
   UIOSWindowGraphicsHints   hints;
   CGFloat         rate;
   int             i;
   BOOL            haveRate;

   hints    = [UIPureWindow osGraphicsHints];
   rate     = UIWindowFrameRateSynced;
   haveRate = NO;

   if( ! UIConfigureGraphicsHints( argc, argv, &hints))
      usage();

   for( i = 1; i < argc; i++)
   {
      if( ! argv[ i])
         continue;

      if( argv[ i][ 0] == '-')
         usage();

      if( haveRate)
         usage();
      haveRate = YES;
      switch( argv[ i][ 0])
      {
      case 'a' : rate = UIWindowFrameRateAsync; break;
      case 's' : rate = UIWindowFrameRateSynced; break;
      case 'u' : rate = UIWindowFrameRateUnsynced; break;
      default  : rate = atof( argv[ i]);
                 if( rate == 0.0)
                    usage();
                 rate = 1.0/rate;
      }
   }

   app = [UIApplication sharedInstance];
   {
      window = [UIPureWindow windowWithFrame:CGRectMake( 0.0, 0.0, 800.0, 600.0)];
      if( ! window)
      {
         reportWindowCreationFailure( hints);
         return( 1);
      }

      [window setBackgroundHexColor:CGHexColorWhite];

      [window setFrameRate:rate];
      [window setRawFrameCallback:rawDisplay];
      updateWindowTitleWithBackend( window);
//      setupSceneInView( [window contentView]);

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
