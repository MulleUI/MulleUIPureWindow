//
// Copyright (c) 2021 Nat!, Mulle kybernetiK
//
// prefer a local UIView over one in import.h
// we want "import.h" always anyway
#import "import.h"


@interface UIView( Render)

//
// this is used for screeshots, not for the window renderer.
// The semantics are also quite different, as there are no animations
// and it doesn't layout.
//
- (void) renderInContext:(id <UIGraphicsContext>) context;

@end
