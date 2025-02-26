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
   UIWindowDefaultRawFrameCallback( UIPureWindow *self,
                                    id <UIGraphicsContext> context,
                                    struct CGFrameInfo *info,
                                    UIWindowDisplayBits displayBits);

extern UIWindowDisplayBits
   UIWindowDefaultWillRenderFrameCallback( UIPureWindow *self,
                                           id <UIGraphicsContext> context,
                                           struct CGFrameInfo *info,
                                           UIWindowDisplayBits displayBits);

extern UIWindowDisplayBits
   UIWindowDefaultDidRenderFrameCallback( UIPureWindow *self,
                                          id <UIGraphicsContext> context,
                                          struct CGFrameInfo *info,
                                          UIWindowDisplayBits returnBits);



@interface UIPureWindow( Render)


- (void) clearFrame:(struct CGFrameInfo *) info
    graphicsContext:(id <UIGraphicsContext>) context;

@end

