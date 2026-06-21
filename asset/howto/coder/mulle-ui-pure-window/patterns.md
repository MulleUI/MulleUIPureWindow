<!-- Keywords: patterns, framecallback, retained mode, graphics context, oneframe, event sync, invocation queue -->
# Patterns

## Draw straight into the window framebuffer

`demo/src/main-backend.inc` is the local baseline for "no views, just draw":

```objc
static UIWindowDisplayBits   display( UIPureWindow *window,
                                      id <UIGraphicsContext> context,
                                      struct CGFrameInfo *info,
                                      UIWindowDisplayBits bits)
{
   drawStuff( (CGContext *) context, CGFrameInfoGetContentRect( info));
   return( 1);
}

window = [UIPureWindow windowWithFrame:CGRectMake( 0.0, 0.0, 400.0, 400.0)
                       titleUTF8String:"Demo"
                             styleMask:UIWindowStyleMaskDefault | UIWindowStyleNoView];
[window setFrameCallback:display];
```

- Return non-zero while you still want animation or repeated frames.
- Comparison: this is closer to a GLFW draw callback than to UIKit/AppKit view rendering.

## Prebuild GPU-backed assets with a live render context

`demo/src/main-context-retained-keep.m` uses a real render context before the app loop starts:

```objc
[window activateRenderGraphicsContext];
context = (CGContext *) [window renderGraphicsContext];

image = [CGFramebuffer framebufferWithBitmapSize:CGPixelSizeMakeWithSize( size)
                                 backgroundColor:CGColorMakeWhite()
                                    drawFunction:drawGradientCircle
                                        userInfo:&circleOne
                                  nameUTF8String:"circle"
                                         context:context];

[window deactivateRenderGraphicsContextKeepState:0];
```

- Do this when your framebuffer resources depend on the concrete graphics backend.
- Deactivate before the retained render thread starts using that context.

## Layer custom hooks around the default frame pipeline

`test/20-window/window-rendering-test.m` shows the supported hook order:

```objc
[window setFrameCallback:customFrameCallback];
[window setWillRenderFrameCallback:customWillRenderCallback];
[window setDidRenderFrameCallback:customDidRenderCallback];
[window setDidSwapBuffersCallback:swapBuffersCallback];

[window renderAndSwapOneFrame];
```

- Use `willRenderFrameCallback` / `didRenderFrameCallback` when you want to keep the stock render path but bracket it.
- Use `frameCallback` when you want to replace view-based drawing for the frame.

## Drive a simple loop with OneFrame

For the conventional single-window loop from `src/UIPureWindow+OneFrame.h`:

```objc
while( [window processOneFrame])
   ;
```

- Prefer this for volatile or demo-style code.
- Use `renderAndSwapOneFrame` when you need one render tick without the full event step.

## Propagate OS-facing property changes before asserting on the OS window

`test/20-window/window-events-test.m` demonstrates the local sync point:

```objc
[window setDiscardEventsMask:testMask];
[window syncOSWindowPropertyChangesIfNeeded];

if( [osWindow discardEventsMask] == testMask)
   printf( "OK\n");
```

- Setting the thread-safe property alone is not the same as forcing the OS window to reflect it right now.
- Use this pattern in focused tests and low-level property plumbing.

## Keep background work owned by the window

`test/60-invocationqueue/queue.m` uses named queues stored on the window:

```objc
queue = [window invocationQueueForNameUTF8String:"whatevs"];
if( ! queue)
{
   queue = [MulleInvocationQueue invocationQueue];
   [window setInvocationQueue:queue
            forNameUTF8String:"whatevs"];
}
[queue addInvocation:invocation];
```

- Reuse the window's queue registry instead of hanging ad-hoc worker state elsewhere.
- Pair this with the timer APIs in `src/UIPureWindow+NSTimer.h` when work must wake the window thread.
