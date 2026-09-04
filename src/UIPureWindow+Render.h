//
//  UIPureWindow+Render.h
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
#ifdef __has_include
# if __has_include( "UIPureWindow.h")
#  import "UIPureWindow.h"
# endif
#endif

// we want "import.h" always anyway
#import "import.h"


extern UIWindowDisplayBits
   UIPureWindowDefaultRawFrameCallback( UIPureWindow *self,
                                        id <UIGraphicsContext> context,
                                        struct CGFrameInfo *info,
                                        UIWindowDisplayBits displayBits);

extern UIWindowDisplayBits
   UIPureWindowDefaultWillRenderFrameCallback( UIPureWindow *self,
                                               id <UIGraphicsContext> context,
                                               struct CGFrameInfo *info,
                                               UIWindowDisplayBits displayBits);

extern UIWindowDisplayBits
   UIPureWindowDefaultDidRenderFrameCallback( UIPureWindow *self,
                                              id <UIGraphicsContext> context,
                                              struct CGFrameInfo *info,
                                              UIWindowDisplayBits returnBits);


@interface UIPureWindow( Render)

- (void) clearFrame:(struct CGFrameInfo *) info
    graphicsContext:(id <UIGraphicsContext>) context;
    
- (UIWindowDisplayBits) renderWithFrameInfo:(struct CGFrameInfo *) info
                                displayBits:(UIWindowDisplayBits) displayBits;

// supporting render methods called from renderWithFrameInfo:displayBits:
                                
- (UIWindowDisplayBits) render_frameWithFrameInfo:(struct CGFrameInfo *) info
                                      displayBits:(UIWindowDisplayBits) displayBits;
- (void) render_requestFakeMouseEventIfNeeded:(UIWindowDisplayBits) displayBits;
- (void) render_setupInitialFirstResponderIfNeeded;
- (UIWindowDisplayBits) render_adjustFrameWithFrameInfo:(struct CGFrameInfo *) info
                                            displayBits:(UIWindowDisplayBits) displayBits;

// used by UIWindow
- (void) render_drawDebug:(struct CGFrameInfo *) info
          graphicsDrawing:(id <UIGraphicsDrawing>) drawing;

- (void) render_debugNumberOfFrames:(NSUInteger) numberOfFrames
                            atPoint:(CGPoint) point
                           hexColor:(NSUInteger) color
                    graphicsDrawing:(id <UIGraphicsDrawing>) context;

- (void) render_debugDisplayBits:(NSUInteger) displayBits
                         atPoint:(CGPoint) point
                 graphicsDrawing:(id <UIGraphicsDrawing>) context;                             
//
// +--------------------------------------------+
// | render_setupInitialFirstResponderIfNeeded: |
// +--------------------------------------------+
//                      |
//                      v
//      +-----------------------------+
//      | render_adjustFrameIfNeeded: |
//      +-----------------------------+
//                      |
//                      v
//       +----------------------------+
//       | render_frameWithFrameInfo: |
//       |               displayBits: |
//       +----------------------------+
//                      |
//                      v
//   +---------------------------------------+
//   | render_requestFakeMouseEventIfNeeded: |
//   +---------------------------------------+
//

@end
