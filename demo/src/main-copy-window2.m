#import "import.h"


//
// in this demo, we screenshot window 1 and display it in window2
//
static void   drawColorwheel(NVGcontext* vg, float x, float y, float w, float h, NSUInteger frameNumber)
{
   int i;
   float r0, r1, ax,ay, bx,by, cx,cy, aeps, r;
   float fummel = fmod( frameNumber / 100.0, NVG_PI * 2.0) == 0.0 ? 1.0 : fmod( frameNumber / 100.0, NVG_PI * 2.0);
   float hue = sinf( fummel * 0.12);
   float rot;
   NVGpaint paint;

   // stolen from the nanovg demo and stupedified

   // RING
   nvgSave(vg);
   {
      cx = x + w*0.5f;
      cy = y + h*0.5f;
      r1 = (w < h ? w : h) * 0.5f - 5.0f;
      r0 = r1 - 20.0f;
      aeps = 0.5f / r1; // half a pixel arc length in radians (2pi cancels out).

      nvgTranslate(vg, cx,cy);
      rot = -fummel;
      nvgRotate(vg, rot);
      nvgTranslate(vg, -cx,-cy);

      for (i = 0; i < 6; i++) {
         float a0 = (float)i / 6.0f * NVG_PI * 2.0f - aeps;
         float a1 = (float)(i+1.0f) / 6.0f * NVG_PI * 2.0f + aeps;
         nvgBeginPath(vg);
         nvgArc(vg, cx,cy, r0, a0, a1, NVG_CW);
         nvgArc(vg, cx,cy, r1, a1, a0, NVG_CCW);
         nvgClosePath(vg);
         ax = cx + cosf(a0) * (r0+r1)*0.5f;
         ay = cy + sinf(a0) * (r0+r1)*0.5f;
         bx = cx + cosf(a1) * (r0+r1)*0.5f;
         by = cy + sinf(a1) * (r0+r1)*0.5f;
         paint = nvgLinearGradient(vg, ax,ay, bx,by, nvgHSLA(a0/(NVG_PI*2),1.0f,0.55f,255), nvgHSLA(a1/(NVG_PI*2),1.0f,0.55f,255));
         nvgFillPaint(vg, paint);
         nvgFill(vg);
      }

      nvgBeginPath(vg);
      nvgCircle(vg, cx,cy, r0-0.5f);
      nvgCircle(vg, cx,cy, r1+0.5f);
      nvgStrokeColor(vg, nvgRGBA(0,0,0,64));
      nvgStrokeWidth(vg, 1.0f);
      nvgStroke(vg);
   }
   nvgRestore(vg);

   // TRIANGLE
   nvgSave(vg);
   {
      nvgTranslate(vg, cx,cy);
      rot = fummel;
      nvgRotate(vg, rot);

      r = r0 - 6;
      ax = cosf(120.0f/180.0f*NVG_PI) * r;
      ay = sinf(120.0f/180.0f*NVG_PI) * r;
      bx = cosf(-120.0f/180.0f*NVG_PI) * r;
      by = sinf(-120.0f/180.0f*NVG_PI) * r;
      nvgBeginPath(vg);
      nvgMoveTo(vg, r,0);
      nvgLineTo(vg, ax,ay);
      nvgLineTo(vg, bx,by);
      nvgClosePath(vg);
      paint = nvgLinearGradient(vg, r,0, ax,ay, nvgHSLA(hue,1.0f,0.5f,255), nvgRGBA(255,255,255,255));

      nvgFillPaint(vg, paint);
      nvgFill(vg);
      paint = nvgLinearGradient(vg, (r+ax)*0.5f,(0+ay)*0.5f, bx,by, nvgRGBA(0,0,0,0), nvgRGBA(0,0,0,255));
      nvgFillPaint(vg, paint);
      nvgFill(vg);
      nvgStrokeColor(vg, nvgRGBA(0,0,0,64));
      nvgStroke(vg);
   }
   nvgRestore(vg);
}


static void  drawStuff( CALayer *layer, CGContext *context)
{
   CGFloat   diameter;
   CGRect    canvas;
   CGRect    rect;
   CGPoint   a;
   CGPoint   b;

   canvas      = [layer canvas];
   rect        = UIEdgeInsetsInsetRect( canvas, UIEdgeInsetsMake( 50, 50, 50, 50));
   diameter    = CGFloatMinimum( CGRectGetWidth( rect), CGRectGetHeight( rect));
   rect.origin = CGSizeGetCenterPointInRect( CGSizeMake( diameter, diameter), rect);
   rect.size   = CGSizeMake( diameter, diameter);

   drawColorwheel( CGContextGetNVGContext( context),
                   rect.origin.x,
                   rect.origin.y,
                   diameter,
                   diameter,
                   [context numberOfFrames]);
}


static void   setupSceneInWindow( UIWindow *window)
{
   UIView   *view;
   CGRect   frame;
   UIView   *contentPlane;

   contentPlane = [window contentView];

   frame = [contentPlane contentRect];
   frame = UIEdgeInsetsInsetRect( frame, UIEdgeInsetsMake( 40, 40, 40, 40));

   view  = [UIView viewWithFrame:frame];
   [view setBackgroundColor:CGColorMakeWithRGBA( 0.0, 0.0, 0.0, 1.0)];
   [(CGGraphicsLayer *) [view layer] setDrawCallback:(CGGraphicsLayerDrawCallback_t *) drawStuff];
   [contentPlane addSubview:view];
}


static void  copyStuff( CALayer *layer, CGContext *context)
{
   CGFloat      diameter;
   CGRect       rect;
   NVGcontext   *vg;

   rect = [layer canvas];
   rect = UIEdgeInsetsInsetRect( rect, UIEdgeInsetsMake( 2, 2, 2, 2));
   diameter = CGFloatMinimum( CGRectGetWidth( rect), CGRectGetHeight( rect));

   vg = CGContextGetNVGContext( context);
   nvgBeginPath( vg);
   {
      nvgCircle( vg, CGRectGetMidX( rect), CGRectGetMidY( rect), diameter / 2.0);
      nvgStrokeColor( vg, CGColorMakeWithRGBA( 1.0, 1.0, 1.0, 1.0));
      nvgStrokeWidth( vg, 4.0);
   }
   nvgStroke( vg);
}


static void   setupCopyInWindow( UIWindow *window)
{
   UIView   *view;
   CGRect   frame;
   UIView   *contentPlane;

   contentPlane = [window contentView];

   frame = [contentPlane contentRect];
   view  = [UIImageView viewWithFrame:frame];
   [view setTag:1];
   [view setAutoresizingMask:UIViewAutoresizingScaleToFill];
   [view setBackgroundColor:CGColorMakeWithRGBA( 0.0, 1.0, .0, 1.0)];
   [contentPlane addSubview:view];
}


int   main( int argc, char *argv[])
{
   UIWindow        *window[ 2];
   UIApplication   *app;
   UIImageView     *imageView;
   UIImage         *image;
   BOOL            closed[ 2];

   app = [UIApplication sharedInstance];
   {
      window[ 0] = [[[UIWindow alloc] initWithFrame:CGRectMake( 100.0, 100.0, 400.0, 400.0)
                                    titleUTF8String:NULL
                                          styleMask:UIWindowStyleBare|UIWindowStyleInvisible] autorelease];
      [window[ 0] setBackgroundColor:CGColorMakeWithRGBA( 1.0, 0.0, 0.0, 1.0)];
      setupSceneInWindow( window[ 0]);
      [window[ 0] setFrameRateHz:60.0];
      [app addWindow:window[ 0]];

      window[ 1] = [UIWindow windowWithFrame:CGRectMake( 500.0, 100.0, 400.0, 400.0)
                             titleUTF8String:NULL
                                   styleMask:UIWindowStyleMaskNonRetained];
      [window[ 1] setBackgroundColor:CGColorMakeWithRGBA( 0.0, 1.0, 0.0, 1.0)];
      setupCopyInWindow( window[ 1]);
      [app addWindow:window[ 1]];

      closed[ 0] = NO;
      closed[ 1] = NO;
      while( ! closed[ 0] || ! closed[ 1])
      {
         if( ! closed[ 0])
         {
            closed[ 0] = ! [window[ 0] processOneFrame];
            if( closed[ 0])
               fprintf( stderr, "0 closed\n");
         }

         if( ! closed[ 1])
         {
            if( ! closed[ 0])
            {
               image     = [window[ 0] screenshotBitmapImage];
               imageView = (UIImageView *) [[window[ 1] view] findViewWithTag:1];
               assert( imageView);
               [imageView setImage:image];
            }

            closed[ 1] = ! [window[ 1] processOneFrame];
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

