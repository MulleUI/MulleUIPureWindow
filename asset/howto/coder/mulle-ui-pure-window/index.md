<!-- Keywords: uipurewindow, framebuffer, render callback, retained mode, events, timer, invocation queue, oneframe, framedelgate, bitmap, screenshot -->
# mulle-ui-pure-window

Use this topic when you are changing exported `UIPureWindow` behavior or writing code directly against this library's window/framebuffer API. The local surface is broader than the README: creation and backing-store choice in `src/UIPureWindow.h`, render/context control in `src/UIPureWindow+Render.h` and `src/UIPureWindow+UIGraphicsContext.h`, event intake in `src/UIPureWindow+UIEvent.h`, and the window-owned timer/queue/thread helpers in `src/UIPureWindow+NSTimer.h`, `src/UIPureWindow+InvocationQueue.h`, `src/UIPureWindow+Thread.h`, and `src/UIPureWindow+OneFrame.h`.

## Understand first

```bash
mulle-sde code map
mulle-sde code search UIPureWindow
mulle-sde code grep "frameCallback"
mulle-sde code grep "activateRenderGraphicsContext"
mulle-sde code grep "syncOSWindowPropertyChangesIfNeeded"
mulle-sde api apropos InvocationQueue
```

## Local references

- `README.md`
- `asset/dox/TOC.md`
- `src/UIPureWindow.h`
- `src/UIPureWindow+Render.h`
- `src/UIPureWindow+Frame.h`
- `src/UIPureWindow+FrameInfo.h`
- `src/UIPureWindow+UIEvent.h`
- `src/UIPureWindow+UIGraphicsContext.h`
- `src/UIPureWindow+NSTimer.h`
- `src/UIPureWindow+InvocationQueue.h`
- `src/UIPureWindow+Thread.h`
- `src/UIPureWindow+ThreadRefresh.h`
- `src/UIPureWindow+OneFrame.h`
- `demo/src/main-backend.inc`
- `demo/src/main-backend-retained.m`
- `demo/src/main-backend-singlethread-retained.m`
- `demo/src/main-backend-volatile.m`
- `demo/src/main-context-retained-keep.m`
- `demo/src/main-context-retained-nokeep.m`
- `demo/src/main-context-nonretained-keep.m`
- `demo/src/main-context-nonretained-nokeep.m`
- `demo/src/main-context-mainretained-keep.m`
- `demo/src/main-context-mainretained-nokeep.m`
- `test/20-window/window-rendering-test.m`
- `test/20-window/window-events-test.m`
- `test/60-invocationqueue/queue.m`
- `test/50-eventplayer/dummy-replay.m`
- `test/10-leaks/window-frame-title-stylemask.m`

## Main local subareas

| Scenario | Start here |
| --- | --- |
| Direct drawing with no UIView tree | `frameCallback`, `UIWindowStyleNoView`, `renderAndSwapOneFrame`, `demo/src/main-backend.inc` |
| Retained/offscreen rendering and texture prebuild | `UIWindowStyleMaskDefault`, `activateRenderGraphicsContext`, `deactivateRenderGraphicsContextKeepState:`, `demo/src/main-context-retained-keep.m` |
| Render pipeline hooks around the default frame path | `willRenderFrameCallback`, `didRenderFrameCallback`, `didSwapBuffersCallback`, `src/UIPureWindow+Render.h`, `test/20-window/window-rendering-test.m` |
| Event intake and OS-window property sync | `discardEventsMask`, `sendWindowFramebufferGeometryEvent:`, `src/UIPureWindow+UIEvent.h`, `test/20-window/window-events-test.m` |
| Window-owned background work | `addTimer:`, `handleRetainedTimer:`, `invocationQueueForNameUTF8String:`, `pollInvocationQueues`, `src/UIPureWindow+NSTimer.h`, `src/UIPureWindow+InvocationQueue.h`, `test/60-invocationqueue/queue.m` |
| GLFW-style single-window loop | `processOneFrame`, `waitForEventsUntil:returnsEarly:`, `src/UIPureWindow+OneFrame.h` |
| Frame lifecycle delegate | `frameDelegate`, `UIWindowFrameDelegate` protocol methods (`willBeginFrame:`, `didEndFrame:`, `willDrawFrame:`, `didDrawFrame:`), `src/UIPureWindow.h` |
| Screenshot capture | `screenshotBitmap`, `screenshotBitmapImage`, `writeScreenshotToPNGUTF8String:`, `UIPureWindowBitmapImage` protocol, `src/UIPureWindow+Frame.h` |

## Local workflow delta

- Choose the backing-store story first. `UIWindowStyleMaskDefault` already means retained/offscreen/threaded rendering; `UIWindowStyleMaskNonRetained` is the simpler volatile path shown by `src/UIPureWindow.h` and `test/20-window/window-rendering-test.m`.
- Treat `frameCallback` as the fast path for framebuffer-only apps. `demo/src/main-backend.inc` uses it together with `UIWindowStyleNoView`; once you do that, you are not authoring a UIView hierarchy here.
- Keep redraw and present separate. `setNeedsDisplayBit:` / `setNeedsDisplayBits:` schedule layout-animation-redraw work, while `setNeedsRefresh` only asks for the last rendered framebuffer to be shown.
- Add the window to `UIApplication` before expecting timers or normal event delivery. `test/20-window/window-rendering-test.m` calls `[app addWindow:window]` before exercising rendering, and `src/UIPureWindow+NSTimer.h` says timers require that registration.
- Treat graphics contexts as thread-owned resources. `src/UIPureWindow+UIGraphicsContext.h` explicitly separates window/offscreen activation, and `demo/src/main-context-retained-keep.m` deactivates the render context after prebuilding a `CGImage` so the later render thread can take ownership cleanly.
- Set `keepOSGraphicsContextActive = NO` for multiple windows on the same thread (from `src/UIPureWindow.h` header comment). Only one window per thread may keep its OS context active.
- Use `UIWindowFrameDelegate` for frame lifecycle observation without overriding callbacks. The four delegate methods bracket the frame pipeline and receive the graphics context and frame info.

## Verify locally

- Render callback or swap changes: `test/20-window/window-rendering-test.m`
- Event routing or property propagation changes: `test/20-window/window-events-test.m`
- Invocation queue changes: `test/60-invocationqueue/queue.m`
- Constructor/title/style-mask leaks: `test/10-leaks/window-frame-title-stylemask.m`
- Render context activation patterns: `demo/src/main-context-retained-keep.m` and its variants
- Screenshot or BitmapImage changes: `src/UIPureWindow+Frame.h`
