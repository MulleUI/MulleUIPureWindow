#define _GNU_SOURCE

#import "import.h"

#include <math.h>


#if 0
- (void) _beginAccumulateRender
{
   CGLayer   *oldLayer;

   oldLayer = nil;

   if( !_accumulateLayer || 
       ! MulleIntegerSizeEqualToIntegerSize( _currentFrameInfo.window.framebufferSize, [_accumulateLayer bitmapSize]))
   {
      oldLayer         = [_accumulateLayer autorelease];
      _accumulateLayer = [[self layerWithSize:_currentFrameInfo.window.framebufferSize] retain];
   }

   [self bindFramebuffer:CGContextFramebufferMakeWithLayer( _accumulateLayer)];

   if( oldLayer)
   {
      [self setCompositionMode:UIGraphicsCopy];
      [self drawRect:CGRectMakeWithIntegerSize( _currentFrameInfo.window.framebufferSize)
               image:oldLayer
               scale:YES]; 
      [self setCompositionMode:UIGraphicsSourceOver];
   }
}

   /*
    * if we have accumulate, blit to offscreen or default
    */
   if( _usesAccumulationBuffer)
   {
      if( _rendersOffScreen)
         [self bindFramebuffer:CGContextFramebufferMakeWithLayer( _renderLayer)];
      else
         [self bindFramebuffer:CGContextFramebufferMakeDefault()];
      CGContextCheckBackendError( self, "bind buffer");

      [self setCompositionMode:UIGraphicsCopy];
      [self drawRect:CGRectMakeWithIntegerSize( _currentFrameInfo.window.framebufferSize)
               image:_accumulateLayer
               scale:NO]; 
      [self setCompositionMode:UIGraphicsSourceOver];
   }

#endif

/* 
 * stolen from: https://processing.org/examples/distance2d.html
 */
#define DIAMETER 30

static void   draw( CALayer *layer, CGContext *context)
{
   CGFloat   size;
   CGPoint   mouse;
   CGPoint   center;
   CGRect    canvas;
   CGFloat   max;

   canvas = [layer canvas];
   mouse  = [context mouseLocation];

   [context fillRect:canvas
            hexColor:CGHexColorMakeWithColor( CGColorMakeWhite())];

   max = CGPointDistanceToPoint( CGPointZero, CGSizeAsPoint( canvas.size));
     // make a x and y grid of ellipses
   for( center.x = DIAMETER / 2; center.x <= canvas.size.width + DIAMETER / 2; center.x = center.x + DIAMETER)
   {
      for( center.y = DIAMETER / 2; center.y <= canvas.size.height + DIAMETER / 2; center.y = center.y + DIAMETER)
      {
         // starting point of each circle depends on mouse position
         size = CGPointDistanceToPoint( mouse, center);
         size = (size / max) * 66; // magic 66
         [context fillCircleAtPoint:center
                             radius:size / 2.0
                           hexColor:CGHexColorMakeWithColor( CGColorMakeWithRGBBytes( 20, 200, 20))];
      }
   }
}


int   main( int argc, char *argv[])
{
   UIWindow        *window;
   UIApplication   *app;

   app = [UIApplication sharedInstance];
   {
      window = [UIWindow windowWithFrame:CGRectMake( 0.0, 0.0, 710.0, 400.0)];

      // background color will be seen when resizing
      [window setBackgroundColor:CGColorMakeGreen()];
      [window setDrawCallback:(CALayerDrawCallback_t *) draw];
      [window setFrameRateHz:60.0];
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

