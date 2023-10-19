//
// Copyright (c) 2022 Nat!, Mulle kybernetiK
//
#import "UIWindow+InvocationQueue.h"

#import "import-private.h"



@implementation UIWindow ( InvocationQueue)

static struct mulle_container_keyvaluecallback   callback;

+ (void) load 
{
   callback.keycallback   = mulle_container_keycallback_copied_cstring;
   callback.valuecallback = *MulleObjCContainerRetainValueCallback;
}


- (void) _initInvocationQueues
{
   struct mulle_allocator   *allocator;
 
   allocator = MulleObjCInstanceGetAllocator( self);
   mulle_map_init( &_invocationQueueMap, 8, &callback, allocator);
}


- (void) _doneInvocationQueues
{
   [self terminateAllInvocationQueues];
   mulle_map_done( &_invocationQueueMap);
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

   mulle_map_for( &_invocationQueueMap, key, queue)
   {
      [queue poll]; // this will call delegate methods
   }
}


- (void) terminateAllInvocationQueues
{
   char                   *key;
   MulleInvocationQueue   *queue;
   unsigned int           i, n;

   n = mulle_map_get_count( &_invocationQueueMap);
   mulle_flexarray_do( queues, MulleInvocationQueue *, 16, n)
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
