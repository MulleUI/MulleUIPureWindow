#import "import.h"


static const GLfloat   vertices[4][2] =
{
    { -0.5f, -0.5f },
    { -0.5f,  0.5f },
    {  0.5f,  0.5f },
    {  0.5f, -0.5f }
};

#define BLAU   CGColorMakeRGBA( 0.1, 0.1, 0.4, 1.0)
#define GRUEN  CGColorMakeRGBA( 0.1, 0.4, 0.1, 1.0)
#define WEISS  CGColorMakeRGBA( 1.0, 1.0, 1.0, 1.0)

#define R   { 0xFF, 0, 0, 0xFF }
#define G   { 0, 0xFF, 0, 0xFF }
#define B   { 0, 0, 0xFF, 0xFF }

static unsigned char   stupidtex[ 8][ 8][ 4] =
{
   { R, R, R, R,   R, R, R, R },
   { R, R, B, B,   G, G, R, R },
   { R, R, B, B,   G, G, R, R },
   { R, B, B, B,   G, G, G, R },

   { R, B, B, B,   G, G, G, R },
   { R, R, B, B,   G, G, R, R },
   { R, R, B, B,   G, G, R, R },
   { R, R, R, R,   R, R, R, R }
};

static UIBitmapImage   *image;
static CGImage         *cgImage;


static void  drawPrettyBackground( CALayer *layer, CGContext *context)
{
   CGFloat                    radius;
   CGFloat                    strokeWidth;
   CGFont                     *font;
   CGRect                     canvas;
   CGRect                     rect;
   struct NVGcontext          *vg;

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


//
// unused, just here to remind me how to use nvgCopyImage
//
static void  drawStuff_nvg( CALayer *layer, CGContext *context)
{
   struct NVGcontext          *vg;
   struct CGDrawableOptions   options;
   static int                 imageHandle[ 2];
   static NVGcontext          *vgs[ 2];
   int                        imageID;
   NVGpaint                   imgPaint;

   drawPrettyBackground( layer, context);

   vg = CGContextGetNVGContext( context);

   imageID = 0;
   if( vgs[ 0] == vg)
      imageID  = imageHandle[ 0];
   else
      imageID  = imageHandle[ 1];

   if( ! imageID)
   {
      if( ! imageHandle[ 0])
      {
         vgs[ 0]         = vg;
         imageHandle[ 0] = nvgCreateImageRGBA( vg, 8, 8, 0, (void *) stupidtex);
         imageID         = imageHandle[ 0];
      }
      else
      {
         vgs[ 1]         = vg;
         imageHandle[ 1] = nvgCopyImage( vgs[ 1], vgs[ 0], imageHandle[ 0]);
         imageID         = imageHandle[ 1];
      }
   }

   imgPaint  = nvgImagePattern( vg, 32.0,
                                    32.0,
                                    128.0,
                                    128.0,
                                    0.0,
                                    imageID,
                                    1.0);

   nvgBeginPath( vg);
   nvgRoundedRect( vg, 32.0, 32.0, 128.0, 128.0, 0.0);
   nvgFillPaint( vg, imgPaint);
   nvgFill( vg);
}


static void  drawStuff( CALayer *layer, CGContext *context)
{
   struct CGDrawableOptions   options;
   static CGImage             *cgImage[ 2];
   static CGContext           *contexts[ 2];

   drawPrettyBackground( layer, context);

   options = CGDrawableOptionsMake( 0.0, 1.0, 0.0, YES);

   if( ! cgImage[ 0])
   {
      cgImage[ 0] = [[image cgImageWithContext:context
                                   imageFlags:0] retain];
      contexts[ 0] = context;
   }
   else
      if( ! cgImage[ 1])
      {
         cgImage[ 1]  = [[cgImage[ 0] shareWithContext:context] retain];
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
}



static void   setupSceneInView( UIView *contentPlane, CGColor color)
{
   UIView   *view;
   CGRect   frame;

   frame = [contentPlane contentRect];
   frame = UIEdgeInsetsInsetRect( frame, UIEdgeInsetsMake( 10, 10, 10, 10));

   view  = [UIView viewWithFrame:frame];
   [view setBackgroundColor:color];
   [(CALayer *) [view layer] setDrawCallback:drawStuff];
   [contentPlane addSubview:view];
}


int   main( int argc, char *argv[])
{
   GLFWOSWindow    *glfwWindow[ 2];
   UIApplication   *app;
   UIWindow        *window[ 2];
   NSUInteger      i;
   BOOL            closed[ 2];
   CGRect          frame;

   app = [UIApplication sharedInstance];
   {
      image = (UIBitmapImage *) [UIImage imageWithContentsOfFileCString:"parrot.png"];
      assert( image);

      for( i = 0; i < 2; i++)
      {
         frame = CGRectMake( 0.0 + 500 * i, 100.0, 400.0, 300.0);
         glfwWindow[ i] = [[[GLFWOSWindow alloc] initWithFrame:frame
                                                titleUTF8String:! i ? "Demo" : "Demo2"
                                                      styleMask:0
                                                  graphicsHints:0
                                                  sharingWindow:i ? glfwWindow[ 0] : NULL] autorelease];

         window[ i] = [[[UIWindow alloc] initWithOSWindow:glfwWindow[ i]
                                        offscreenOSWindow:nil] autorelease];
         assert( window[ i]);

         [window[ i] setBackgroundColor:WEISS];

         setupSceneInView( [window[ i] contentPlane], i ? BLAU : GRUEN);

         [app addWindow:window[ i]];
      }

      // app should handle this...
      closed[ 0] = NO;
      closed[ 1] = NO;
      while( ! closed[ 0] && ! closed[ 1])
      {
         if( ! closed[ 0])
         {
            closed[ 0] = [window[ 0] runOneFrame];
            if( closed[ 0])
               fprintf( stderr, "0 closed\n");
         }
         if( ! closed[ 1])
         {
            closed[ 1] = [window[ 1] runOneFrame];
            if( closed[ 1])
               fprintf( stderr, "1 closed\n");
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

