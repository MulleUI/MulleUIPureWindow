#define _GNU_SOURCE

#import "import-private.h"

// if this test fails, comment this out and see if something changes
//#define USE_UIWINDOW_CG_CONTEXT

#include "draw-flag.inc"


@interface MyWindow : GLFWOSWindow

@property( retain) CGContext  *context;

@end


@implementation MyWindow

- (void) finalize
{
   [self os_activateGraphicsContext];
   {
      // have to do this manually
      [_context mullePerformFinalize];
   }
   [self os_deactivateGraphicsContext];

   [super finalize];
}

@end


static int   display( GLFWOSWindow *window_in)
{
   MyWindow      *osWindow = (MyWindow *) window_in;
   CGRect        canvas;
   CGContext     *context;
   CGFrameInfo   frameInfo;

   canvas.origin = CGPointZero;
   canvas.size   = [osWindow os_windowSize];
   context       = [osWindow context];
   frameInfo     = CGFrameInfoSFMake( canvas, [osWindow os_framebufferSize], 1.0);

   [context beginRender:&frameInfo];
   {
      drawRedWhiteBlueFlag( CGContextGetNVGContext( context), canvas);
   }
   [context endRender];
   return( 0);
}


//
// This needs to be implemented by the context owner. This is not a bug.
// setActive: is not supposed to be seen outside of the osWindow setting this
// context active. (Locking is done in GLFWOSWindow with the implicit context!)
//
@implementation CGContext( MyWindow)

- (void) setActive:(BOOL) flag
{
   _activeThread = flag ? [NSThread currentThread] : nil;
}

@end


@implementation UIWindow( MyWindow)

- (CGContext *) context
{
   return( (CGContext *) _context);
}

@end 


int   main( int argc, char *argv[])
{
   UIApplication  *app;
   MyWindow       *osWindow;
   UIWindow       *uiWindow;
   CGContext      *context;

   app = [UIApplication sharedInstance];
      // this is part of MulleUIOS
   [UIWindow setOSWindowClass:[MyWindow class]];

   uiWindow = [UIWindow windowWithFrame:CGRectMake( 0, 0, 200, 200)
                        titleUTF8String:"Demo"
                              styleMask:UIWindowStyleMaskDefault & ~UIWindowStyleRetained];
   assert( uiWindow);

   @autoreleasepool
   {
      osWindow = (MyWindow *) [uiWindow OSWindow];

      assert( [osWindow isKindOfClass:[MyWindow class]]);

#ifdef USE_UIWINDOW_CG_CONTEXT    
      [uiWindow setKeepOSGraphicsContextActive:NO];
      context = (CGContext *) [uiWindow activateWindowGraphicsContext];
      [uiWindow deactivateGraphicsContext:context];
#else 
      [osWindow os_activateGraphicsContext];
      context = [[[CGContext alloc] initWithBackend:[osWindow backend]
                                            shareID:[osWindow shareID]
                                            options:UIGraphicsDefaultOptions] autorelease];
      // have to do this manually, because the context is created manually
      [osWindow os_deactivateGraphicsContext];
#endif
      assert( context);

      [context setActive:YES];
      // remember context for "display" callback
      [osWindow setContext:context];
      [osWindow setFrameCallback:display];
//      [osWindow setFrameRate:UIWindowFrameRateSynced];

      // add osWindow so it will be used for rendering ?
      [app addWindow:osWindow];
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

