//
//  UIPureWindow+OneFrame.h
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
#import "UIPureWindow.h"

#import "UIPureWindow+UIWindow.h"

//
// This is support for the "conventional" GLFW render/waitForEvents loop
// which has fallen out of favor for UIApplication
//
@interface UIPureWindow( OneFrame)

// returns ORed bits of handled events
- (NSUInteger) waitForEventsUntil:(mulle_absolutetime_t) timeout
                     returnsEarly:(BOOL) returnsEarly;

//
// eventHandling calls eventHandlingWithFrameRate: which will call
// processEvents:frameRate: which will call waitForEventsUntil:returnsEarly:
//
- (NSUInteger) processEvents:(mulle_absolutetime_t) now
                   frameRate:(mulle_relativetime_t) frameRate;

- (void) eventHandlingWithFrameRate:(mulle_relativetime_t) frameRate;

// returns NO, if windows should close
// does event handling after renderAndSwapOneFrame
- (BOOL) processOneFrame:(CGFloat) frameRate;
- (BOOL) processOneFrame;  // Use unsynced


// as processOneFrame
- (void) renderAndSwapOneFrame;

@end

