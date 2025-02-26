//
// Copyright (c) 2021 Nat!, Mulle kybernetiK
//
#import "UIPureWindow+Render.h"

#import "import-private.h"

#import "UIPureWindow+DebugPrivate.h"

//#define LAYOUT_ANIMATIONS
//#define RENDER_DEBUG
//#define RENDER_DEBUG_VERBOSE
//#define RENDER_FRAMEINFO_DEBUG

// #define DRAW_FRAMEBUFFER_ID_RECT


//
//
// UIWindow frame chain
//
//    Creates a queue of CALayers from the UIView hierarchy. Layers are
//    setup so they draw themselves into the window coordinate space.
//
//                                                  UIWindow Delegate Views
//  .----------------------------------------.      .---.---.
//  | UIWindow willLayoutWithAbsoluteTime:   |      | B | C |
//  '----------------------------------------'      '---'---'
//                       |
//                       |
//                       v                          UIView hierarchy tree
//  .-----------------------------------------.           .---.
//  | UIView layout                           |           | A |-.
//  '-----------------------------------------'           '---' |
//                       |                                |     |
//                       |                          .---. |     |
//                       v                          | B |<'     v
//  .-----------------------------------------.     '---'     .---.
//  | UIView createRenderQueue:               |               | C |
//  '-----------------------------------------'               '---'
//                       |                                  |
//    From here on the   |                                  |
//    only hierarchy     |                                  |
//    is the order       |                                  |
//    of the layers in   |                                  v
//    the queue.         |
//                       v                          CALayer Render Queue
//  .------------------------------------------.    .---.---.---.---.---.----.
//  | CGAnimation animateObjects:absoluteTime: |    | A1| B1| B2| C1| C2| C3 |
//  '------------------------------------------'    '---'---'---'---'---'----'
//                       |
//                       |
//                       v
//  .-----------------------------------------.
//  | CGContext drawObjects:                  |
//  '-----------------------------------------'
//
// glitch hunt:
//
// a) we sometimes overflow the current frame
// b) we are doublebuffering
// c) the glitch occurs when there is already drawing on the screen
// d) the glitch looks like the buffer is cleared and then not swapped
//
// With the parameters, you should be able to render into a different
// context from the window context, with all the delegate calls intact.
//
// A window must not run two renderFrames concurrently!
// A view calling [(UIWindow *) [self window] context] could get the wrong context
// though. Maybe need a -renderContext ?
// Or should
//

@implementation UIPureWindow( Render)


- (void) _init
{
   _willRenderFrameCallback = UIWindowDefaultWillRenderFrameCallback;
   _rawFrameCallback        = UIWindowDefaultRawFrameCallback;
   _didRenderFrameCallback  = UIWindowDefaultDidRenderFrameCallback;
}



- (void) clearFrame:(struct CGFrameInfo *) info
    graphicsContext:(id <UIGraphicsContext>) context
{
   BOOL   doClearFramebufferColor;

   if( _willClearCallback && ! (*_willClearCallback)( self, context, info))
      return;

   MulleWindowProfileBegin();

   //
   // if window is Opaque, clear is superflous, except if this is the very
   // first frame of a new or corrupted framebuffer
   //
   doClearFramebufferColor = YES;
   if( [context isInitializedFramebuffer]) // now we can be smarter..
      doClearFramebufferColor = info->alpha == 1.0 && ! [self isOpaque];

   UIWindowRenderLogVerbose( "clearing framebuffer color=%btd", doClearFramebufferColor);

   // we have to clear some of the framebuffer for nanovg anyway
   // like the stencil bits
   if( doClearFramebufferColor)
      [context clearFramebufferWithHexColor:[self backgroundHexColor]];
   else
      [context clearFramebufferNoColor];

   MulleWindowProfileEnd();

   UIWindowRenderLogVerbose( "cleared framebuffer");
}




UIWindowDisplayBits
   UIWindowDefaultWillRenderFrameCallback( UIPureWindow *self,
                                           id <UIGraphicsContext> context,
                                           struct CGFrameInfo *info,
                                           UIWindowDisplayBits displayBits)
{
   UIWindowDisplayBitsLog( "%s returns (0x%tx)", __FUNCTION__, displayBits);
   return( displayBits);
}



//
// The default "rawFrameCallback" used in -renderWithFrameInfo:displayBits:
//
UIWindowDisplayBits
   UIWindowDefaultRawFrameCallback( UIPureWindow *self,
                                    id <UIGraphicsContext> context,
                                    struct CGFrameInfo *info,
                                    UIWindowDisplayBits displayBits)
{
   UIWindowDisplayBits   returnBits;

   UIWindowDisplayBitsLog( "%s enters (0x%tx)", __FUNCTION__, displayBits);

   [self->_frameDelegate window:self
                 willBeginFrame:info
                graphicsContext:context];

   [context beginRender:info];
   {
      [self clearFrame:info
       graphicsContext:context];

      [self->_frameDelegate window:self
                     willDrawFrame:info
                   graphicsContext:context];

      returnBits = self->_frameCallback 
                   ? (*self->_frameCallback)( self, context, info, displayBits)
                   : 0;

      [self->_frameDelegate window:self
                      didDrawFrame:info
                   graphicsContext:context];
   }
   [context endRender];

   [self->_frameDelegate window:self
                    didEndFrame:info
                graphicsContext:context];

   UIWindowDisplayBitsLog( "%s returns (0x%tx)", __FUNCTION__, returnBits);
   return( returnBits);
}


UIWindowDisplayBits
   UIWindowDefaultDidRenderFrameCallback( UIPureWindow *self,
                                          id <UIGraphicsContext> context,
                                          struct CGFrameInfo *info,
                                          UIWindowDisplayBits returnBits)
{
   UIWindowDisplayBitsLog( "%s returns (0x%tx)", __FUNCTION__, returnBits);
   return( returnBits);
}

@end
