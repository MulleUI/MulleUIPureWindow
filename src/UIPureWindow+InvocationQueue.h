//
// Copyright (c) 2022 Nat!, Mulle kybernetiK
//
// prefer a local UIWindow over one in import.h
#ifdef __has_include
# if __has_include( "UIPureWindow.h")
#  import "UIPureWindow.h"
# endif
#endif

// we want "import.h" always anyway
#import "import.h"


@interface UIPureWindow( InvocationQueue)

// queue will be created on demand, if it doesn't exist

- (MulleInvocationQueue *) invocationQueueForNameUTF8String:(char *) s;
- (void) setInvocationQueue:(MulleInvocationQueue *) queue
          forNameUTF8String:(char *) s;
- (void) removeInvocationQueueForNameUTF8String:(char *) s;

- (void) _initInvocationQueues;
- (void) _doneInvocationQueues;
- (void) pollInvocationQueues;
- (void) terminateAllInvocationQueues;

@end
