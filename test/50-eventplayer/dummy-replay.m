#define NVG_NO_DRAWING
#include <MulleUIPureWindow/MulleUIPureWindow.h>


@interface EventLogger : NSObject <UIEventReceiver>
{
   NSUInteger   _eventCount;
}
@end


@implementation EventLogger

- (void) receiveRetainedEvent:(UIEvent *) event
{
   _eventCount++;
   mulle_printf( "Event %lu: type=%ld\n", _eventCount, (long)[event eventType]);
   [event autorelease];
}

- (UIWindowEvent *) handleWindowEvent:(UIWindowEvent *) event
{
   return( event);
}

@end


int main( void)
{
   UINullOSWindow   *nullWindow;
   UIPureWindow     *window;
   UIEventPlayer    *player;
   EventLogger      *logger;
   BOOL              result;
   
   @autoreleasepool
   {
      mulle_printf( "=== UIEventPlayer with UINullOSWindow Test ===\n\n");
      
      // Create null OS window with NVG_NO_DRAWING
      nullWindow = [UINullOSWindow instance];
      mulle_printf( "Created UINullOSWindow\n");
      
      // Create UIPureWindow with null window
      window = [[UIPureWindow alloc] initWithOSWindow:nullWindow
                                    offscreenOSWindow:nil];
      
      if( ! window)
      {
         mulle_printf( "FAILED: Could not create UIPureWindow\n");
         return( 1);
      }
      mulle_printf( "Created UIPureWindow\n");
      
      // Create event logger and hook it
      logger = [EventLogger instance];
      [nullWindow setEventsReceiver:logger];
      mulle_printf( "Set event logger\n\n");
      
      // Create and load event player
      player = [UIEventPlayer instance];
      result = [player loadScriptFromUTF8String:
         "0.0 mouseMove x=100 y=100\n"
         "0.1 mouseDown button=Left x=100 y=100\n"
         "0.2 mouseUp button=Left x=100 y=100\n"
         "0.3 keyDown key=A mods=Shift\n"
         "0.4 keyUp key=A\n"];
      
      if( ! result)
      {
         mulle_printf( "FAILED: Could not load script\n");
         return( 1);
      }
      
      mulle_printf( "Loaded event script\n");
      mulle_printf( "Test flag setter/getter\n");
      
      [player setAbortOnInvalidWindowIndex:NO];
      if( ! [player abortOnInvalidWindowIndex])
         mulle_printf( "  abortOnInvalidWindowIndex: NO\n");
      
      [player setAbortOnInvalidWindowIndex:YES];
      if( [player abortOnInvalidWindowIndex])
         mulle_printf( "  abortOnInvalidWindowIndex: YES\n");
      
      mulle_printf( "\nSUCCESS: UIEventPlayer loaded with UINullOSWindow\n");
      
      [window release];  // UIPureWindow was created with alloc/init
   }
   
   return( 0);
}
