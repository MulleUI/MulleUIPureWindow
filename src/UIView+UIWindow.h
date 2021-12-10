//
// Copyright (c) 2021 Nat!, Mulle kybernetiK
//
// prefer a local UIView over one in import.h

// we want "import.h" always anyway
#import "import.h"


@class UIWindow;


@interface UIView( UIWindow)

- (UIWindow *) window;

@end
