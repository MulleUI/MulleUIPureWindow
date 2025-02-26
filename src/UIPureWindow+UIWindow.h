//
// Copyright (c) 2021 Nat!, Mulle kybernetiK
//

#import "UIPureWindow.h"



@interface UIPureWindow( UIWindow)  <UIWindow>

// this is called by UIApplication run, to force a draw set
// needsRefresh to YES
- (mulle_relativetime_t) displayFrameIfNeeded:(mulle_absolutetime_t) now;

@end

mulle_relativetime_t    UIWindowGetAnimationRate( UIPureWindow *self);
