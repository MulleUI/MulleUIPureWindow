//
// Copyright (c) 2020 Nat!, Mulle kybernetiK
//
// prefer a local UIWindow over one in import.h
#import "UIPureWindow.h"

// we want "import.h" always anyway
#import "import.h"


@class UIPasteboard;


@interface UIPureWindow( UIPasteboard)

- (UIPasteboard *) pasteboard;

@end

