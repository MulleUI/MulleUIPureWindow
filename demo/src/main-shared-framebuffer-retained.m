#define _GNU_SOURCE

#import "import-private.h"
#import "MulleUIPureWindow.h"

#include "ui-application-glue.inc"
#include "graphics-hints.inc"

//
// This is the retained (fully threaded) counterpart to
// main-shared-framebuffer.m. Each window here is created with
// UIWindowStyleRetained, which means each window gets its own private
// offscreen window/context AND its own render thread (see
// UIPureWindow.m -initWithFrame:titleUTF8String:styleMask:).
//
// The point of this demo is to reproduce (or rule out) the two-window
// cross-content-leak bug seen with the MulleUIWidget animate-style demo,
// but with the minimum amount of code: no widgets, no layout, no
// animation, just two threaded windows sharing one rendered framebuffer's
// texture between them, exactly like main-shared-framebuffer.m does
// single-threaded.
//
#ifndef STYLE_MASK
// retained (threaded) - confirmed ONE window missing when BOTH windows use this:
# define STYLE_MASK_RETAINED  ((UIWindowStyleMaskDefault | UIWindowStyleRetained | UIWindowStyleNoDelayedShow) & ~UIWindowStylePlanes)
// non-retained (volatile, single-threaded) - confirmed BOTH windows appear when BOTH windows use this:
# define STYLE_MASK_VOLATILE  ((UIWindowStyleMaskDefault | UIWindowStyleNoDelayedShow) & ~(UIWindowStylePlanes|UIWindowStyleRetained))
// retained-on-main-thread - confirmed BOTH windows appear when BOTH windows use this:
# define STYLE_MASK_RETAINED_MAIN  ((UIWindowStyleMaskDefault | UIWindowStyleRetainedOnMainThread | UIWindowStyleNoDelayedShow) & ~(UIWindowStylePlanes|UIWindowStyleRetained))
#endif


#define BLAU   CGColorMakeWithRGBA( 0.1, 0.1, 0.4, 1.0)
#define GRUEN  CGColorMakeWithRGBA( 0.1, 0.4, 0.1, 1.0)
#define WEISS  CGColorMakeWithRGBA( 1.0, 1.0, 1.0, 1.0)
#define GRAU   CGColorMakeWithRGBA( 0.85, 0.85, 0.85, 0.75)


static UIBitmapImage   *image;


static void  drawPrettyBackground( CGContext *context, CGRect canvas)
{
   CGFloat             radius;
   CGFloat             strokeWidth;
   CGFont              *font;

   strokeWidth = 20.0;
   radius      = (CGFloatMinimum( CGRectGetWidth( canvas),
                                  CGRectGetHeight( canvas)) - strokeWidth) / 2;
   CGContextBeginPath( context);
   {
      CGContextCircle( context, CACircleMakeWithCenterAndRadius( CGPointMake( CGRectGetMidX( canvas), CGRectGetMidY( canvas)), radius));
      CGContextStrokeColor( context, GRAU);
      CGContextStrokeWidth( context, strokeWidth);
   }
   CGContextStroke( context);

   font = [context fontWithNameUTF8String:"sans"];
   [context useFont:font];

   CGContextFontSize( context, strokeWidth * 8.0);
   CGContextCombinedTextAlignment( context, CGTextAlignCenter | CGTextAlignMiddle);
   CGContextTextColor( context, WEISS);
   CGContextTextBackgroundColor( context, BLAU);
   CGContextText( context, CGPointMake( CGRectGetMidX( canvas), CGRectGetMidY( canvas)), "1848", (size_t) -1);
}


//
// Same idea as main-shared-framebuffer.m's drawStuff: the FIRST window to
// draw creates a CGFramebuffer, renders the loaded image into it, and
// wraps it into a CGImage owned by ITS context. The SECOND window shares
// that CGImage's texture into ITS OWN context via -shareWithContext:.
// Both windows then draw their (own vs shared) CGImage in the corner.
//
// If windowless-of-thread texture sharing is broken, window B will show
// window A's content, wrong content, or nothing, exactly like the deform/
// monochrome bug.
//
static BOOL  drawStuff( CGContext *context, CGRect canvas)
{
   CGRect                     rect;
   static CGContext           *contexts[ 2];
   static CGFramebuffer       *framebuffer;
   static CGImage             *cgImage[ 2];
   struct CGDrawableOptions   options;
   struct CGFrameInfo         frameInfo;
   struct CGFrameInfo         oldFrameInfo;

   drawPrettyBackground( context, CGRectInset( canvas, 20, 20));

   options = CGDrawableOptionsMakeScaleToFit();
   if( ! cgImage[ 0])
   {
      framebuffer = [CGFramebuffer framebufferWithBitmapSize:CGPixelSizeMakeWithSize( [image size])
                                                textureFlags:0
                                                     context:context];

      frameInfo = CGFrameInfoFBMake( CGPixelSizeMakeWithSize( [image size]), 1.0, 1.0);
      oldFrameInfo = [context bindRender:&frameInfo];
      {
         [context bindFramebuffer:CGContextFramebufferMakeWithFramebuffer( framebuffer)];
         [context clearFramebufferWithColor:CGColorMakeWithRGBA( 0.2, 0.1, 0.3, 0.66)];
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

         cgImage[ 1]  = [[cgImage[ 0] shareWithContext:context
                                          textureFlags:[framebuffer textureFlags]] retain];
         contexts[ 1] = context;
      }

   if( contexts[ 0] == context)
   {
      if( cgImage[ 0])
         [cgImage[ 0] drawRect:CGRectMake( 32, 32, 128, 160)
                       options:&options
                       context:context];
   }
   else
   {
      if( cgImage[ 1])
         [cgImage[ 1] drawRect:CGRectMake( 32, 32, 128, 160)
                       options:&options
                       context:context];
   }

   return( YES);
}


static UIWindowDisplayBits   display( UIPureWindow *window,
                                      id <UIGraphicsContext> context,
                                      struct CGFrameInfo *frameInfo,
                                      UIWindowDisplayBits displayBits)
{
   // temporarily disabled: shared-texture/bird-image drawing, to isolate
   // whether the missing-window bug is related to the sharing code path
   // or is more fundamental. Re-enable by swapping the two lines below.
   // drawStuff( (CGContext *) context, CGFrameInfoGetContentRect( frameInfo));
   drawPrettyBackground( (CGContext *) context, CGFrameInfoGetContentRect( frameInfo));
   return( 1);
}


int   main( int argc, char *argv[])
{
   UIOSWindowGraphicsHints   hints;
   UIApplication   *app;
   UIPureWindow    *window[ 2];
   NSUInteger      i;
   NSUInteger      styleMask;

   if( ! UIConfigureGraphicsHints( argc, argv, &hints))
      return( 1);

   app   = [UIApplication sharedInstance];
   image = (UIBitmapImage *) [UIImage imageWithContentsOfFileUTF8String:"magpie-clipart-free-8.png"];
   assert( image);

   for( i = 0; i < 2; i++)
   {
      // test: window 0 gets a real render thread (STYLE_MASK_RETAINED),
      // window 1 stays on the main thread (STYLE_MASK_VOLATILE). If this
      // works (both windows appear), the bug needs TWO concurrent render
      // threads to trigger, one alone is fine alongside the main thread.
      // RESULT: only window 1 ("Demo2", volatile) appeared. Window 0
      // (retained/threaded) did NOT appear, even alone with no second
      // thread.
      // Then tested the reverse pairing (window 0 volatile, window 1
      // retained/threaded): BOTH windows appeared.
      // CONCLUSION SO FAR: it is always the LAST-created window that
      // reliably shows; a retained/threaded window created FIRST fails
      // to show once a second UIPureWindow (of any kind) is created
      // after it. Restoring both to retained/threaded here to trace
      // this precisely (test A).
      // styleMask = STYLE_MASK_RETAINED;

      // test B: window 0 retained (threaded), window 1
      // RETAINED_MAIN (retained state-machine, but NO second OS thread).
      // Goal: distinguish "window 0 just needs to be threaded" from
      // "the bug needs a second OS thread to exist at all", now that we
      // know from test A that plain object creation of a second
      // UIPureWindow (of any kind) is enough to break a threaded window 0.
      // RetainedOnMainThread was already confirmed to work fine when BOTH
      // windows use it, and to work fine when it's window 0 with window 1
      // retained/threaded -- this specific ordering/pairing has not been
      // tested yet.
      // styleMask = ! i ? STYLE_MASK_RETAINED : STYLE_MASK_RETAINED_MAIN;

      // Differential trace pair, run 1 (FAILING): window 0 retained
      // (threaded), window 1 volatile. Closest minimal-diff pair to the
      // WORKING run below (run 2), which just swaps which slot is
      // threaded. Goal: diff the two full traces to find where behavior
      // actually diverges, instead of further style-mask permutations.
      // styleMask = ! i ? STYLE_MASK_RETAINED : STYLE_MASK_VOLATILE;

      // Differential trace pair, run 2 (WORKING): window 0 volatile,
      // window 1 retained (threaded). Same two style masks as run 1,
      // just swapped slots -- minimal diff.
      // styleMask = ! i ? STYLE_MASK_RETAINED : STYLE_MASK_VOLATILE;

      // window 0 retained (threaded), window 1 volatile. This was the
      // original failing pairing (only one window showed). It is now
      // handled automatically by UIApplication downgrading the main-thread
      // screen context's keep-active state when more than one window exists
      // (see WAYLAND-RETAINED-WINDOW-PAIR-AGONY.md), so no per-window style
      // tweaking is needed anymore.
      styleMask = ! i ? STYLE_MASK_RETAINED : STYLE_MASK_VOLATILE;

      window[ i] = [UIPureWindow windowWithFrame:CGRectMake( 0.0 + 500 * i, 100.0, 400.0, 300.0)
                                  titleUTF8String:! i ? "Demo" : "Demo2"
                                        styleMask:styleMask];
      assert( window[ i]);

      [window[ i] setBackgroundHexColor:i ? CGHexColorBlue : CGHexColorGreen];
      [window[ i] setFrameCallback:display];

      [app addWindow:window[ i]];
   }

   return( [app runApp]);
}
