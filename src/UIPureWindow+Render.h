//
// Copyright (c) 2021 Nat!, Mulle kybernetiK
//
// prefer a local UIPureWindow over one in import.h
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
