#define _GNU_SOURCE

#import "import.h"

#include <math.h>
#include <stdlib.h>


#define DRAW_FLAT           0
#define STOP_AFTER_FRAMES   0
#define DUMP_AFTER_STOP     0  // produce stdout instead


struct mulle_utf8data   reduce_text( char *s)
{
   char   *start;
   char   *end;

   start = strchr( s, ' ');
   start = start ? start + 1 : s;
   end   = strrchr( start, ']');
   if( ! end)
      return( mulle_utf8data_make( s, -1));
   return( mulle_utf8data_make( start, end - start));
}



@interface WindowProfileLayer : CAAccumulationLayer
{
   struct mulle_structqueue   *_profileQueue;
}

@property( assign) CGFloat    minimumRectWidth;
@property( assign) CGFloat    minimumHeight;
@property( assign) CGFloat    maximumHeight;
@property( assign) BOOL       drawStacked;
@property( assign) BOOL       drawText;

- (void) setProfileQueue:(struct mulle_structqueue *) queue;

@end



@implementation WindowProfileLayer


- (instancetype) init
{
   self = [super init];
   if( self)
   {
      _minimumRectWidth = 3.0;
      _drawStacked      = NO;
      _drawText         = YES;

      _minimumHeight    = 2.0;
      _minimumHeight    = 13.0;
   }
   return( self);
}

- (void) setProfileQueue:(struct mulle_structqueue *) queue
{
   UIWindowDestroyProfileQueue( _profileQueue);
   _profileQueue = queue;
}



// each rectangle we draw is temporarily stored
struct rect
{
   CGRect      rect;
   CGHexColor  color;
   char        *text;
};


// some values together for easier passing
struct scene
{
   mulle_absolutetime_t   start;
   mulle_absolutetime_t   end;
   mulle_relativetime_t   elapsed;
   mulle_relativetime_t   refreshRate;
   mulle_relativetime_t   frameRate;
   CGFloat                minimumRectWidth;
   CGFloat                height;
   CGRect                 canvas;
   CGColor                backgroundColor;
   BOOL                   drawText;

   CGFloat                x;
   CGFloat                x2;
   CGFloat                w;
   CGFloat                scale;
};


static void   rect_start( struct rect *r,
                          struct scene *p,
                          struct MulleWindowProfileEntry *entry,
                          NSInteger level)
{
   CGFloat      x;
   CGFloat      y;
   NSUInteger   hash;

   assert( level >= 0);
   assert( entry->timestamp >= p->start);
   assert( p->elapsed > 0.0);
   assert( p->refreshRate > 0.0);

   x = p->x + (entry->timestamp - p->start) * p->scale;
   if( x > p->x2)
      x = p->x2;

   y = ((level + 1) * p->height);

   r->rect = CGRectMake( + x,
                         - y,
                         CGRectGetWidth( p->canvas),
                         p->height);
   if( entry->flags.mode & MulleWindowProfileEntryFunctionIsAddress)
      hash = mulle_pointer_hash( entry->function);
   else
      hash = entry->function ? _mulle_string_hash( entry->function) : 0x1848;

   r->color = CGHexColorMakeWithNameAtIndex( hash);

   if( entry->function && ! (entry->flags.mode & MulleWindowProfileEntryFunctionIsAddress))
      r->text = entry->function;
   else
      r->text = "";
}


static void   rect_draw( struct rect *r,
                         struct scene *p,
                         struct MulleWindowProfileEntry *entry,
                         NVGcontext *vg)
{
   CGFloat                x;
   CGColor                color;
   CGColor                textColor;
   CGRect                 rect;
   struct mulle_utf8data  displayText;
   CGFloat                diff;

   x                  = p->x + (entry->timestamp - p->start) * p->scale;
   r->rect.size.width = x - r->rect.origin.x;
   diff               = r->rect.size.width - p->minimumRectWidth;
   if( diff < 0)
   {
      r->rect.size.width = p->minimumRectWidth;
      r->rect.origin.x  -= diff / 2.0;
   }
   r->rect.origin.x += CGRectGetMinX( p->canvas);
   r->rect.origin.y += CGRectGetMaxY( p->canvas);

   color = CGColorMakeWithHexColor( r->color);
   color = CGColorEnsureContrastWithColor( color, p->backgroundColor);

   mvgFillRectWithColor( vg, r->rect, color);

   if( p->drawText)
   {
      rect = CGRectInsetOrZero( r->rect, 1, 1);

      textColor = CGColorSuggestTextColor( color);
      mvgTextColor( vg, textColor);
      mvgTextBackgroundColor( vg, color);
      mvgFontSize( vg, rect.size.height);

      displayText = reduce_text( r->text);
      mvgTextInRect( vg, displayText.characters, displayText.length, rect, CGContentModeBottomLeft, 0);
   }
}


static void   draw_triangle( NVGcontext *vg, CGPoint center, CGSize size, CGPaint *paint)
{
   static CGPoint  points[ 3] =
   {
      CGPointData(  0.0, -0.5),
      CGPointData( -0.5,  0.5),
      CGPointData(  0.5,  0.5)
   };
   CGRect     rect;

   mvgSave( vg);
   {
      // STEPS are applied in reverse to the path

      // 2. move center of scaled triangle to destination
      mvgTranslate( vg, center);

      // 1. scale (still center at 0.0)
      mvgScale( vg, CGVectorMake( size.width, size.height));

      mvgBeginPath( vg);
      mvgMoveTo( vg, points[ 0]);
      mvgLineTo( vg, points[ 1]);
      mvgLineTo( vg, points[ 2]);
      mvgClosePath( vg);

      rect = CGRectMakeWithCenterPointAndSize( CGPointZero, CGSizeMake( 1.0, 1.0));
      [paint fillWithBounds:rect
                 NVGcontext:vg];

   }
   mvgRestore( vg);
}



- (void) drawProfileQueueInContext:(CGContext *) context
{
   struct MulleWindowProfileEntry   *entry;
   struct MulleWindowProfileEntry   fake;
   NSInteger                        level;
   NSUInteger                       maxLevel;
   NSUInteger                       maxVisibleLevel;
   NSUInteger                       i;
   struct scene                     scene;
   struct NVGcontext                *vg;
   struct CGFrameInfo               *frameInfo;
   CGFloat                          x;
   mulle_relativetime_t             timestamp;

   frameInfo = [context currentFrameInfo];
   assert( frameInfo);

   level    = 0;
   maxLevel = 0;
   memset( &scene, 0, sizeof( scene));

   mulle_structqueue_for( _profileQueue, entry)
   {
      if( scene.start == 0)
         scene.start = entry->timestamp;

      assert( entry->timestamp >= scene.start);

      switch( entry->flags.action)
      {
      case MulleWindowProfileEntryBegin :
         if( ++level > maxLevel)
            maxLevel = level;
         break;

      case MulleWindowProfileEntryEnd :
         if( --level < 0)
            level = 0;
      default :
         break;
      }
      scene.end = entry->timestamp;
   }

   scene.drawText         = _drawText;
   scene.elapsed          = scene.end - scene.start;
   scene.minimumRectWidth = _minimumRectWidth;
   scene.refreshRate      = frameInfo->refreshRate;
   scene.frameRate        = frameInfo->frameRate;

   if( scene.elapsed <= 0.0)
   {
      MulleUICLog( "No time spent in scene");
      return;
   }

   if( maxLevel == 0)
   {
      MulleUICLog( "No profile entries recorded in scene");
      return;
   }

   // draw stuff between start and end
   if( _minimumHeight <= 1.0)
      _minimumHeight = 1.0;
   if( _minimumHeight > _maximumHeight)
      _maximumHeight = _minimumHeight;

   scene.canvas = [self canvas];
   scene.height = _maximumHeight;

   if( _minimumHeight < _maximumHeight)
   {
      scene.height = scene.canvas.size.height / maxLevel;
      if( scene.height > _maximumHeight)
         scene.height = _maximumHeight;
      if( scene.height < _minimumHeight)
         scene.height = _minimumHeight;
   }

   scene.backgroundColor = [[self backgroundPaint] mainColor];

   // if some part on top is missing its fine
   maxVisibleLevel = ceil( scene.canvas.size.height / scene.height);
   if( maxLevel > maxVisibleLevel)
      maxLevel = maxVisibleLevel;


   //
   // the actual "point" scale is
   // minimumRectWidth / 2.0 to CGRectGetWidth( canvas) - minimumRectWidth
   //   |                                  |
   //
   scene.x     = _minimumRectWidth / 2.0;
   scene.w     = CGRectGetWidth( scene.canvas) - scene.minimumRectWidth;
   if( scene.w < _minimumRectWidth / 2.0)
   {
      // too small to draw anything
      return;
   }
   scene.x2    = scene.x + scene.w;
   scene.scale = scene.w / scene.elapsed;

   vg = CGContextGetNVGContext( context);

   //
   // in a flamegraph we can't have more than maxLevel rects open at one time
   //
   mulle_calloca_do( rects, struct rect, maxLevel)
   {
      level = 0;
      mulle_structqueue_for( _profileQueue, entry)
      {
         switch( entry->flags.action)
         {
         case MulleWindowProfileEntryBegin :
            if( level < maxLevel)
            {
               rect_start( &rects[ level], &scene, entry, _drawStacked ? level : 0);
               ++level;
            }
            break;

         case MulleWindowProfileEntryEnd :
            if( --level < 0)
            {
               level = 0;
               break;
            }

            if( level < maxLevel)
            {
               rect_draw( &rects[ level], &scene, entry, vg);
            }

         default :
            break;
         }
      }

      while( level)
      {
         --level;
         // create a fake entry for missing ends
         if( level < maxLevel)
         {
            fake           = *entry;
            fake.timestamp = scene.end + 0.01;
            rect_draw( &rects[ level], &scene, &fake, vg);
         }
      }
   }


   // paint markers for frameRate (green) and refreshRate (yellow)

   assert( ! isinf( scene.refreshRate));
   if( scene.refreshRate > 0.0)
   {
      for( timestamp = scene.refreshRate; timestamp <= scene.elapsed; timestamp += scene.refreshRate)
      {
         x = scene.x + (timestamp * scene.scale);
         mvgStrokeLineVWithColor( vg, CGPointMake( x, CGRectGetMaxY( scene.canvas) - scene.height),
                                      scene.height,
                                      0.5,
                                      CGColorMakeLightGray());
      }
   }

   if( ! isinf( scene.frameRate) && scene.frameRate > 0.0)
   {
      for( timestamp = scene.frameRate; timestamp <= scene.elapsed; timestamp += scene.frameRate)
      {
         x = scene.x + (timestamp * scene.scale);
         mvgStrokeLineVWithColor( vg, CGPointMake( x, CGRectGetMaxY( scene.canvas) - scene.height),
                                      scene.height,
                                      0.5,
                                      CGColorMakeWhite());
      }
   }
}


- (BOOL) drawInContext:(CGContext *) context
{
   if( ! [super drawInContext:context])
      return( NO);

#if STOP_AFTER_FRAMES
   if( [context numberOfFrames] == STOP_AFTER_FRAMES)
   {
#if DUMP_AFTER_STOP
      [[[context OSWindow] parentWindow] dumpProfileQueue];
      fflush( stdout);
#endif
      _exit( 0);
   }
#endif

   [self drawProfileQueueInContext:context];

   return( YES);
}



static void  didSwapBuffersCallback( UIWindow *window, BOOL immediately)
{
   struct mulle_structqueue   *profileQueue;
   UIView                     *view;
   WindowProfileLayer         *layer;

//   MulleUICLog( "%#@", window);

   profileQueue = [window extractProfileQueue];
   view         = [[window contentView] subviewWithTag:1848];
   layer        = (WindowProfileLayer *) [view layer];
   [layer setProfileQueue:profileQueue];
}

@end


static void   usage( void)
{
   fprintf( stderr, "\n"
"Usage:\n"
"   window-profile [options]\n"
"\n"
"   Display window profile of current and past frames."
"\n"
"Options:\n"
"   -i <v>  : swap interval (0-2)\n"
"   -a      : async\n"
"   -f <hz> : refresh in hz\n"
"   -m      : retained on main thread (is async only)\n"
"   -r      : retained\n"
"   -u      : no sync\n"
"   -s      : sync (default)\n"
"\n");
   exit( 1);
}


int   main( int argc, char *argv[])
{
   UIWindow               *window;
   UIApplication          *app;
   int                    i;
   NSUInteger             styleMask;
   NSUInteger             swapInterval;
   BOOL                   isRetained;
   BOOL                   isMainThread;
   mulle_relativetime_t   frameRate;
   UIView                 *view;
   CALayer                *layer;

   swapInterval = 0;
   frameRate    = 2.0;
   isRetained   = NO;
   isMainThread = NO;

   /*
    * window and app
    */
   for( i = 1; i < argc; i++)
   {
      if( argv[ i][ 0] != '-')
         break;
      switch( argv[ i][ 1])
      {
      case 'a' :
         frameRate = UIWindowFrameRateAsync;
         break;

      case 'f' :
         if( ++i < argc)
            frameRate = 1 / atof( argv[ i]);
         break;

      case 'i' :
         if( ++i < argc)
            swapInterval = atoi( argv[ i]);
         break;

      case 'm' :
         isRetained   = YES;
         isMainThread = YES;
         break;

      case 'r' :
         isRetained = YES;
         break;

      case 's' :
         frameRate = UIWindowFrameRateSynced;
         break;

      case 'u' :
         frameRate = UIWindowFrameRateUnsynced;
         break;

      default :
         usage();
      }
   }

   if( i != argc)
      usage();

   fprintf( stderr, "%s\n", [CGContext nanoVGBackendUTF8String]);

   app = [UIApplication sharedInstance];
   {
      // UIWindowStyleRenderNonRetainedOnly
      styleMask = UIWindowStyleMaskDefault|UIWindowStyleProfileQueue;
      if( ! isRetained)
         styleMask &= ~UIWindowStyleRetained;
      else
         if( isMainThread)
            styleMask |= UIWindowStyleRetainedOnMainThread;

      window = [UIWindow windowWithFrame:CGRectMake( 0.0, 0.0, 600.0, 400.0)
                         titleUTF8String:"Demo"
                               styleMask:styleMask];
      [window setBackgroundColor:CGColorMakeWhite()];

      layer = [WindowProfileLayer layerWithFrame:[[window contentView] contentRect]];
      view  = [UIView viewWithLayer:layer];
      [view setAutoresizingMask:UIViewAutoresizingScaleToFill];
      [view setTag:1848];
      [[window contentView] addSubview:view];
#if ! DUMP_AFTER_STOP
      [window setDidSwapBuffersCallback:didSwapBuffersCallback];
#endif
      [window setFrameRate:frameRate];
      [UIApp addWindow:window];
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

