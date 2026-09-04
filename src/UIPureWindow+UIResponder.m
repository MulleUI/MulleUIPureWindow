//
//  UIPureWindow+UIResponder.m
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
#import "UIPureWindow+UIResponder.h"

#import "UIPureWindow+DebugPrivate.h"

//#define FIRST_RESPONDER_DEBUG

@implementation UIPureWindow( UIResponder)

- (id <UIResponder>) firstResponder
{
   return( _firstResponder);
}


- (BOOL) makeFirstResponder:(id <UIResponder>) responder
{
   BOOL   changed;

   // the original _firstResponder if present must have resigned before
   // we can set any non-nil value
   assert( ! responder || ! _firstResponder);

   changed = responder != _firstResponder;
   _firstResponder = responder;

   if( changed)
   {
      UIWindowEventLog( nil, "change firstResponder to %#@", responder);

      // MEMO: this is obscure, but for views that do mouse tracking, they
      //       need to have the window subscribed to mouse motion events.
      //       But mouse motion events subscription is only passed down to
      //       the OSWindow when a display occurs. If you do
      //       makeFirstResponder: in mouseDown: and no other changes, the
      //       request for mouseMotion events will not propagate.
      [self setNeedsDisplay];
   }
   return( YES);
}


- (id <UIResponder>) previousFirstResponder
{
   id <UIResponder>  responder;

   if( [_firstResponder respondsToSelector:_cmd])
   {
      responder = [(id) _firstResponder previousFirstResponder];
      if( responder)
         return( responder);
   }

   return( nil);
}


- (id <UIResponder>) nextFirstResponder
{
   id <UIResponder>  responder;

   if( [_firstResponder respondsToSelector:_cmd])
   {
      responder = [(id) _firstResponder nextFirstResponder];
      if( responder)
         return( responder);
   }
   return( nil);
}


- (UIInputEvent *) acceptKeyboardEvent:(UIKeyboardEvent *) event
{
   NSUInteger   key;
   NSUInteger   modifiers;

   UIWindowEventLog( event, "key: %ld scanCode: %ld modifiers: %ld",
                        (long) [event key], 
                        (long) [event scanCode],
                        (long) [event keyModifiers]);

   key       = [event key];
   modifiers = [event keyModifiers];
   switch( key)
   {
   case 258  : // TAB
      if( modifiers & UIEventKeyModifierShift)
         [[self previousFirstResponder] becomeFirstResponder];
      else
         [[self nextFirstResponder] becomeFirstResponder];
      return( nil);
   }
   return( event);
}

@end
