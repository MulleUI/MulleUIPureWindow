#define _GNU_SOURCE

#import "import-private.h"
#import "MulleUIPureWindow.h"

#include "ui-application-glue.inc"


//
// a simple demo that runs without a UIView 
// uses CGContext to draw the connected gamepads and monitors gamepad state
//
// drawGamepad: written by Cody mostly
//
static void    drawGamepad(struct NVGcontext *vg, CGRect canvas, id <UIGamepad> gamepad, CGColor bgColor)
{
   float width = canvas.size.width * 0.8;
   float height = canvas.size.height * 0.6;
   float x = (canvas.size.width - width) / 2 + canvas.origin.x;
   float y = (canvas.size.height - height) / 2 + canvas.origin.y;
   float fontSize;
   CGColor   color;
   CGFloat   gray;
   struct UIGamepadInfo   info;
   float     axes[ 3];

   if( ! gamepad)
   {
      gray  = CGColorGetGray( bgColor);
      gray  = gray < 0.5 ? gray + 0.1 : gray - 0.1;
      color = CGColorMakeWithGray(  gray);
   }
   else
      color = CGColorSuggestTextColor( bgColor);

   // Main body
   nvgBeginPath(vg);
   nvgRoundedRect(vg, x, y, width, height, canvas.size.width * 0.03);
   nvgStrokeColor(vg, color);
   nvgStrokeWidth(vg, canvas.size.width * 0.002);
   nvgStroke(vg);

   // Button states (1 for pressed, 0 for not pressed)
   int buttonA = 0, buttonB = 0, buttonC = 0, buttonD = 0;

   // Joystick positions (range from -1 to 1 for both x and y)
   float leftStickX = 0, leftStickY = 0;
   float rightStickX = 0, rightStickY = 0;

   // D-pad states (1 for pressed, 0 for not pressed)
   CADirection   direction = 0;

   // Add this after drawing all the gamepad elements
   if (gamepad)
   {
      const char *name = [gamepad nameUTF8String];
      fontSize = CGFloatClamp( canvas.size.width * 0.02, 5.0, 44.0);
      nvgFontSize(vg, fontSize);

      nvgTextAlign(vg, NVG_ALIGN_CENTER | NVG_ALIGN_MIDDLE);
      nvgTextColor(vg, color);
      nvgTextBackgroundColor( vg, bgColor);
      nvgText(vg, x + width * 0.5, y + height * 0.9, name, NULL);
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
   nvgBeginPath(vg);
   nvgCircle(vg, x + width * 0.25, y + height * 0.3, canvas.size.width * 0.02);
   nvgStroke(vg);
   nvgBeginPath(vg);
   nvgCircle(vg,
      x + width * 0.25 + leftStickX * canvas.size.width * 0.015,
      y + height * 0.3 + leftStickY * canvas.size.width * 0.015,
      canvas.size.width * 0.005);
   nvgFillColor(vg, color);
   nvgFill(vg);

   // Right analog stick
   nvgBeginPath(vg);
   nvgCircle(vg, x + width * 0.75, y + height * 0.7, canvas.size.width * 0.02);
   nvgStroke(vg);
   nvgBeginPath(vg);
   nvgCircle(vg,
      x + width * 0.75 + rightStickX * canvas.size.width * 0.015,
      y + height * 0.7 + rightStickY * canvas.size.width * 0.015,
      canvas.size.width * 0.005);
   nvgFillColor(vg, color);
   nvgFill(vg);

   // D-pad
   float dpadSize = canvas.size.width * 0.06;
   nvgBeginPath(vg);
   nvgRect(vg, x + width * 0.25 - dpadSize/2, y + height * 0.7 - dpadSize/2, dpadSize, dpadSize);
   nvgStroke(vg);
   if ( direction & CADirectionUp) {
      nvgBeginPath(vg);
      nvgRect(vg, x + width * 0.25 - dpadSize/4, y + height * 0.7 - dpadSize/2, dpadSize/2, dpadSize/4);
      nvgFillColor(vg, color);
      nvgFill(vg);
   }
   if (direction & CADirectionDown) {
      nvgBeginPath(vg);
      nvgRect(vg, x + width * 0.25 - dpadSize/4, y + height * 0.7 + dpadSize/4, dpadSize/2, dpadSize/4);
      nvgFillColor(vg, color);
      nvgFill(vg);
   }
   if (direction & CADirectionLeft) {
      nvgBeginPath(vg);
      nvgRect(vg, x + width * 0.25 - dpadSize/2, y + height * 0.7 - dpadSize/4, dpadSize/4, dpadSize/2);
      nvgFillColor(vg, color);
      nvgFill(vg);
   }
   if (direction & CADirectionRight) {
      nvgBeginPath(vg);
      nvgRect(vg, x + width * 0.25 + dpadSize/4, y + height * 0.7 - dpadSize/4, dpadSize/4, dpadSize/2);
      nvgFillColor(vg, color);
      nvgFill(vg);
   }

   // Buttons
   float buttonRadius = canvas.size.width * 0.015;
   float buttonX = x + width * 0.75;
   float buttonY = y + height * 0.3;
   float buttonSpacing = canvas.size.width * 0.03;

   nvgBeginPath(vg);

   // North (Y)
   nvgCircle(vg, buttonX, buttonY - buttonSpacing, buttonRadius);
   if ([gamepad stateOfGamepadButton:UIGamepadButtonY]) nvgFill(vg);
   else nvgStroke(vg);

   // East (B)
   nvgBeginPath(vg);
   nvgCircle(vg, buttonX + buttonSpacing, buttonY, buttonRadius);
   if ([gamepad stateOfGamepadButton:UIGamepadButtonB]) nvgFill(vg);
   else nvgStroke(vg);

   // West (X)
   nvgBeginPath(vg);
   nvgCircle(vg, buttonX - buttonSpacing, buttonY, buttonRadius);
   if ([gamepad stateOfGamepadButton:UIGamepadButtonX]) nvgFill(vg);
   else nvgStroke(vg);

   // South (A)
   nvgBeginPath(vg);
   nvgCircle(vg, buttonX, buttonY + buttonSpacing, buttonRadius);
   if ([gamepad stateOfGamepadButton:UIGamepadButtonA]) nvgFill(vg);
   else nvgStroke(vg);
}


//
// This demo uses a frameCallback to draw stuff into an UIWindow without
// UIViews. It's a little more convenient, than doing it with GLFWOSWindow
// but not much. 
//
static void   drawStuff( CGContext *context, CGRect canvas)
{
   struct NVGcontext   *vg;
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

   vg = CGContextGetNVGContext( context);
   [context useDefaultFont];

   for( i = 0; i < 3; i++)
   {
      color      = stripes[ i];
      stripeRect = CGRectMake( canvas.origin.x,
                               canvas.origin.y + i * canvas.size.height / 3.0,
                               canvas.size.width,
                               canvas.size.height / 3.0);
      // papaya stripe
      mvgFillRectWithColor( vg, stripeRect, color);
      gamepad = [UIApp gamepadAtIndex:i];
      drawGamepad( vg, stripeRect, gamepad, color);
   }
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
   UIPureWindow    *window;
   UIApplication   *app;

   app = [UIApplication sharedInstance];

   window = [UIPureWindow windowWithFrame:CGRectMake( 0.0, 0.0, 400.0, 400.0)
                          titleUTF8String:"Demo"
                                styleMask:(UIWindowStyleMaskDefault|UIWindowStyleNoView) & ~UIWindowStyleRetained];
   assert( window);

   [window setFrameCallback:display];
   [window setFrameRate:UIWindowFrameRateSynced];
   //[window setFrameDelegate:[MulleUIPerf object]];
   return( UIApplicationRunWindow( window));
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

