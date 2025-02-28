#include <MulleUIPureWindow/MulleUIPureWindow.h>
#include "../fake-ui-application-glue.inc"

int main(int argc, char *argv[])
{
   UIPureWindow   *window;
   FakeOSWindow   *osWindow;
   CGRect         frame;
   id<UIEventReceiver> receiver;

   frame = CGRectMake(100, 100, 800, 600);
   window = [UIPureWindow windowWithFrame:frame];

   osWindow = (FakeOSWindow *)[window OSWindow];

   // Test event receiver setup
   receiver = [osWindow eventsReceiver];
   printf("Event receiver setup: %s\n",
      (receiver == window) ? "OK" : "FAILED");

   // Test window events receiver setup
   receiver = [osWindow windowEventsReceiver];
   printf("Window events receiver setup: %s\n",
      (receiver == window) ? "OK" : "FAILED");

   // Test discardEventsMask
   NSUInteger testMask = 0x1234;
   [window setDiscardEventsMask:testMask];
   // After setting the mask but before testing it
   [window writeOSWindowPropertyChangesIfNeeded];

   printf("Discard events mask: %s\n",
      ([osWindow discardEventsMask] == testMask) ? "OK" : "FAILED");

   // this change won't appear until properly propagated
   [window setDiscardEventsMask:0x5678];
   // After setting the mask but before testing it
   // [window writeOSWindowPropertyChangesIfNeeded];

   printf("Discard events mask 2: %s\n",
      ([osWindow discardEventsMask] == testMask) ? "OK" : "FAILED");

   return 0;
}
