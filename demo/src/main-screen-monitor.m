#import "import.h"

struct ShapeAppearance
{
    CGColor  fillColor;
    CGColor  strokeColor;
    CGFloat  strokeWidth;
};


#define ShapeAppearanceData( fc, sc, sw) \
(struct ShapeAppearance)                 \
{                                        \
   .fillColor   = fc,                    \
   .strokeColor = sc,                    \
   .strokeWidth = sw                     \
}

static void  mvgDrawPathWithAppearance( struct NVGcontext *vg,
                                        struct ShapeAppearance *appearance)
{
   if( ! CGColorIsTransparent( appearance->fillColor))
   {
      mvgFillColor(vg, appearance->fillColor);
      mvgFill( vg);
   }

   if( appearance->strokeWidth > 0.0)
   {
      mvgStrokeColor(vg, appearance->strokeColor);
      mvgStrokeWidth( vg, appearance->strokeWidth);
      mvgStroke( vg);
   }
}

struct TextAppearance
{
    CGColor      textColor;
    CGColor      textBackgroundColor;
};

#define TextAppearanceData( tc, tbc) \
(struct TextAppearance)              \
{                                    \
   .textColor = tc,                  \
   .textBackgroundColor = tbc        \
}


static void  mvgTextWithAppearance( struct NVGcontext *vg,
                                    CGPoint point,
                                    char *text,
                                    struct TextAppearance *appearance)
{
   mvgTextColor(vg, appearance->textColor);
   mvgTextBackgroundColor(vg, appearance->textBackgroundColor);
   mvgText( vg, point, text, (size_t) -1);
}


struct MonitorAppearance
{
    struct ShapeAppearance   bezel;
    struct ShapeAppearance   screen;
    struct ShapeAppearance   stand;
    struct ShapeAppearance   circle;
    struct TextAppearance    digit;
    struct TextAppearance    info;
};


static struct MonitorAppearance  appearance =
{
    .bezel  =
    {
      .fillColor   = CGColorDataTransparent,
      .strokeColor = CGColorDataBlack,
      .strokeWidth = 3.0f
    },
    .screen = ShapeAppearanceData( CGColorDataBlack,       CGColorDataTransparent, 0.0),
    .stand  = ShapeAppearanceData( CGColorDataGray,        CGColorDataBlack, 3.0),
    .circle = ShapeAppearanceData( CGColorDataWhiteSmoke,  CGColorDataTransparent, 0.0),
    .digit  = TextAppearanceData( CGColorDataGray, CGColorDataWhiteSmoke),
    .info   = TextAppearanceData( CGColorDataWhite, CGColorDataBlack)
};


//
// the monitor draw function was coded by Cody/Sourcegraph/Claude Sonnet 3.5
// it's doing a pretty good job.
//
static void drawMonitor( struct NVGcontext *vg,
                        CGRect frame,
                        NSUInteger index,
                        id <UIScreen> screen,
                        struct MonitorAppearance *appearance)
{
  CGRect screenRect;
  CGRect bezelRect;
  CGRect standRect;
  CGRect infoRect;
  CGFloat cornerRadius = 10.0;
  CGRect circleBounds;
  CGSize actualScreenSize = [screen frame].size;
  CGFloat aspectRatio = actualScreenSize.width / actualScreenSize.height;

  // Calculate available space for the screen (subtracting space for bezel and stand)
  CGFloat availableWidth = CGRectGetWidth(frame) * 0.8;
  CGFloat availableHeight = CGRectGetHeight(frame) * 0.6;

  // Calculate screen dimensions while maintaining aspect ratio
  if (availableWidth / availableHeight > aspectRatio) {
      screenRect.size.height = availableHeight;
      screenRect.size.width = screenRect.size.height * aspectRatio;
  } else {
      screenRect.size.width = availableWidth;
      screenRect.size.height = screenRect.size.width / aspectRatio;
  }

  screenRect.origin.x = CGRectGetMidX(frame) - screenRect.size.width / 2;
  screenRect.origin.y = CGRectGetMidY(frame) - screenRect.size.height / 2;

  // Draw outer rounded rectangle (monitor frame)
  mvgBeginPath(vg);
  bezelRect = CGRectInset(screenRect, -10, -10);
  mvgRoundedRect(vg, bezelRect, cornerRadius);
  mvgDrawPathWithAppearance(vg, &appearance->bezel);

  // Draw inner rectangle (screen)
  mvgBeginPath(vg);
  mvgRect(vg, screenRect);
  mvgDrawPathWithAppearance(vg, &appearance->screen);

  // Draw stand using CGRectGetMaxY(bezelRect) for precise connection
  CGFloat baseWidth = screenRect.size.width * 0.4;
  CGFloat baseHeight = screenRect.size.height * 0.05;
  CGFloat baseX = CGRectGetMidX(frame) - baseWidth / 2;
  CGFloat baseY = CGRectGetMaxY(bezelRect) + screenRect.size.height * 0.075;
  CGFloat neckWidth = screenRect.size.width * 0.05;
  CGFloat neckX = CGRectGetMidX(frame) - neckWidth / 2;
  CGFloat neckTopY = CGRectGetMaxY(bezelRect);

  nvgBeginPath(vg);
  nvgMoveTo(vg, baseX, baseY + baseHeight);
  nvgLineTo(vg, baseX + baseWidth, baseY + baseHeight);
  nvgLineTo(vg, baseX + baseWidth, baseY);
  nvgLineTo(vg, neckX + neckWidth, baseY);
  nvgLineTo(vg, neckX + neckWidth, neckTopY);
  nvgLineTo(vg, neckX, neckTopY);
  nvgLineTo(vg, neckX, baseY);
  nvgLineTo(vg, baseX, baseY);
  nvgClosePath(vg);
  mvgDrawPathWithAppearance(vg, &appearance->stand);   mvgSave(vg);

   // Set up clipping to screenFrame
   mvgIntersectScissor(vg, screenRect);
   {
  // Draw big circle
  CGFloat radius = fmin(CGRectGetWidth(screenRect), CGRectGetHeight(screenRect)) * 0.3;
  circleBounds = CGRectInset( screenRect, radius / 2, radius / 2);
  CGPoint center = CGRectGetCenterPoint(circleBounds);
  radius = fmin(CGRectGetWidth(circleBounds), CGRectGetHeight(circleBounds)) * 0.3;

  nvgBeginPath(vg);
  mvgCircle(vg, CACircleMake( center, radius));
  mvgDrawPathWithAppearance( vg, &appearance->circle);

  // Draw index number (assuming index 1 for this example)
  nvgFontSize(vg, radius);
  nvgTextAlign(vg, NVG_ALIGN_CENTER | NVG_ALIGN_MIDDLE);
  mulle_buffer_do( buffer)
  {
     mulle_buffer_sprintf( buffer, "%tu", index + 1);
     mvgTextWithAppearance(vg, center, mulle_buffer_get_string( buffer), &appearance->digit);
  }

  infoRect = CGRectInset( screenRect, 10, 10);
  nvgFontSize( vg, 14);
  nvgTextAlign(vg, NVG_ALIGN_BOTTOM | NVG_ALIGN_LEFT);
  CGPoint namePoint = CGRectGetCornerPoint( infoRect, CADirectionBottom|CADirectionLeft);
  mvgTextWithAppearance(vg, namePoint, [screen nameUTF8String], &appearance->info);

  nvgTextAlign(vg, NVG_ALIGN_TOP | NVG_ALIGN_RIGHT);
  CGPoint sizePoint = CGRectGetCornerPoint( infoRect, CADirectionTop|CADirectionRight);
  mvgTextWithAppearance(vg, sizePoint, CGRectUTF8String( [screen frame]), &appearance->info);
   }
   mvgRestore(vg);
}


static void  drawStuff( CALayer *layer, CGContext *context)
{
   CGRect              canvas;
   struct NVGcontext   *vg;
   id <UIScreen>       screen;
   NSUInteger          i, n;
   CGRect              rects[ 9]; // h w
   CGRect              *p_rects;

   canvas = [layer canvas];
   vg     = CGContextGetNVGContext( context);

   [context useDefaultFont];

   // divide screen into equal parts
   n = [UIApp numberOfScreens];
   switch( n)
   {
   case 1 :
      p_rects = (CGRect *) &canvas;
      break;

   case 2 :
      CGRectPartitionIntoRows( canvas, 20, 2, rects);
      p_rects = (CGRect *) rects;
      break;

   case 3 :
   case 4 :
      CGRectPartition2x2( canvas, CGSizeMake( 20, 20), (void *) rects);
      p_rects = (CGRect *) rects;
      break;

   case 5 :
   case 6 :
   case 7 :
   case 8 :
   default :
         n = n >= 9 ? 9 : n;
         CGRectPartition3x3( canvas, CGSizeMake( 20, 20), (void *) rects);
         p_rects = (CGRect *) rects;
         break;
   }

   for( i = 0; i < n; i++)
   {
      screen = [UIApp screenAtIndex:i];
      drawMonitor(vg, *p_rects++, i, screen, &appearance);
   }
}

@interface ScreenMonitorView : UIView
@end


@implementation ScreenMonitorView

- (instancetype) initWithLayer:(id <UILayer>)layer
                         frame:(CGRect) frame
{
   self = [super initWithLayer:layer
                         frame:frame];
   [self setAutoresizingMask:UIViewAutoresizingFlexibleSize];
   [self setBackgroundColor:CGColorMakeAliceBlue()];
   [(CGGraphicsLayer *) layer  setDrawCallback:(CGGraphicsLayerDrawCallback_t *) drawStuff];
   return( self);
}

//
// Only the view (root) of the UIWindow gets events, that do not have a
// mousePosition, so we made our view the root view. Otherwise we would
// have needed to subclass UIWindow
//
- (UIEvent *) handleEvent:(UIEvent *)event
{
   if( [event eventType] == UIEventTypeScreen)
   {
      [self setNeedsDisplay];
      return( event);  // don't snarf let it propagate
   }
   return( event);
}

@end


//
// could also make UIWindow with NoView and then setView: (or create as
// is and setView:) many different ways to skin that cat
//
@implementation UIWindow( RootViewClass)

+ (Class) viewClass
{
   return( [ScreenMonitorView class]);
}

@end


int   main( int argc, char *argv[])
{
   UIWindow        *window;
   UIApplication   *app;
   NSUInteger      styleMask;
   
   app = [UIApplication sharedInstance];
   {
      // demo runs single threaded
      // styleMask = UIWindowStyleMaskDefault & ~(UIWindowStyleRetained|UIWindowStylePlanes);
      // demo runs multi threaded
      styleMask = UIWindowStyleMaskDefault & ~(UIWindowStylePlanes);
      window    = [UIWindow windowWithFrame:CGRectMake( 0.0, 0.0, 800.0, 800.0)
                            titleUTF8String:"Demo"
                                  styleMask:styleMask];

      assert( window);

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

