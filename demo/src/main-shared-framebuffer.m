#import "import.h"


//
// This demo is the same as main-shared, but we draw the parrot into a
// framebuffer first.
//
#define BLAU   CGColorMakeWithRGBA( 0.1, 0.1, 0.4, 1.0)
#define GRUEN  CGColorMakeWithRGBA( 0.1, 0.4, 0.1, 1.0)
#define WEISS  CGColorMakeWithRGBA( 1.0, 1.0, 1.0, 1.0)
#define GRAU   CGColorMakeWithRGBA( 0.85, 0.85, 0.85, 0.75)


static UIBitmapImage   *image;
static CGImage         *cgImage;


static void  drawPrettyBackground( CGGraphicsLayer *layer, CGContext *context)
{
   CGFloat             radius;
   CGFloat             strokeWidth;
   CGFont              *font;
   CGRect              canvas;
   CGRect              rect;
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
      nvgStrokeColor( vg, GRAU);
      nvgStrokeWidth( vg, strokeWidth);
   }
   nvgStroke( vg);

   // draw text
   // load in font first, this will be efficient on subsequent frames
   font = [context fontWithNameUTF8String:"sans"];
   [context useFont:font];

   nvgFontSize( vg, strokeWidth * 8.0);
   nvgTextAlign( vg, NVG_ALIGN_CENTER | NVG_ALIGN_MIDDLE);
   nvgTextColor( vg, WEISS);
   nvgTextBackgroundColor( vg, BLAU);
   nvgText( vg, CGRectGetMidX( canvas), CGRectGetMidY( canvas), "1848", NULL);
}


static BOOL  drawStuff( CGGraphicsLayer *layer, CGContext *context)
{
   struct CGDrawableOptions   options;
   static CGImage             *cgImage[ 2];
   static CGContext           *contexts[ 2];
   static CGFramebuffer       *framebuffer;
   CGRect                     canvas;
   CGRect                     rect;
   struct CGFrameInfo         frameInfo;
   struct CGFrameInfo         oldFrameInfo;

   drawPrettyBackground( layer, context);

   options = CGDrawableOptionsMakeScaleToFit();
   if( ! cgImage[ 0])
   {
      canvas     = [layer canvas];
      // Create a framebuffer matching our canvas size
      framebuffer = [CGFramebuffer framebufferWithBitmapSize:CGPixelSizeMakeWithSize( canvas.size)
                                               textureFlags:0
                                                    context:context];

      // Draw into framebuffer
      frameInfo = CGFrameInfoFBMake( CGPixelSizeMakeWithSize( canvas.size), 1.0, 1.0);
      oldFrameInfo = [context bindRender:&frameInfo];
      {
         [context bindFramebuffer:CGContextFramebufferMakeWithLayer( framebuffer)];
         [context clearFramebufferWithColor:CGColorMakeWithRGBA( 0.2, 0.1, 0.3, 1.0)];
         rect.origin = CGPointZero;
         rect.size   = [image size];

         [image drawRect:rect
                 options:NULL
                 context:context];
      }
      [context bindRender:&oldFrameInfo];
      [context bindFramebuffer:CGContextFramebufferMakeDefault()];

      cgImage[ 0]  = [[framebuffer cgImageWithContext:context
                                         textureFlags:[framebuffer textureFlags]] retain];
      contexts[ 0] = context;
   }
   else
      if( ! cgImage[ 1])
      {
         assert( contexts[ 0] != context);

         cgImage[ 1]  = [[framebuffer shareWithContext:context
                                          textureFlags:[framebuffer textureFlags]] retain];
         contexts[ 1] = context;
      }

   if( contexts[ 0] == context)
   {
      [cgImage[ 0] drawRect:CGRectMake( 32, 32, 128, 160)
                    options:&options
                    context:context];
   }
   else
   {
      [cgImage[ 1] drawRect:CGRectMake( 32, 32, 128, 160)
                    options:&options
                    context:context];
   }

   return( YES);
}


static void   setupSceneInBareWindow( UIWindow *window, CGColor color)
{
   UIView   *view;
   CGRect   frame;

   frame = [window bounds];
   frame = UIEdgeInsetsInsetRect( frame, UIEdgeInsetsMake( 10, 10, 10, 10));

   view  = [UIView viewWithFrame:frame];
   [view setBackgroundColor:color];
   [(CGGraphicsLayer *) [view layer] setDrawCallback:drawStuff];
   [window setView:view];
}


int   main( int argc, char *argv[])
{
   GLFWOSWindow    *glfwWindow[ 2];
   GLFWOSWindow    *sharingWindow;
   UIApplication   *app;
   UIWindow        *window[ 2];
   NSUInteger      i;
   BOOL            closed[ 2];
   CGRect          frame;

   app = [UIApplication sharedInstance];
   {
      image = (UIBitmapImage *) [UIImage imageWithContentsOfFileCString:"parrot.png"];
      assert( image);

      // for testing sharing, we use singlebuffer (to obscure a current double
      // buffer error)
      for( i = 0; i < 2; i++)
      {
         frame          = CGRectMake( 0.0 + 500 * i, 100.0, 400.0, 300.0);

         //
         // if you set sharingWindow to nil always, the cockatoo won't show
         // up in the right window
         //
         sharingWindow  = i ? glfwWindow[ 0] : nil;
         glfwWindow[ i] = [[[GLFWOSWindow alloc] initWithFrame:frame
                                                titleUTF8String:! i ? "Demo" : "Demo2"
                                                      styleMask:GLFWOSWindowStyleMaskDefault //|UIWindowStyleSingleBuffer
                                                  graphicsHints:0
                                                  sharingWindow:sharingWindow] autorelease];

         window[ i] = [[[UIWindow alloc] initWithOSWindow:glfwWindow[ i]
                                        offscreenOSWindow:nil] autorelease];
         assert( window[ i]);

         setupSceneInBareWindow( window[ i], i ? BLAU : GRUEN);
         [window[ i] setBackgroundColor:WEISS];

         [app addWindow:window[ i]];
      }

      // app should handle this...
      closed[ 0] = NO;
      closed[ 1] = NO;
      while( ! closed[ 0] && ! closed[ 1])
      {
         if( ! closed[ 0])
         {
            closed[ 0] = ! [window[ 0] processOneFrame];
            if( closed[ 0])
               fprintf( stderr, "window[ 0] closed\n");
         }

         if( ! closed[ 1])
         {
            closed[ 1] = ! [window[ 1] processOneFrame];
            if( closed[ 1])
               fprintf( stderr, "window[ 1] closed\n");
         }
      }
   }
   return( [app terminate]);
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

