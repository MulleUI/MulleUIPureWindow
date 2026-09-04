//
//  UIPureWindow+UIEvent.h
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
#ifdef __has_include
# if __has_include( "UIPureWindow.h")
#  import "UIPureWindow.h"
# endif
#endif

#import "import.h"


//
// A window _receives_ and event the event is then _handled_ which means
// the views and other recipients are sought out, the recipient then
// accepts this event. If nil is returned the event was consumed, otherwise
// the event is forwarded to the next in line.
//

@interface UIPureWindow( UIEvent) < UIEventReceiver>

- (void) discardPendingEvents;

// hardcore event handling, must be called from MainThread
- (void) receiveRetainedEvent:(UIEvent *) event                MULLE_UI_MAIN_THREAD_ONLY;
- (UIWindowEvent *) handleWindowEvent:(UIWindowEvent *) event  MULLE_UI_MAIN_THREAD_ONLY;


//
// These event methods are special, you may not necessarily be in an 
// autoreleasepool as this time! Discard event with -retain and return NO if
// you must. Otherwise return YES and let UIPureWindow deal with it.
//
// The -willDiscardEvent: method must be thread safe as it can be called from 
// -willDiscardOverflowEvent: (Main thread) or -willDiscardPendingEvent:
// (Window thread). The default implementation just returns YES, indicating
// approval. 
//
- (BOOL) willDiscardEvent:(UIEvent *) event                    MULLE_OBJC_THREADSAFE_METHOD;
- (BOOL) willDiscardOverflowEvent:(UIEvent *) event            MULLE_UI_MAIN_THREAD_ONLY;
- (BOOL) willDiscardPendingEvent:(UIEvent *) event;

- (NSUInteger) executeEventQueue;

- (void) sendWindowFramebufferGeometryEvent:(struct CGWindowInfo *) info   MULLE_OBJC_THREADSAFE_METHOD;

- (BOOL) isMouseMotionEventsEnabled;
- (void) setMouseMotionEventsEnabled:(BOOL) flag;


@end


@interface UIPureWindow( OSInputEvents)

- (void) _charCallback:(unsigned int) codepoint;
- (void) _keyCallback:(int) key
             scancode:(int) scancode
               action:(int) action
            modifiers:(int) mods;

- (void) _mouseMotionCallback:(CGPoint) pos;
- (void) _mouseButtonCallback:(int) button
                       action:(int) action
                    modifiers:(int) mods;
- (void) _mouseScrollCallback:(CGPoint) offset;

@end
