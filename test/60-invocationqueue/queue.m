#import <MulleUIPureWindow/MulleUIPureWindow.h>
#include "../fake-ui-application-glue.inc"


int   main( void)
{
   UIPureWindow           *window;
   MulleInvocationQueue   *queue;
   NSInvocation           *invocation;

   window = [UIPureWindow object];

   queue = [window invocationQueueForNameUTF8String:"whatevs"];
   if( ! queue)
   {
      queue = [MulleInvocationQueue invocationQueue];
      [window setInvocationQueue:queue
               forNameUTF8String:"whatevs"];
   }
   invocation = [NSInvocation object];
   [queue addInvocation:invocation];
   [window removeInvocationQueueForNameUTF8String:"whatevs"];

   return( 0);
}
