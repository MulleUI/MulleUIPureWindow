//
//  UIPureWindow+Render.m
//  MulleUIPureWindow
//
//  Copyright (c) 2025 Nat! - Mulle kybernetiK.
//  All rights reserved.
//
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  Redistributions of source code must retain the above copyright notice, this
//  list of conditions and the following disclaimer.
//
//  Redistributions in binary form must reproduce the above copyright notice,
//  this list of conditions and the following disclaimer in the documentation
//  and/or other materials provided with the distribution.
//
//  Neither the name of Mulle kybernetiK nor the names of its contributors
//  may be used to endorse or promote products derived from this software
//  without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//
#import "UIPureWindow+Render.h"

#import "import-private.h"

#import "UIPureWindow+DebugPrivate.h"
#import "UIPureWindow+UIGraphicsContext.h"

//#define LAYOUT_ANIMATIONS
//#define RENDER_DEBUG
//#define RENDER_DEBUG_VERBOSE
//#define RENDER_FRAMEINFO_DEBUG

// #define DRAW_FRAMEBUFFER_ID_RECT


@interface UIPureWindow( Private)

- (void) _setPosition:(CGPoint) position;
//- (void) _setSize:(CGSize) size;
- (void) _setFrame:(CGRect) rect;
//- (void) _setFramebufferSize:(CGPixelSize) size;

@end


@implementation UIPureWindow( Render)

- (void) clearFrame:(struct CGFrameInfo *) info
    graphicsContext:(id <UIGraphicsContext>) context
{
   BOOL         doClearFramebufferColor;
   CGHexColor   backgroundHexColor;

   if( _willClearCallback && ! (*_willClearCallback)( self, context, info))
      return;

   MulleWindowProfileBegin();

   //
   // if window is Opaque, clear is superflous, except if this is the very
   // first frame of a new or corrupted framebuffer
   //
   doClearFramebufferColor = YES;
   if( ! [context needsFramebufferClear]) // now we can be smarter..
      doClearFramebufferColor = info->alpha == 1.0 && ! [self isOpaque];

   UIWindowRenderLogVerbose( "clearing framebuffer color=%btd", doClearFramebufferColor);

   // we have to clear some of the framebuffer for nanovg anyway
   // like the stencil bits
   if( doClearFramebufferColor)
   {
      backgroundHexColor = [self backgroundHexColor];
      [context clearFramebufferWithHexColor:backgroundHexColor];
   }
   else
      [context clearFramebufferNoColor];

   MulleWindowProfileEnd();

   UIWindowRenderLogVerbose( "cleared framebuffer");
}


UIWindowDisplayBits
   UIPureWindowDefaultWillRenderFrameCallback( UIPureWindow *self,
                                               id <UIGraphicsContext> context,
                                               struct CGFrameInfo *info,
                                               UIWindowDisplayBits displayBits)
{
   UIWindowDisplayBitsLog( "returns (%s)", UIWindowDisplayBitsUTF8String( displayBits));
   return( displayBits);
}


//
// The default "rawFrameCallback" used in -renderWithFrameInfo:displayBits:
//
UIWindowDisplayBits
   UIPureWindowDefaultRawFrameCallback( UIPureWindow *self,
                                        id <UIGraphicsContext> context,
                                        struct CGFrameInfo *info,
                                        UIWindowDisplayBits displayBits)
{
   UIWindowDisplayBits   returnBits;

   UIWindowDisplayBitsLog( "enters (%s)", UIWindowDisplayBitsUTF8String( displayBits));

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

      if( self->_frameDelegate)
      {
         [context reset];            
         [self->_frameDelegate window:self
                         didDrawFrame:info
                      graphicsContext:context];
      }
   }
   [context endRender];

   [self->_frameDelegate window:self
                    didEndFrame:info
                graphicsContext:context];

   UIWindowDisplayBitsLog( "returns (%s)", UIWindowDisplayBitsUTF8String( displayBits));
   return( returnBits);
}


UIWindowDisplayBits
   UIPureWindowDefaultDidRenderFrameCallback( UIPureWindow *self,
                                              id <UIGraphicsContext> context,
                                              struct CGFrameInfo *info,
                                              UIWindowDisplayBits returnBits)
{
   UIWindowDisplayBitsLog( "returns (%s)", UIWindowDisplayBitsUTF8String( returnBits));
   return( returnBits);
}


- (UIWindowDisplayBits) render_adjustFrameWithFrameInfo:(struct CGFrameInfo *) info
                                            displayBits:(UIWindowDisplayBits) displayBits

{
   // if the window size changed, we need to relayout
   if( ! CGSizeEqualToSize( info->window.frame.size, [self frame].size))
   {
      [self _setFrame:info->window.frame]; // don't trigger property change
      displayBits |= UIWindowDisplayNeedsLayout | UIWindowDisplayNeedsDisplay;
   }
   return( displayBits);
}


- (void) render_setupInitialFirstResponderIfNeeded
{
   if( ! _initialFirstResponderState)
   {
      _initialFirstResponderState = -1;
   }
}


- (void) render_debugNumberOfFrames:(NSUInteger) numberOfFrames
                            atPoint:(CGPoint) point
                           hexColor:(NSUInteger) color
                    graphicsDrawing:(id <UIGraphicsDrawing>) drawing
{
   mulle_buffer_do( buffer)
   {
      mulle_buffer_sprintf( buffer, "%tu", numberOfFrames);

      [drawing drawAtPoint:point
            textUTF8String:mulle_buffer_get_string( buffer)
        fontNameUTF8String:"mono"
                  fontSize:11.0
                  hexColor:color];
   }
}


- (void) render_debugDisplayBits:(NSUInteger) displayBits
                         atPoint:(CGPoint) point
                 graphicsDrawing:(id <UIGraphicsDrawing>) drawing
{
//   UIWindowDisplayNeedsDisplay    = 0x1,   // views push state to layers
//   UIWindowDisplayNeedsLayout     = 0x2,   // reposition views, cascades to NeedsDisplay
//   UIWindowDisplayNeedsStyling    = 0x4,   // restyle, cascades to NeedsLayout
//   UIWindowDisplayNeedsNextFrame  = 0x8,   // schedule next frame at animation rate
   CGFloat      distance     = 8.0;
   CGFloat      diameter     = 7.0;
   CGFloat      radius       = diameter / 2.0;
   CGPoint      center;
   CACircle     circle;
   uint32_t     backColor    = 0x202020FF;
   uint32_t     offColor     = 0x101010FF;
   uint32_t     onColor;
   uint32_t     greenColor   = 0x20D020FF;
   uint32_t     orangeColor  = 0xD04010FF;
   uint32_t     magentaColor = 0xD040F0FF;
   uint32_t     yellowColor  = 0xD0D020FF;
   uint32_t     blueColor    = 0x0087FFFF;
   NSUInteger   bit;

   center = CGPointMake( point.x + radius, point.y + radius);

   // only display the user events
   for( bit = UIWindowDisplayNeedsNextFrame; bit; bit >>= 1)
   {
      circle = CACircleMakeWithCenterAndRadius( center, radius);
      [drawing fillCircle:circle
                 hexColor:backColor];
      circle = CACircleMakeWithCenterAndRadius( center, radius - 0.75);
      switch( bit)
      {
      case UIWindowDisplayNeedsNextFrame  : onColor = orangeColor; break;
      case UIWindowDisplayNeedsStyling    : onColor = magentaColor; break;
      case UIWindowDisplayNeedsLayout     : onColor = greenColor; break;
      case UIWindowDisplayNeedsMouseEvent : onColor = yellowColor; break;
      default                             : onColor = blueColor; break;
      }
      [drawing fillCircle:circle
                 hexColor:(displayBits & bit) ? onColor : offColor];
      center.x += distance;
   }
}


- (void) render_drawDebug:(struct CGFrameInfo *) info
          graphicsDrawing:(id <UIGraphicsDrawing>) drawing
{
   MulleWindowProfileBegin();

   if( _debuggingFlags & UIWindowDebugFramebufferIdRect)
   {
      CGRect   rect;

      rect.origin = CGPointZero;
      rect.size   = info->window.frame.size;
      rect        = CGRectInset( rect, 24, 24);
      [drawing strokeRect:rect
              strokeWidth:4.0
                 hexColor:0xE04020FF];
   }

   if( self->_debuggingFlags & UIWindowDebugRenderFrameInfo)
   {
      [self render_debugNumberOfFrames:[_renderGraphicsContext numberOfFrames]
                                atPoint:CGPointMake( 4,
                                                     info->window.frame.size.height - 12)
                               hexColor:CGHexColorRed
                        graphicsDrawing:drawing];
   }

   if( self->_debuggingFlags & UIWindowDebugRenderDisplayBits)
   {
      UIWindowRenderLogVerbose( "display=0x%tx return=0x%tx", _debugDisplayBits, _debugReturnBits);

      [self render_debugDisplayBits:_debugDisplayBits
                            atPoint:CGPointMake( info->window.frame.size.width - 30,
                                                 info->window.frame.size.height - 21)
                   graphicsDrawing:drawing];

      [self render_debugDisplayBits:_debugReturnBits
                            atPoint:CGPointMake( info->window.frame.size.width - 30,
                                                 info->window.frame.size.height - 12)
                    graphicsDrawing:drawing];
   }

   MulleWindowProfileEnd();
}


//
// Assume the user does not move the mouse, but the view is animating the
// view may slide under the mouse pointer and we want highlighting to occur.
// We do this by sending a fake mouse event, which will trigger the tracking.
//
// Assume we are implementing "hover", now the fake mouse events destroys the
// hover as there is movement of the mouse implied. How to fix this ?
// We only want to hover if there is no physical movement of the mouse.
//
- (void) render_requestFakeMouseEventIfNeeded:(UIWindowDisplayBits) displayBits
{
   if( displayBits & UIWindowDisplayNeedsMouseEvent)
      UIWindowEventLogVerbose( nil, "requesting fake mouse motion event");

   _sendFakeMouseMotionEvent = (displayBits & UIWindowDisplayNeedsMouseEvent);
}


- (UIWindowDisplayBits) render_frameWithFrameInfo:(struct CGFrameInfo *) info
                                      displayBits:(UIWindowDisplayBits) displayBits
{
   UIWindowDisplayBits  returnBits;

   [self activateRenderGraphicsContext];

   @autoreleasepool // THIS IS IMPORTANT TO COLLECT CGLAYERS WHILE THE PROPER CONTEXT IS ALIVE
   {
      self->_debugDisplayBits = displayBits;

      UIWindowRenderLog( "%s %s", CGFrameInfoUTF8String( info),
                                  UIWindowDisplayBitsUTF8String( displayBits));

      // for demos (memo: thread safety question
      if( _styleMask & UIWindowStyleInputPolling)
         [_renderGraphicsContext setInputState:[self polledInputState]];

      else
         [_renderGraphicsContext setInputState:_eventInputState];

      // MEMO: we have not done beginRender here, this means that the proper
      //       framebuffer may not be bound to the context (yet)
      
      displayBits = (*self->_willRenderFrameCallback)( self, _renderGraphicsContext, info, displayBits);
      UIWindowDisplayBitsLogVerbose( "_willRenderFrameCallback augmented (0x%tx)", displayBits);

      // This is usually UIPureWindowDefaultRawFrameCallback (UIWindow+Render.m)
      // Here displayBits are now used to render the frame. The returned
      // value are the returnBits, which are different.
      returnBits = (*self->_rawFrameCallback)( self, _renderGraphicsContext, info, displayBits);
      UIWindowDisplayBitsLogVerbose( "_rawFrameCallback returned (0x%tx)", returnBits);

      returnBits = (*self->_didRenderFrameCallback)( self, _renderGraphicsContext, info, returnBits);
      UIWindowDisplayBitsLogVerbose( "_didRenderFrameCallback augmented (0x%tx)", returnBits);
   
      self->_debugReturnBits = returnBits;

      [self render_drawDebug:info
             graphicsDrawing:MULLE_OBJC_PROTOCOL_CAST( UIGraphicsDrawing, _renderGraphicsContext)];
   }
   [self deactivateRenderGraphicsContext];

   return( returnBits);
}


- (UIWindowDisplayBits) renderWithFrameInfo:(struct CGFrameInfo *) info
                                displayBits:(UIWindowDisplayBits) displayBits
{
   UIWindowDisplayBits   returnBits;


   [self render_setupInitialFirstResponderIfNeeded];

   _isRendering = YES;
   displayBits  = displayBits & 0xFFFF;  // only care for user bits here

   if( _renderedFrames >= _startTraceFrames && _startTraceFrames != (NSUInteger) -1L)
   {
      if( _renderedFrames == _startTraceFrames)
         MulleUILog( "Starting nvgTrace");
      info->debuggingFlags |= UIGraphicsContextTraceDrawCalls;
   }

   MulleWindowProfileBegin();
   {
      //
      // the display bits are possibly expanded by
      // render_adjustFrameWithFrameInfo:displayBits:
      //
      UIWindowDisplayBitsLogVerbose( "starts with (0x%tx)", displayBits);
      displayBits = [self render_adjustFrameWithFrameInfo:info
                                              displayBits:displayBits];
      UIWindowDisplayBitsLogVerbose( "render_adjustFrameWithFrameInfo:displayBits: augmented to (0x%tx)", displayBits);

      // takes displayBits, returns zero unless animations happened + some user
      // bits
      returnBits = [self render_frameWithFrameInfo:info
                                       displayBits:displayBits];
      UIWindowDisplayBitsLogVerbose( "render_frameWithFrameInfo:displayBits: returned (0x%tx)", returnBits);
   }
   MulleWindowProfileEnd();


   if( ++_renderedFrames == _maxRenderedFrames && _maxRenderedFrames)
   {
      MulleUILog( "Exiting on maxRenderedFrames %tu reached", _maxRenderedFrames);
      exit( 0);
   }
   _isRendering = NO;

   [self render_requestFakeMouseEventIfNeeded:returnBits];

   // only pass UIWindowDisplayNeedsNextFrame back, if needed
   returnBits = (returnBits & UIWindowDisplayDidAnimate) ? UIWindowDisplayNeedsNextFrame : 0;
   UIWindowDisplayBitsLogVerbose( "returns (0x%tx)", returnBits);
   return( returnBits);
}

@end
