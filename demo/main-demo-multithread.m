#import "import.h"


#define BLAU   CGColorMakeWithRGBA( 0.1, 0.1, 0.4, 1.0)
#define WEISS  CGColorMakeWithRGBA( 1.0, 1.0, 1.0, 1.0)


//
// Just a plain basic setup demo. Nothing special. A good starting point
// to try out your own nvg calls.
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
}


static void   setupSceneInView( UIView *contentPlane)
{
   UIView   *view;
   CGRect   frame;

   frame = [contentPlane contentRect];
   frame = UIEdgeInsetsInsetRect( frame, UIEdgeInsetsMake( 10, 10, 10, 10));

   view  = [UIView viewWithFrame:frame];
   [view setBackgroundColor:BLAU];
   [(CALayer *) [view layer] setDrawCallback:(CALayerDrawCallback_t *) drawStuff];
   [contentPlane addSubview:view];
}


int   main( int argc, char *argv[])
{
   UIWindow        *window[ 2];
   UIApplication   *app;
   NSUInteger      styleMask;
   
   app = [UIApplication sharedInstance];
   {
      styleMask = UIWindowStyleMaskDefault & ~UIWindowStyleRetained;
      for( i = 0; i < 2; i++)
      {
         window[ i] = [UIWindow windowWithFrame:CGRectMake( i * 400.0, 0.0, 400.0, 400.0)
                                titleUTF8String:"Demo"
                                      styleMask:styleMask];
         [window[ i] setBackgroundColor:WEISS];
         [window[ i] setSwapInterval:1];
         [window[ i] setRefreshContentMode:CGContentModeTopLeft];
         setupSceneInView( [window[ i] contentPlane]);
         [app addWindow:window[ i]];
      }
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

