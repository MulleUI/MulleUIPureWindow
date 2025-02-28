#include <MulleUIPureWindow/MulleUIPureWindow.h>
#include "../fake-ui-application-glue.inc"

static int frameCallbackCount = 0;

static int customFrameCallback(UIPureWindow *window,
                              id <UIGraphicsContext> context,
                              struct CGFrameInfo *frameInfo,
                              UIWindowDisplayBits displayBits)
{
   frameCallbackCount++;
   printf("Frame callback called (#%d)\n", frameCallbackCount);
   return 1; // Indicate we're animating
}

static UIWindowDisplayBits customWillRenderCallback(UIPureWindow *window,
                                                 id <UIGraphicsContext> context,
                                                 struct CGFrameInfo *info,
                                                 UIWindowDisplayBits displayBits)
{
   printf("Will render frame callback called\n");
   return displayBits;
}

static UIWindowDisplayBits customDidRenderCallback(UIPureWindow *window,
                                               id <UIGraphicsContext> context,
                                               struct CGFrameInfo *info,
                                               UIWindowDisplayBits returnBits)
{
   printf("Did render frame callback called\n");
   return returnBits;
}

static void swapBuffersCallback(UIPureWindow *window, BOOL immediately)
{
   printf("Swap buffers callback called (immediately: %s)\n",
          immediately ? "YES" : "NO");
}

int main(int argc, char *argv[])
{
   UIPureWindow     *window;
   CGRect           frame;
   FakeOSWindow     *osWindow;
   id <UIGraphicsContext> context;
   NSUInteger       initialFrames;
   NSUInteger       framesAfterRender;
   FakeApplication *app;

   // Get the shared application instance
   app = [FakeApplication sharedInstance];

   frame = CGRectMake(100, 100, 800, 600);
   window = [UIPureWindow windowWithFrame:frame
                          titleUTF8String:"Window Rendering Test"
                                styleMask:UIWindowStyleMaskNonRetained];
   printf("UIPureWindow creation: %s\n", window ? "OK" : "FAILED");

   // Add the window to the application - this is crucial
   [app addWindow:window];

   // Test OSWindow creation
   osWindow = (FakeOSWindow *)[window OSWindow];
   printf("OSWindow creation: %s\n", osWindow ? "OK" : "FAILED");

   // Test graphics context activation - using pattern from main-frames.m
   context = [window activateWindowGraphicsContext];
   printf("Context creation: %s\n", context ? "OK" : "FAILED");

   // Set up custom render callbacks
   [window setFrameCallback:customFrameCallback];
   [window setWillRenderFrameCallback:customWillRenderCallback];
   [window setDidRenderFrameCallback:customDidRenderCallback];
   [window setDidSwapBuffersCallback:swapBuffersCallback];

   // Get initial frame count
   initialFrames = [context numberOfFrames];
   printf("Initial frame count: %lu\n", (unsigned long)initialFrames);

   // Render a frame using the OneFrame API
   [window renderAndSwapOneFrame];

   // Check if callbacks were invoked
   printf("Frame callback was %s\n",
          (frameCallbackCount > 0) ? "invoked" : "NOT invoked");

   // Check if frame count increased
   framesAfterRender = [context numberOfFrames];
   printf("Frame count after render: %lu\n", (unsigned long)framesAfterRender);
   printf("Frame rendering: %s\n",
      (framesAfterRender > initialFrames) ? "OK" : "FAILED");

   // Test processOneFrame
   BOOL shouldContinue = [window processOneFrame];
   printf("Process one frame result: %s\n",
          shouldContinue ? "continue" : "should close");

   // Test multiple render frames
   for (int i = 0; i < 3; i++) {
      [window renderAndSwapOneFrame];
   }
   printf("After multiple renders, frame count: %lu\n",
      (unsigned long)[context numberOfFrames]);
   printf("Frame callback count: %d\n", frameCallbackCount);

   // Deactivate the graphics context when done
   [window deactivateGraphicsContext:context];

   // No explicit release since windowWithFrame: returns an autoreleased object
   return 0;
}