
//
// This demo shows how you can share a texture between two windows and
// therefore also two contexts.
//
#define BLAU   CGColorMakeWithRGBA( 0.1, 0.1, 0.4, 1.0)
#define GRUEN  CGColorMakeWithRGBA( 0.1, 0.4, 0.1, 1.0)
#define WEISS  CGColorMakeWithRGBA( 1.0, 1.0, 1.0, 1.0)
#define GRAU   CGColorMakeWithRGBA( 0.85, 0.85, 0.85, 0.75)


static UIBitmapImage   *image;
static CGImage         *cgImage;


static void  drawPrettyBackground( CGContext *context, CGRect canvas)
{
   CGFloat             radius;
   CGFloat             strokeWidth;
   CGFont              *font;
   CGRect              rect;
   struct NVGcontext   *vg;

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




static UIWindowDisplayBits   display( UIPureWindow *window,
                                      id <UIGraphicsContext> context,
                                      struct CGFrameInfo *frameInfo,
                                      UIWindowDisplayBits displayBits)
{
   drawStuff( (CGContext *) context, CGFrameInfoGetContentRect( frameInfo));
   return( 1);
}


int   main( int argc, char *argv[])
{
   GLFWOSWindow    *glfwWindow[ 2];
   GLFWOSWindow    *sharingWindow;
   UIApplication   *app;
   UIPureWindow     *window[ 2];
   NSUInteger      i;
   BOOL            closed[ 2];
   CGRect          frame;

   app = [UIApplication sharedInstance];
   {
      image = (UIBitmapImage *) [UIImage imageWithContentsOfFileCString:"magpie-clipart-free-8.png"];
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

         window[ i] = [[[UIPureWindow alloc] initWithOSWindow:glfwWindow[ i]
                                            offscreenOSWindow:nil] autorelease];
         assert( window[ i]);

         [window[ i] setBackgroundHexColor:i ? CGHexColorBlue : CGHexColorGreen];
         [window[ i] setFrameCallback:display];

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

