#import <MulleUIWindow/MulleUIWindow.h>


int   main( void)
{
   UIWindow               *window;
   MulleInvocationQueue   *queue;

   window = [UIWindow object];
   [window _initInvocationQueues];

   queue = [window invocationQueueForNameUTF8String:"whatevs"];
   if( ! queue)
   {
      queue = [MulleInvocationQueue invocationQueue];
      [window setInvocationQueue:queue
               forNameUTF8String:"whatevs"];
   }
   [queue addInvocation:[NSInvocation object]];
   [window removeInvocationQueueForNameUTF8String:"whatevs"];

   return( 0);
}