#import "import.h"

#include <time.h>


#define BLAU   CGColorMakeRGBA( 0.1, 0.1, 0.4, 1.0)
#define WEISS  CGColorMakeRGBA( 1.0, 1.0, 1.0, 1.0)


//
// This is the same as main-demo.m, but here we let the drawing adjust to the
// window size. Resize the window to see the difference.
//
// We use the [UIView autoresizingMask] for this. The window
// resizes its planes, which ask their views to resize. The view with the
// proper resize settings will take up the given room and propagate it to
// the layer. If the layers canvas is set to track the frame, which it is
// by default, then the drawing will cover the space.
//
// drawStuff and main are left unchanged.
//
static void  drawStuff( CALayer *layer, CGContext *context)
{
   CGFloat             radius;
   CGFloat             strokeWidth;
   CGFont              *font;
   CGRect              canvas;
   struct NVGcontext   *vg;

   canvas      = [layer canvas];
   strokeWidth = 20.0;
   radius      = (CGFloatMinimum( CGRectGetWidth( canvas),
                                  CGRectGetHeight( canvas)) - strokeWidth) / 2;

   // draw circle
   vg = CGContextGetNVGContext( context);
   nvgBeginPath( vg);
   {
      nvgCircle( vg, CGRectGetMidX( canvas), CGRectGetMidY( canvas), radius);
      nvgStrokeColor( vg, WEISS);
      nvgStrokeWidth( vg, strokeWidth);
   }
   nvgStroke( vg);

   // draw text
   // load in font first, this will be efficient on subsequent frames
   font = [context fontWithNameUTF8String:"sans"];
   [context setFont:font];

   nvgFontSize( vg, strokeWidth * 8.0);
   nvgTextAlign( vg, NVG_ALIGN_CENTER | NVG_ALIGN_MIDDLE);
   nvgTextColor( vg, WEISS, BLAU);
   nvgText( vg, CGRectGetMidX( canvas), CGRectGetMidY( canvas), "1848", NULL);

   // punish drawing to be super slow, because of buffering it's not
   // noticable
   {
       struct timespec   delay = { 0, 1000 * 1000 * (1000 / 10) };
       nanosleep( &delay, NULL);
   }
}


static void   setupSceneInView( UIView *contentPlane)
{
   UIView   *view;
   CGRect   frame;

   frame = [contentPlane contentRect];

   view  = [UIView viewWithFrame:frame];
   [view setBackgroundColor:BLAU];

   // The view will cover all space given by the parent "contentPlane",
   // with the exception of margins.
   [view setAutoresizingMask:UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth];
   //
   // To keep the border effect use margins.
   //
   [view setMargins:UIEdgeInsetsMake( 10, 10, 10, 10)];

   [(CALayer *) [view layer] setDrawCallback:drawStuff];
   [contentPlane addSubview:view];
}


int   main( int argc, char *argv[])
{
   UIWindow        *window;
   UIApplication   *app;

   app = [UIApplication sharedInstance];
   {
      window = [UIWindow windowWithFrame:CGRectMake( 0.0, 0.0, 800.0, 600.0)];
      assert( window);

      [window setBackgroundColor:WEISS];

      setupSceneInView( [window contentPlane]);

      [app addWindow:window];
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

