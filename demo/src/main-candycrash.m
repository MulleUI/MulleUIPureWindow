#define _GNU_SOURCE

#import "import.h"

#include <float.h>
#include <math.h>
#include <stdlib.h>

//#define DUMP


// kynd.info 2014
// Code "inspired" by paper.js demos

#define      MIN_RADIUS      40
#define      MAX_RADIUS      40
#define      numBalls        32
#define      maxVec          15
#define      overlapFactor   0.015  // bounce back over framerate 66.6 Hz ?
#define      smoothness      1.5      // > 0 < min radius

static id    balls[ numBalls];


@interface Ball : NSObject
{
   NSUInteger          _numSegment;
   CGFloat             *_boundOffset;
   CGFloat             *_boundOffsetBuff;
   struct CGPoint      *_sidePoints;
   CGColor              _fillColor;
}

@property( assign) CGPoint       point;
@property( assign) CGFloat       radius;
@property( assign) CAPolarPoint  vector;

@end


@implementation Ball

- (id) initWithRadius:(CGFloat) r
             position:(CGPoint) p
               vector:(struct CAPolarPoint) v
{
   NSUInteger       i;
   CAPolarPoint     x;
   CAAngleRadians   rad;
   CGFloat          hue;

   _radius          = r;
   _point           = p;
   _vector          = v;
   _numSegment      = (NSUInteger) floorf( r / smoothness) + 2;

   _boundOffset     = mulle_calloc( _numSegment, sizeof( CGFloat));
   _boundOffsetBuff = mulle_calloc( _numSegment, sizeof( CGFloat));
   _sidePoints      = mulle_calloc( _numSegment, sizeof( CGPoint));

   hue              = CGFloatMakeRandom();
//   printf( "hue: %.2f\n", hue);
   _fillColor       = CGColorMakeWithHSL( hue, 1, 0.5);

   for( i = 0; i < _numSegment; i++)
   {
      _boundOffset[ i]     = r;
      _boundOffsetBuff[ i] = r;
//      _path.add(new Point());
      rad                  = CAAngleDegreesToRadians( 360.0 / _numSegment * i);
      x                    = CAPolarPointMake( 1.0f, rad);
      _sidePoints[ i]      = CGPointMakeWithPolarPoint( x);
   }
   return( self);
}


#ifdef DUMP
- (void) dump:(char *) name
{
   NSUInteger   i;

   fprintf( stdout, "%s r=%.2f p=%.2f/%.2f v=%.2f,%.2f [", name,
                        _radius, _point.x, _point.y, _vector.angle, _vector.radius);
   for( i = 0; i <_numSegment; i++)
   {
      fprintf( stdout, " %.2f/%.2f", _sidePoints[ i].x, _sidePoints[ i].y);
   }
   fprintf( stdout, "]\n");
}
#endif

/*
 * Ball collision
 */

- (CGPoint) getSidePoint:(NSUInteger) index
{
   CGPoint   p;

   p    = _sidePoints[ index];
   p.x *= _boundOffset[ index];
   p.y *= _boundOffset[ index];
   p    = CGPointAdd( _point, p);
   return( p);
}


- (CGFloat) getBoundOffset:(CGPoint) b
{
   CGPoint          diff;
   CGFloat          angle;
   CAAngleDegrees   deg;

   diff  = CGPointSubtract( _point, b);
   deg   = CAAngleRadiansToDegrees( CGPointGetPolarAngle( diff));
   angle = fmodf( deg + 180.0, 360.0f);
   return( _boundOffset[ (NSUInteger) floor( angle / 360.0 * _numSegment)]);
}


- (void) calcBounds:(Ball *) b
{
   NSUInteger   i;
   CGPoint      tp;
   CGFloat      bLen;
   CGFloat      td;

   for( i = 0; i < _numSegment; i++)
   {
      tp   = [self getSidePoint:i];
      bLen = [b getBoundOffset:tp];
      td   = CGPointDistanceToPoint( tp, [b point]);
      if(td < bLen)
      {
         _boundOffsetBuff[ i] -= (bLen - td) / 2;
      }
   }
}


- (void) updateBounds
{
   NSUInteger   i;

   for( i = 0; i < _numSegment; i++)
      _boundOffset[i] = _boundOffsetBuff[i];
}


- (void) react:(Ball *) b
{
   CGFloat        dist;
   CGFloat        overlap;
   CAPolarPoint   direc;
   CGPoint        diff;

   dist = CGPointDistanceToPoint( _point, [b point]);
   assert( dist >= 0.0);
   if( (dist < _radius + [b radius]) && (dist != 0.0))
   {
      overlap = _radius + [b radius] - dist;

      diff    = CGPointSubtract( _point, [b point]);
      direc   = CAPolarPointMake( overlap * overlapFactor,
                                  CGPointGetPolarAngle( diff));
#ifdef DUMP
      fprintf( stdout, "dist=%.2f, overlap=%.2f, direc=%.2f,%2.f vector=%.2f,%2.f\n",
                  dist, overlap, direc.angle, direc.radius, _vector.angle, _vector.radius);
#endif
      _vector = CAPolarPointAdd( _vector, direc);
      [b setVector:CAPolarPointSubtract( [b vector], direc)];

      [self calcBounds:b];
      [b calcBounds:self];
      [self updateBounds];
      [b updateBounds];
   }
}

/*
 * Ball movement
 */

- (void) checkBorders:(CGSize) size
{
   if( _point.x < -_radius)
      _point.x = size.width + _radius;
   if( _point.x > size.width + _radius)
      _point.x = -_radius;
   if( _point.y < -_radius)
      _point.y = size.height + _radius;
   if( _point.y > size.height + _radius)
      _point.y = -_radius;
}


- (void) updateShape
{
   NSUInteger   i;
   NSUInteger   next;
   NSUInteger   prev;
   CGFloat      offset;
   CGPoint      p;

   for( i = 0; i < _numSegment; i++)
   {
      if( _boundOffset[ i] < _radius / 4)
         _boundOffset[ i] = _radius / 4;

      next    = (i + 1) % _numSegment;
      prev    = (i > 0) ? i - 1 : _numSegment - 1;
      offset  = _boundOffset[ i];
      offset += (_radius - offset) / 15; // maxVec; ??
      offset += ((_boundOffset[ next] + _boundOffset[ prev]) / 2 - offset) / 3;

      _boundOffsetBuff[ i] = _boundOffset[ i] = offset;
   }
}


- (void) iterate:(CGSize) size
{
   [self checkBorders:size];

   _vector.radius = fmodf( _vector.radius, maxVec);
   _point         = CGPointAddPolarPoint( _point, _vector);

   [self updateShape];
}



/*
 * Ball drawing
 */
- (void) drawInContext:(CGContext *) context
{
   NVGcontext   *vg;
   NSUInteger   i;
   CGPoint      p;

   vg = CGContextGetNVGContext( context);
   nvgBeginPath( vg);
   nvgGlobalCompositeOperation( vg, NVG_LIGHTER);
   for( i = 0; i < _numSegment; i++)
   {
      p = [self getSidePoint:i];
      if( ! i)
         nvgMoveTo( vg, p.x, p.y);
      else
         nvgLineTo( vg, p.x, p.y);
   }
   nvgClosePath( vg);

   // TODO: need to smooth
   nvgFillColor( vg, _fillColor);
   nvgFill( vg);
}

@end


static void  drawStuff( CALayer *layer, CGContext *context)
{
   CGRect       canvas;
   NSUInteger   i;
   NSUInteger   j;
   static int   rounds;

//#ifdef DEBUG
//   mulle_fprintf( stderr, "%s\n", __PRETTY_FUNCTION__);
//#endif

#ifdef DUMP
   [balls[ 0] dump:"a (before)"];
   [balls[ 1] dump:"b (before)"];
#endif

   for( i = 0; i < numBalls - 1; i++)
      for( j = i + 1; j < numBalls; j++)
         [balls[ i] react:balls[ j]];

#ifdef DUMP
   [balls[ 0] dump:"a (after)"];
   [balls[ 1] dump:"b (after)"];
#endif

   canvas = [layer canvas];
   for( i = 0; i < numBalls; i++)
      [balls[i] iterate:canvas.size];

   for( i = 0; i < numBalls; i++)
      [balls[ i] drawInContext:context];
}


static void   setupSceneInView( UIView *contentPlane)
{
   CGRect               contentRect;
   NSUInteger           i;
   Ball                 *ball;
   CGFloat              r;
   CGPoint              p;
   struct CAPolarPoint  v;

   contentRect = [contentPlane contentRect];
   [contentPlane setDrawCallback:drawStuff];

   for( i = 0; i < numBalls; i++)
   {
      r = CGFloatMakeRandom() * (MAX_RADIUS - MIN_RADIUS) + MIN_RADIUS;
      p = CGPointMakeRandomInRect( contentRect);
      v = CAPolarPointMake( CGFloatMakeRandom(),
                            CAAngleDegreesToRadians( CGFloatMakeRandom() * 360));
      balls[ i] = [[Ball alloc] initWithRadius:r
                                      position:p
                                        vector:v];
   }
//
//      balls[ 0] = [[Ball alloc] initWithRadius:100.0
//                                      position:CGPointMake( 100, 100.0)
//                                        vector:CAPolarPointMake( 1.0,
//                                                                 CAAngleHourToRadians( 6.0)
//                                                                 )];
//      balls[ 1] = [[Ball alloc] initWithRadius:100.0
//                                      position:CGPointMake( 100.0, 400.0)
//                                        vector:CAPolarPointMake( 1.0,
//                                                                 CAAngleHourToRadians( 12.0)
//                                                                 )];
}


int   main( int argc, char *argv[])
{
   UIWindow        *window;
   UIApplication   *app;
   MulleUIPerf     *perf;
   CGRect          frame;

   app = [UIApplication sharedInstance];
   {
      frame  = CGRectMake( 0.0, 0.0, 800.0, 600.0);
      window = [UIWindow windowWithFrame:frame
                         titleUTF8String:"Demo"
                               styleMask:UIWindowStyleMaskDefault & ~UIWindowStyleRetained];

//      window = [UIWindow windowWithFrame:CGRectMake( frame)];
      assert( window);

      // If alpha is 0.0 balls lose contour ?
      // If color is white, nothing is shown
      [window setBackgroundColor:CGColorMakeBlack()];
      [window setFrameRateHz:60.0];

      setupSceneInView( [window contentPlane]);

      [app addWindow:window];
   }

   perf = [MulleUIPerf object];
   [window setFrameDelegate:perf];

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

