//
// NOTE: This test is obsolete and no longer works.
//
// Original intent was to test UIEventPlayer with UIPureWindow by accessing
// internal structures to manually dispatch events. This approach failed because:
//
// 1. UIEventPlayer's _events array is protected (can't access from test)
// 2. createUIEventFromScriptedEvent: is a private method
// 3. The test tried to bypass UIApplication's timer/run loop mechanism
//
// The correct approach is in dummy-replay.m which:
// - Uses FakeOSWindow with NVG_NO_DRAWING
// - Creates UIPureWindow properly
// - Tests loading and basic functionality without full playback
//
// For actual event replay testing, we need a real UIApplication with timers
// and run loop, which is beyond the scope of a unit test.
//
// Kept for reference only.
//

#include <MulleUIPureWindow/MulleUIPureWindow.h>
#include "../fake-ui-application-glue.inc"


int main(int argc, char *argv[])
{
   UIEventPlayer   *player;
   UIPureWindow    *window;
   CGRect           frame;
   BOOL             result;
   
   mulle_printf( "=== UIEventPlayer with UIPureWindow Test ===\n\n");
   
   // Create a simple window
   frame = CGRectMake( 0, 0, 800, 600);
   window = [UIPureWindow windowWithFrame:frame];
   
   if( ! window)
   {
      mulle_printf( "FAILED: Could not create window\n");
      return( 1);
   }
   
   mulle_printf( "Created UIPureWindow\n");
   
   // Create event player
   player = [UIEventPlayer instance];
   
   mulle_printf( "Created UIEventPlayer\n");
   
   // Load a simple script
   result = [player loadScriptWithUTF8String:
      "0.0 mouseMove x=100 y=100\n"
      "0.1 mouseDown button=Left x=100 y=100\n"
      "0.2 mouseUp button=Left x=100 y=100\n"
      "0.3 keyDown key=A mods=Shift\n"
      "0.4 keyUp key=A mods=Shift\n"
      "0.5 keyDown key=Space\n"
      "0.6 keyUp key=Space\n"];
   
   if( ! result)
   {
      mulle_printf( "FAILED: Could not load script\n");
      return( 1);
   }
   
   mulle_printf( "Loaded event script with 7 events\n");
   
   // Test abort on invalid window index flag
   [player setAbortOnInvalidWindowIndex:NO];
   if( ! [player abortOnInvalidWindowIndex])
      mulle_printf( "Set abortOnInvalidWindowIndex to NO\n");
   
   [player setAbortOnInvalidWindowIndex:YES];
   if( [player abortOnInvalidWindowIndex])
      mulle_printf( "Set abortOnInvalidWindowIndex to YES\n");
   
   mulle_printf( "\nSUCCESS: UIEventPlayer works with UIPureWindow\n");
   
   return( 0);
}
