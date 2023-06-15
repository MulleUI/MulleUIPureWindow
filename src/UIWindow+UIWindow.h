//
// Copyright (c) 2021 Nat!, Mulle kybernetiK
//

#import "UIWindow.h"


// fulfill UIWindow protocol
@interface UIWindow( UIWindow) <UIWindow>

// this is called by UIApplication run, to force a draw set
// needsRefresh to YES
- (mulle_relativetime_t) displayFrameIfNeeded:(mulle_absolutetime_t) now;

@end
