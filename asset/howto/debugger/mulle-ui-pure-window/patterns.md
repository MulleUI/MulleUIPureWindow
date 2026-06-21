<!-- Keywords: patterns, debugging, screenshot, screenshot bitmap, png, uidebuggingflags, uiwindowdebuggingflags, retained on main thread, max rendered frames, trace frames, sync, frame callback, invocation queue -->
# Patterns

## Collapse a retained bug to single-thread retained mode

`demo/src/main-context-mainretained-keep.m` and `demo/src/main-backend-singlethread-retained.m` are the local pattern for "same retained machinery, no second thread":

```objc
#define STYLE_MASK  ((UIWindowStyleMaskDefault | UIWindowStyleRetainedOnMainThread) \
                     & ~(UIWindowStylePlanes | UIWindowStyleRetained))

window = [UIPureWindow windowWithFrame:CGRectMake( 0.0, 0.0, 800.0, 600.0)
                       titleUTF8String:"Demo"
                             styleMask:STYLE_MASK];
```

- Use this before changing render logic. If the bug disappears here, debug thread/context handoff first.
- Comparison: this is the local "retained debug mode", not a production replacement.

## Stop after a small frame window or start tracing later

`src/UIPureWindow.m` reads these environment variables during startup:

```bash
export UIPureWindowMaxRenderedFrames=1
export UIPureWindowStartTraceAtFrame=20
```

- `UIPureWindowMaxRenderedFrames` exits after that many rendered frames.
- `UIPureWindowStartTraceAtFrame` is additive here: the implementation adds it to `UIPureWindowMaxRenderedFrames`, so `20` plus `5` stops around frame `25`, not `5`.

Equivalent `mulle-sde run` entrypoint:

```bash
mulle-sde run --mulleui-frames 1 --mulleui-trace 20 demo
```

## Dump screenshot bitmaps for refresh-path debugging

Use the screenshot dump flag from `src/UIPureWindow+DebugPrivate.h`:

```bash
mulle-sde -DUIWindowDebuggingFlags=0x08000000 run --mulleui-frames 1 demo
```

- `0x08000000` is `UIWindowDebugDumpFrameToFile`.
- Refresh rendering then writes `refresh-image*.png` via `MulleUIWriteImageToPNGFileSequenceAsync` in `src/UIPureWindow+ThreadRefresh.m`.

## Bracket the render pipeline before touching app code

`test/20-window/window-rendering-test.m` is the local minimal render probe:

```objc
[window setFrameCallback:customFrameCallback];
[window setWillRenderFrameCallback:customWillRenderCallback];
[window setDidRenderFrameCallback:customDidRenderCallback];
[window setDidSwapBuffersCallback:swapBuffersCallback];

[window renderAndSwapOneFrame];
```

- The expected order is in `test/20-window/window-rendering-test.stdout`: will-render, frame, did-render, then swap.
- Use `renderAndSwapOneFrame` when you want one render tick without mixing in full app-loop event handling.

## Force OS-window property propagation before asserting

`test/20-window/window-events-test.m` shows the local sync point:

```objc
[window setDiscardEventsMask:testMask];
[window syncOSWindowPropertyChangesIfNeeded];

if( [osWindow discardEventsMask] == testMask)
   printf( "OK\n");
```

- The thread-safe setter changes window state first; the OS window may still be stale until this sync runs.
- `processOneFrame` does this sync as part of its one-frame path; direct property tests must do it themselves.

## Prebuild graphics resources with an explicitly owned render context

`demo/src/main-context-retained-keep.m` is the local repro pattern for backend-dependent resource creation:

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

- Do this when the resource must be created against the real backend context.
- The demo immediately deactivates so the later retained render thread can re-own that context cleanly.

## Keep background work attached to the window

`test/60-invocationqueue/queue.m` shows the preferred queue lookup:

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

- Reuse the window's named registry so `pollInvocationQueues` and teardown stay visible to the window.
- Pair timer debugging with `[app addWindow:window]`; `src/UIPureWindow+NSTimer.h` says timers are not valid before registration.

## Use the live event-player fixture, not the obsolete one

`test/50-eventplayer/dummy-replay.m` is the current low-noise event-player probe:

```objc
nullWindow = [UINullOSWindow instance];
window = [[UIPureWindow alloc] initWithOSWindow:nullWindow
                              offscreenOSWindow:nil];

player = [UIEventPlayer instance];
[player loadScriptFromUTF8String:
   "0.0 mouseMove x=100 y=100\n"
   "0.1 mouseDown button=Left x=100 y=100\n"];
```

- This verifies script loading and window hookup without a full app run loop.
- Keep `test/50-eventplayer/eventplayer-dispatch.m` only as a note about what not to test anymore.
