#define _GNU_SOURCE

#import "import-private.h"
#import "MulleUIPureWindow.h"

#include "ui-application-glue.inc"


#ifndef STYLE_MASK
# define STYLE_MASK  ((UIWindowStyleMaskDefault | UIWindowStyleRetained) & ~UIWindowStylePlanes)
#endif
#ifndef KEEP_ACTIVE
# define KEEP_ACTIVE   YES
#endif


//
// This demo shows how to setup some textures before starting the window.
//


// #define START_COLOR   CGColorMakeWhite()
// #define END_COLOR     CGColorMakeBlue()
//#define DEBUG_WRITE_IMAGE_PNG
//#define DEBUG_NO_ANIMATION
//#define DEBUG_NO_SCENE
// #define FPS               60.0
#define FPS               60.0      // TIP: reduce to 0.5 for debugging


@interface MyWindow : UIPureWindow

@property( retain) CGImage   *image;

@end


@implementation MyWindow
@end



static UIWindowDisplayBits   display( UIPureWindow *pureWindow,
                                      id <UIGraphicsContext> graphicsContext,
                                      struct CGFrameInfo *frameInfo,
                                      UIWindowDisplayBits displayBits)
{
   MyWindow            *window;
   CGContext           *context;
   CGImage             *image;
   struct NVGcontext   *vg;
   CGDrawableOptions   options =
   {
      .alpha             = 1.0,
      .rotation          = 0.1,
      .scale             = 1.0,
      .flags.contentMode = CGContentModeCenterPoint
   };


   window  = MULLE_OBJC_CLASS_CAST( MyWindow, pureWindow);
   context = MULLE_OBJC_CLASS_CAST( CGContext, graphicsContext);
   MulleUICLog( "%#@", context);

   image   = [window image];
   assert( image);

   options.rotation = ([context numberOfFrames] % 20) / 20.0;
   vg      = CGContextGetNVGContext( context);
   [image drawRect:CGFrameInfoGetContentRect( frameInfo)
           options:&options
           context:context];

   return( 1);
}



struct DrawContext
{
   CGColor   startColor;
   CGColor   endColor;
   CGFloat   strokeWidth;
   CAAngle   rotation;
};


struct DrawContext   circleOne =
{
   CGColorDataYellow,
   CGColorDataBlue,
   80.0,
   CARotationNone
};


static void   drawGradientCircle( CGContext *context, CGSize size, void *userinfo)
{
   struct DrawContext  *info = userinfo;
   CGGradient          *gradient;
   NVGcontext          *vg;
   CACircle            circle;

   gradient = [CGGradient gradientWithStartColor:info->startColor
                                        endColor:info->endColor
                                        rotation:info->rotation];
   vg       = CGContextGetNVGContext( context);
   circle   = CACircleMake( CGSizeGetCenterPoint( size),
                            CGSizeGetInnerRadius( size) - info->strokeWidth / 2.0 - 1.0);
   mvgStrokeCircleWithPaint( vg, circle,
                                 info->strokeWidth,
                                 gradient);
}


CGImage   *create_image( UIPureWindow *window, CGSize size)
{
   CGImage      *image;
   CGContext    *context;

   //
   // need an alive context to pre-render images
   //
   [window activateRenderGraphicsContext];
   {
      context = (CGContext *) [window renderGraphicsContext];
      MulleUICLog( "%#@", context);

      image   = [CGFramebuffer framebufferWithBitmapSize:CGPixelSizeMakeWithSize( size)
                                         backgroundColor:CGColorMakeWhite()
                                            drawFunction:drawGradientCircle
                                                userInfo:&circleOne
                                          nameUTF8String:"circle"
                                                 context:context];
   }

   // its likely that the render context will be used in a different
   // thread (we are still singlethreaded here), so deactivate and
   // deassociate from thread to be safe
   [window deactivateRenderGraphicsContextKeepState:0];

   // [image writeToPNGUTF8String:"circle.png"];
   return( image);
}



int   main( int argc, char *argv[])
{
   UIApplication   *app;
   MyWindow        *window;
   CGImage         *image;

   app = [UIApplication sharedInstance];
   /*
    * window and app
    */
   window = [MyWindow windowWithFrame:CGRectMake( 0.0, 0.0, 800.0, 600.0)
                      titleUTF8String:"Demo"
                            styleMask:STYLE_MASK];
   // for testing: KEEP_ACTIVE == NO should be slower but harmless!
   [window setKeepOSGraphicsContextActive:KEEP_ACTIVE];
   assert( window);

   [window setBackgroundHexColor:CGHexColorWhite];
#ifdef FPS
   [window setFrameRateHz:FPS];
#endif

   image = create_image( window, [window frame].size);
   [window setImage:image];
   [window setFrameCallback:display];

   // if we do this and go from NO to YES, we need to waste the contexts of
   // the window, otherwise activation won't happen.

   return( UIApplicationRunWindow( window));
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

