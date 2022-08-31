//
// Copyright (c) 2020 Nat!, Mulle kybernetiK
//
#import "UIPasteboard.h"

#import "import-private.h"

#import "UIWindow+UIPasteboard.h"



@implementation UIPasteboard

+ (instancetype) pasteboardWithWindow:(UIWindow *) window
{
   // let window dynamically create and manage a single instance
   return( [window pasteboard]);
}

- (char *) textUTF8String
{
   return( (char *) [_window pasteboardCString]);
}


- (void) setTextUTF8String:(char *) s
{
   [_window setPasteboardCString:s];
}

@end
