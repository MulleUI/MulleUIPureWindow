<!-- Keywords: quirks, debugging flags, uidebuggingflags, uiwindowdebuggingflags, screenshot, screenshot bitmap, png, retained mode, volatile mode, sync, autoreleasepool, event overflow, keepOSGraphicsContextActive -->
# Quirks

## Backing store and loop choice

- `UIWindowStyleMaskDefault` already includes retained mode. For a true no-retained repro, use `UIWindowStyleMaskNonRetained`.
- Do not trust the demo filename alone: `demo/src/main-backend-volatile.m` currently defines `STYLEMASK` as `UIWindowStyleMaskDefault`, so it is not the pure volatile baseline.
- `UIWindowBackingStoreRetainedOnMainThread` is marked in `src/UIPureWindow.h` as useful for debugging only.
- `processOneFrame` and `renderAndSwapOneFrame` assert against fully retained windows in `src/UIPureWindow+OneFrame.m`; they are not a probe for the default retained path.

## Rendering and graphics-context ownership

- `renderGraphicsContext` is only valid while rendering or after explicit activation; the public comment says it aborts if nil.
- `frameCallback` replaces the normal UIView/CAAnimation frame work for that frame path. Missing view behavior after setting it is expected.
- `src/UIPureWindow+UIGraphicsContext.h` explicitly forbids cross-thread context mixing: main thread should not activate the offscreen context once the render thread is running, and the render thread should not activate the visible window context.
- Keep an autorelease pool between activate/deactivate calls when creating temporary GPU resources; both the public header and render implementations rely on that.
- `keepOSGraphicsContextActive = YES` is only safe for one frequently rendered window on that thread. The public comment says multiple windows on one thread will otherwise starve each other visually.

## Events and property propagation

- A thread-safe property write is not the same as an immediate OS-window update. `test/20-window/window-events-test.m` only sees the changed `discardEventsMask` after `syncOSWindowPropertyChangesIfNeeded`.
- `willDiscardEvent:` can be reached from overflow and pending paths, and `src/UIPureWindow+UIEvent.h` warns that you may not be inside an autorelease pool there. Retain what you keep.
- Event overflow is part of the public design here. Override `willDiscardOverflowEvent:` or `willDiscardPendingEvent:` instead of assuming the FIFO never fills.
- `frame` is not a portable move/resize control on every backend; `src/UIPureWindow.h` calls out Wayland specifically.

## Timers, queues, and tracing

- `src/UIPureWindow+NSTimer.h` requires the window to be added to `UIApplication` before timers are added. Missing registration looks like a timer or wakeup bug.
- Prefer the window's named `MulleInvocationQueue` registry over ad-hoc queue storage so `pollInvocationQueues` and teardown remain coupled to the window lifecycle.
- `UIWindowDebuggingFlags` and `UIDebuggingFlags` are sampled in `+initialize` in `src/UIPureWindow.m`; set them before process start.
- `UIPureWindowStartTraceAtFrame` is not independent of `UIPureWindowMaxRenderedFrames`; the initializer adds the trace start to the max frame count.
- `test/50-eventplayer/eventplayer-dispatch.m` is intentionally obsolete. Use `test/50-eventplayer/dummy-replay.m` when you need a supported event-player reference.

## Screenshot bitmap capture flags

- `UIWindowDebugDumpFrameToFile` is the screenshot dump flag (`0x08000000`) in `src/UIPureWindow+DebugPrivate.h`.
- With that flag enabled, refresh code writes PNG sequences via `MulleUIWriteImageToPNGFileSequenceAsync( image, "refresh-image")` in `src/UIPureWindow+ThreadRefresh.m`.
- In debug builds, `F7` triggers `[window writeScreenshotToPNGUTF8String:"screenshot.png"]` via `acceptDebugKeyboardEvent:` in `src/UIPureWindow+UIEvent.m`.
- Use `mulle-sde run` helpers with env flags when reproducing screenshot issues, for example:

```bash
mulle-sde -DUIWindowDebuggingFlags=0x08000000 run --mulleui-frames 1 --mulleui-trace 0 demo
```

- `--mulleui-frames` maps to `UIPureWindowMaxRenderedFrames` and `--mulleui-trace` maps to `UIPureWindowStartTraceAtFrame`; both are useful to make screenshot repros deterministic.

## Framerate gate — `UIWindowFrameRateAsync` is completely silent

`UIWindowFrameRateAsync = INFINITY` is the default. When it is set, `displayFrameIfNeeded:` silently skips every presentation because `remainingFrameTime` is never zero. No error, no log, no crash — the window appears functional but nothing is ever shown.

If "nothing renders" but logic demonstrably runs, check `[window frameRate]` first. If it returns `INFINITY` and display changes are being driven outside a `CAAnimation`, that is the bug. See the `mulle-uios` debugger howto for the full diagnosis pattern.
