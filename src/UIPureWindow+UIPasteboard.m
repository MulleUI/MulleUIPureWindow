//
// Copyright (c) 2020 Nat!, Mulle kybernetiK
//
#import "UIPureWindow+UIPasteboard.h"

#import "import-private.h"

#import "UIPureWindow+UIWindow.h"


@implementation UIPureWindow ( UIPasteboard)

- (UIPasteboard *) pasteboard
{
   return( [UIPasteboard pasteboardWithWindow:self]);
}

@end
