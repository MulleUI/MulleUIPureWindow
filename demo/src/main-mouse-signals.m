#define _GNU_SOURCE

#import "import.h"

#include <math.h>

//#define ORIGINAL


/* 
 * stolen from: https://processing.org/examples/distance2d.html
 */
#define S_HISTORY_ITEMS   8192

struct mouse_history_item
{
   CGPoint     location;
   NSUInteger  state;   
};

static inline struct mouse_history_item   mouse_history_item_make( CGPoint location, NSUInteger state) 
{
   return( (struct mouse_history_item) { 
                                         .location = location, 
                                         .state = state 
                                       });
}  


struct mouse_history
{
   struct mouse_history_item   items[ S_HISTORY_ITEMS];
   unsigned int                write;
};


static void   mouse_history_add_item( struct mouse_history *p, struct mouse_history_item item)
{
   if( p->write >= S_HISTORY_ITEMS)
      p->write = 0;
   p->items[ p->write++] = item;
}


static struct mouse_history_item   mouse_history_get_item( struct mouse_history *p, unsigned int i)
{
   i = (p->write - i) % S_HISTORY_ITEMS; 
   if( i < 0)
      i = S_HISTORY_ITEMS + i;
   return( p->items[ i]);
}


static void   draw( CALayer *layer, CGContext *context)
{
   CGFloat                       size;
   CGPoint                       mouse;
   CGPoint                       center;
   CGRect                        canvas;
   CGFloat                       max;
   NSUInteger                    state;
   unsigned int                  i;
   static struct mouse_history   history;
   struct mouse_history_item     now;
   struct mouse_history_item     prev;
#ifndef ORIGINAL   
   CGPath                       *path[ 3];
#endif
   canvas = [layer canvas];

   mouse  = [context mouseLocation];
   state  = [context buttonStates];

//  background(237, 34, 93);

   [context fillRect:canvas
            hexColor:CGHexColorMakeWithColor( CGColorMakeWithRGBBytes( 237, 34, 93))];

   // Add the new values to the end of the array
   //  xvals[width - 1] = mouseX;
   //  yvals[width - 1] = mouseY;
   // if( mouseIsPressed) {
   //  bvals[width - 1] = 0;
   //  else {
   //  bvals[width - 1] = 255;
   // 
   mouse_history_add_item( &history, mouse_history_item_make( mouse, state));

   //   fill(255);
   //   noStroke();
   //   rect(0, height / 3, width, height / 3 + 1);
   [context fillRect:CGRectMake( 0, canvas.size.height / 3.0, canvas.size.width, canvas.size.height / 3 + 1)
            hexColor:CGHexColorMakeWithColor( CGColorMakeWithGrayByte( 255))];

   for( i = 1; i < (unsigned int) canvas.size.width; i++) 
   {
      now  = mouse_history_get_item( &history, i);
      prev = mouse_history_get_item( &history, i - 1);

#ifdef ORIGINAL   
      [context fillPoint:CGPointMake( i, now.location.x / 3)
              pointSize:2.0
                   color:CGColorMakeWithGrayByte( 255)];  
      [context fillPoint:CGPointMake( i, canvas.size.height / 3 + now.location.y / 3)
               pointSize:2.0
                   color:CGColorMakeWithGrayByte( 0)];
      [context drawLineFromPoint:CGPointMake( i, (2 * canvas.size.height) / 3 + (now.state ? 0 : 254) / 3)
                         toPoint:CGPointMake( i, (2 * canvas.size.height) / 3 + (prev.state ? 0 : 255) / 3)
                     strokeWidth:2.0
                           color:CGColorMakeWithGrayByte( 255)];
#else 
      if( i == 1)
      {
         path[ 0] = CGPathCreate( NULL);
         path[ 1] = CGPathCreate( NULL);
         path[ 2] = CGPathCreate( NULL);

         CGPathMoveToPoint( path[ 0], CGPointMake( i, now.location.x / 3));
         CGPathMoveToPoint( path[ 1], CGPointMake( i, canvas.size.height / 3 + now.location.y / 3));
         CGPathMoveToPoint( path[ 2], CGPointMake( i, (2 * canvas.size.height) / 3 + (now.state ? 0 : 254) / 3));
         CGPathAddLineToPoint( path[ 2], CGPointMake( i, (2 * canvas.size.height) / 3 + (prev.state ? 0 : 255) / 3));
      }
      else 
      {
         CGPathAddLineToPoint( path[ 0], CGPointMake( i, now.location.x / 3));
         CGPathAddLineToPoint( path[ 1], CGPointMake( i, canvas.size.height / 3 + now.location.y / 3));
         CGPathAddLineToPoint( path[ 2], CGPointMake( i, (2 * canvas.size.height) / 3 + (now.state ? 0 : 254) / 3));
         CGPathAddLineToPoint( path[ 2], CGPointMake( i, (2 * canvas.size.height) / 3 + (prev.state ? 0 : 255) / 3));
      }      
#endif      
   } 

#ifndef ORIGINAL   
   [context strokePath:path[ 0]
           strokeWidth:1.5
              hexColor:CGHexColorMakeWithColor( CGColorMakeWithGrayByte( 255))];
   [context strokePath:path[ 1]
           strokeWidth:1.5
              hexColor:CGHexColorMakeWithColor( CGColorMakeWithGrayByte( 0))];
   [context strokePath:path[ 2]
           strokeWidth:1.5
              hexColor:CGHexColorMakeWithColor( CGColorMakeWithGrayByte( 255))];
   CGPathDestroy( path[ 0]);
   CGPathDestroy( path[ 1]);
   CGPathDestroy( path[ 2]);
#endif
}


int   main( int argc, char *argv[])
{
   UIWindow        *window;
   UIApplication   *app;

   app = [UIApplication sharedInstance];
   {
      window = [UIWindow windowWithFrame:CGRectMake( 0.0, 0.0, 720.0, 400.0)];

      // background color will be seen when resizing
      [window setBackgroundColor:CGColorMakeWhite()];
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

