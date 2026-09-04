#define _GNU_SOURCE

#import "import-private.h"
#import "MulleUIPureWindow.h"

#include "ui-application-glue.inc"
#include "graphics-hints.inc"


//
// a simple demo that runs without a UIView 
// uses CGContext to draw the connected gamepads and monitors gamepad state
//
// drawGamepad: written by Cody mostly
//
static void    drawGamepad( CGContext *context, CGRect canvas, id <UIGamepad> gamepad, CGColor bgColor)
{
   float                  width  = canvas.size.width * 0.8;
   float                  height = canvas.size.height * 0.6;
   float                  x      = (canvas.size.width - width) / 2 + canvas.origin.x;
   float                  y      = (canvas.size.height - height) / 2 + canvas.origin.y;
   float                  fontSize;
   CGColor                color;
   CGFloat                gray;
   struct UIGamepadInfo   info;
   float                  axes[ 3];

   if( ! gamepad)
   {
      gray  = CGColorGetGray( bgColor);
      gray  = gray < 0.5 ? gray + 0.1 : gray - 0.1;
      color = CGColorMakeWithGray(  gray);
   }
   else
      color = CGColorSuggestTextColor( bgColor);

   // Main body
   CGContextBeginPath( context);
   CGContextRoundedRect( context, CGRectMake( x, y, width, height), canvas.size.width * 0.03);
   CGContextStrokeColor( context, color);
   CGContextStrokeWidth( context, canvas.size.width * 0.002);
   CGContextStroke( context);

   // Button states (1 for pressed, 0 for not pressed)
   int buttonA = 0, buttonB = 0, buttonC = 0, buttonD = 0;

   // Joystick positions (range from -1 to 1 for both x and y)
   float leftStickX = 0, leftStickY = 0;
   float rightStickX = 0, rightStickY = 0;

   // D-pad states (1 for pressed, 0 for not pressed)
   CADirection   direction = 0;

   // Add this after drawing all the gamepad elements
   if( gamepad)
   {
      char *name = [gamepad nameUTF8String];
      fontSize   = CGFloatClamp( canvas.size.width * 0.02, 5.0, 44.0);
      CGContextFontSize( context, fontSize);

      CGContextCombinedTextAlignment( context, CGTextAlignCenter | CGTextAlignMiddle);
      CGContextTextColor( context, color);
      CGContextTextBackgroundColor( context, bgColor);
      CGContextText( context, CGPointMake( x + width * 0.5, y + height * 0.9), name, (size_t) -1);
   }

   direction = [gamepad direction];

   // now setup variables above with value from gamepad
   // clean axes, in case gamepad is nil
   if( [gamepad getAnalogStickWithIndex:0
                                   axes:axes])
   {
      leftStickX = axes[0];
      leftStickY = axes[1];
   }

   if( [gamepad getAnalogStickWithIndex:1
                               axes:axes])
   {
      rightStickX = axes[0];
      rightStickY = axes[1];
   }


   // Left analog stick
   CGContextBeginPath( context);
   CGContextCircle( context, CACircleMakeWithCenterAndRadius( CGPointMake( x + width * 0.25, y + height * 0.3), canvas.size.width * 0.02));
   CGContextStroke( context);
   CGContextBeginPath( context);
   CGContextCircle( context, CACircleMakeWithCenterAndRadius(
      CGPointMake( x + width * 0.25 + leftStickX * canvas.size.width * 0.015,
                   y + height * 0.3 + leftStickY * canvas.size.width * 0.015),
      canvas.size.width * 0.005));
   CGContextFillColor( context, color);
   CGContextFill( context);

   // Right analog stick
   CGContextBeginPath( context);
   CGContextCircle( context, CACircleMakeWithCenterAndRadius( CGPointMake( x + width * 0.75, y + height * 0.7), canvas.size.width * 0.02));
   CGContextStroke( context);
   CGContextBeginPath( context);
   CGContextCircle( context, CACircleMakeWithCenterAndRadius(
      CGPointMake(x + width * 0.75 + rightStickX * canvas.size.width * 0.015,
      y + height * 0.7 + rightStickY * canvas.size.width * 0.015),
      canvas.size.width * 0.005));
   CGContextFillColor( context, color);
   CGContextFill( context);

   // D-pad
   float dpadSize = canvas.size.width * 0.06;
   CGContextBeginPath( context);
   CGContextRect( context, CGRectMake(x + width * 0.25 - dpadSize/2, y + height * 0.7 - dpadSize/2, dpadSize, dpadSize));
   CGContextStroke( context);
   if ( direction & CADirectionUp)
   {
      CGContextBeginPath( context);
      CGContextRect( context, CGRectMake(x + width * 0.25 - dpadSize/4, y + height * 0.7 - dpadSize/2, dpadSize/2, dpadSize/4));
      CGContextFillColor( context, color);
      CGContextFill( context);
   }
   if (direction & CADirectionDown)
   {
      CGContextBeginPath( context);
      CGContextRect( context, CGRectMake(x + width * 0.25 - dpadSize/4, y + height * 0.7 + dpadSize/4, dpadSize/2, dpadSize/4));
      CGContextFillColor( context, color);
      CGContextFill( context);
   }
   if (direction & CADirectionLeft)
   {
      CGContextBeginPath( context);
      CGContextRect( context, CGRectMake(x + width * 0.25 - dpadSize/2, y + height * 0.7 - dpadSize/4, dpadSize/4, dpadSize/2));
      CGContextFillColor( context, color);
      CGContextFill( context);
   }
   if (direction & CADirectionRight)
   {
      CGContextBeginPath( context);
      CGContextRect( context, CGRectMake(x + width * 0.25 + dpadSize/4, y + height * 0.7 - dpadSize/4, dpadSize/4, dpadSize/2));
      CGContextFillColor( context, color);
      CGContextFill( context);
   }

   // Buttons
   float buttonRadius = canvas.size.width * 0.015;
   float buttonX = x + width * 0.75;
   float buttonY = y + height * 0.3;
   float buttonSpacing = canvas.size.width * 0.03;

   CGContextBeginPath( context);

   // North (Y)
   CGContextCircle( context, CACircleMakeWithCenterAndRadius( CGPointMake(buttonX, buttonY - buttonSpacing), buttonRadius));
   if ([gamepad stateOfGamepadButton:UIGamepadButtonY]) CGContextFill( context);
   else CGContextStroke( context);

   // East (B)
   CGContextBeginPath( context);
   CGContextCircle( context, CACircleMakeWithCenterAndRadius( CGPointMake(buttonX + buttonSpacing, buttonY), buttonRadius));
   if ([gamepad stateOfGamepadButton:UIGamepadButtonB])
      CGContextFill( context);
   else
      CGContextStroke( context);

   // West (X)
   CGContextBeginPath( context);
   CGContextCircle( context, CACircleMakeWithCenterAndRadius( CGPointMake(buttonX - buttonSpacing, buttonY), buttonRadius));
   if ([gamepad stateOfGamepadButton:UIGamepadButtonX])
      CGContextFill( context);
   else
      CGContextStroke( context);

   // South (A)
   CGContextBeginPath( context);
   CGContextCircle( context, CACircleMakeWithCenterAndRadius( CGPointMake(buttonX, buttonY + buttonSpacing), buttonRadius));
   if ([gamepad stateOfGamepadButton:UIGamepadButtonA])
      CGContextFill( context);
   else
      CGContextStroke( context);
}


//
// This demo uses a frameCallback to draw stuff into an UIWindow without
// UIViews. It's a little more convenient, than doing it with GLFWOSWindow
// but not much. 
//
static void   drawStuff( CGContext *context, CGRect canvas)
{
   CGRect              stripeRect;
   CGColor             color;
   id <UIGamepad>      gamepad;
   NSUInteger          i;
   CGFont              *font;
   static CGColor      stripes[ 3] =
   {
      CGColorDataPapaya,
      CGColorDataWhite,
      CGColorDataDodgerBlue
   };

   [context useDefaultFont];

   for( i = 0; i < 3; i++)
   {
      color      = stripes[ i];
      stripeRect = CGRectMake( canvas.origin.x,
                               canvas.origin.y + i * canvas.size.height / 3.0,
                               canvas.size.width,
                               canvas.size.height / 3.0);
      // papaya stripe
      CGContextFillRectWithColor( context, stripeRect, color);
      gamepad = [UIApp gamepadAtIndex:i];
      drawGamepad( context, stripeRect, gamepad, color);
   }
}


static UIWindowDisplayBits   display( UIPureWindow *window,
                                      id <UIGraphicsContext> context,
                                      struct CGFrameInfo *frameInfo,
                                      UIWindowDisplayBits displayBits)
{
   drawStuff( ( CGContext *) context, CGFrameInfoGetContentRect( frameInfo));
   return( 1);
}


int   main( int argc, char *argv[])
{
   UIOSWindowGraphicsHints   hints;
   UIPureWindow    *window;
   UIApplication   *app;

   if( ! UIConfigureGraphicsHints( argc, argv, &hints))
      return( 1);
   app = [UIApplication sharedInstance];

   window = [UIPureWindow windowWithFrame:CGRectMake( 0.0, 0.0, 400.0, 400.0)
                          titleUTF8String:"Demo"
                                styleMask:(UIWindowStyleMaskDefault|UIWindowStyleNoView) & ~UIWindowStyleRetained];
   assert( window);

   [window setFrameCallback:display];
   [window setFrameRate:UIWindowFrameRateSynced];
   //[window setFrameDelegate:[MulleUIPerf instance]];
   return( [app runWindow:window]);
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
