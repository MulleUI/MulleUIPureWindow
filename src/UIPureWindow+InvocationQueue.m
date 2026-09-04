//
//  UIPureWindow+InvocationQueue.m
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
#import "UIPureWindow+InvocationQueue.h"

#import "import-private.h"



@implementation UIPureWindow ( InvocationQueue)

static struct mulle_container_keyvaluecallback   callback;

+ (void) load 
{
   callback.keycallback   = mulle_container_keycallback_copied_cstring;
   callback.valuecallback = MulleObjCContainerRetainValueCallback;
}


- (void) _initInvocationQueues
{
   struct mulle_allocator   *allocator;
 
   allocator = MulleObjCInstanceGetAllocator( self);
   mulle_map_init( &_invocationQueueMap, 8, &callback, allocator);
}


- (void) _doneInvocationQueues
{
   if( ! _invocationQueueMap.callback)
      return;
   [self terminateAllInvocationQueues];
   mulle_map_done( &_invocationQueueMap);
   _invocationQueueMap.callback = NULL;
}


- (void) setInvocationQueue:(MulleInvocationQueue *) queue
          forNameUTF8String:(char *) s
{
   mulle_map_set( &_invocationQueueMap, s ? s : "default", queue);
}


- (MulleInvocationQueue *) invocationQueueForNameUTF8String:(char *) s
{
   MulleInvocationQueue   *queue;

   queue = mulle_map_get( &_invocationQueueMap, s ? s : "default");
   return( queue);
}


- (void) removeInvocationQueueForNameUTF8String:(char *) s
{
   mulle_map_remove( &_invocationQueueMap, s ? s : "default");
}


- (void) pollInvocationQueues
{
   char                   *key;
   MulleInvocationQueue   *queue;

   MulleWindowProfileBegin();

   mulle_map_for( &_invocationQueueMap, key, queue)
   {
      [queue poll]; // this will call delegate methods
   }

   MulleWindowProfileEnd();
}


- (void) terminateAllInvocationQueues
{
   char                   *key;
   MulleInvocationQueue   *queue;
   unsigned int           i, n;

   n = mulle_map_get_count( &_invocationQueueMap);
   mulle_alloca_do( queues, MulleInvocationQueue *, n)
   {
      i = 0; 
      mulle_map_for( &_invocationQueueMap, key, queue)
      {
         queues[ i++] = [queue retain];
      }

      mulle_map_reset( &_invocationQueueMap);

      for( i = 0; i < n; i++)
      {
         [queues[ i] terminate];
         [queues[ i] autorelease];
      }
   }
}

@end
