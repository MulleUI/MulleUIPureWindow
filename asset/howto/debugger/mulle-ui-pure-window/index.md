<!-- Keywords: debugger, uipurewindow, uidebuggingflags, uiwindowdebuggingflags, screenshot, screenshot bitmap, png, retained mode, volatile mode, render callbacks, event sync, graphics context, invocation queue -->
# mulle-ui-pure-window

Use this topic when a `UIPureWindow` failure depends on backing-store choice, render-hook order, OS-window sync, or window-owned thread helpers. The local debugger surface is mostly four families: backing store and frame callbacks in `src/UIPureWindow.h`, render/context ownership in `src/UIPureWindow+Render.h` and `src/UIPureWindow+UIGraphicsContext.h`, event/property propagation in `src/UIPureWindow+UIEvent.h`, and timer/queue helpers in `src/UIPureWindow+NSTimer.h` and `src/UIPureWindow+InvocationQueue.h`.

## Understand first

```bash
mulle-sde code search UIPureWindow
mulle-sde code search activateRenderGraphicsContext
mulle-sde code search syncOSWindowPropertyChangesIfNeeded
mulle-sde code search processOneFrame
mulle-sde api apropos MulleInvocationQueue
mulle-sde api cat MulleInvocationQueue
```

## Local references

- `README.md`
- `asset/dox/TOC.md`
- `src/UIPureWindow.h`
- `src/UIPureWindow+Render.h`
- `src/UIPureWindow+Frame.h`
- `src/UIPureWindow+UIEvent.h`
- `src/UIPureWindow+UIGraphicsContext.h`
- `src/UIPureWindow+NSTimer.h`
- `src/UIPureWindow+InvocationQueue.h`
- `src/UIPureWindow+Thread.h`
- `src/UIPureWindow+OneFrame.h`
- `demo/src/main-backend.inc`
- `demo/src/main-backend-singlethread-retained.m`
- `demo/src/main-context-mainretained-keep.m`
- `demo/src/main-context-retained-keep.m`
- `test/20-window/window-rendering-test.m`
- `test/20-window/window-rendering-test.stdout`
- `test/20-window/window-events-test.m`
- `test/50-eventplayer/dummy-replay.m`
- `test/50-eventplayer/eventplayer-dispatch.m`
- `test/60-invocationqueue/queue.m`

## Main local subareas

| Scenario | Start here |
| --- | --- |
| Reproduce a draw/swap bug without retained-thread noise | `UIWindowStyleMaskNonRetained`, `renderAndSwapOneFrame`, `test/20-window/window-rendering-test.m` |
| Keep retained buffering but stay on one thread | `UIWindowStyleRetainedOnMainThread`, `demo/src/main-backend-singlethread-retained.m`, `demo/src/main-context-mainretained-keep.m` |
| Debug retained-thread/context handoff | `activateRenderGraphicsContext`, `deactivateRenderGraphicsContextKeepState:`, `demo/src/main-context-retained-keep.m` |
| Debug property propagation or event masks | `discardEventsMask`, `syncOSWindowPropertyChangesIfNeeded`, `test/20-window/window-events-test.m` |
| Capture screenshot bitmaps / PNGs | `UIWindowDebuggingFlags=0x08000000` (`UIWindowDebugDumpFrameToFile`), `writeScreenshotToPNGUTF8String:`, `src/UIPureWindow+ThreadRefresh.m`, `src/UIPureWindow+UIEvent.m` |
| Debug queue/timer wakeups | `addTimer:`, `handleRetainedTimer:`, `invocationQueueForNameUTF8String:`, `pollInvocationQueues`, `test/60-invocationqueue/queue.m` |
| Debug scripted input | `test/50-eventplayer/dummy-replay.m`; keep `test/50-eventplayer/eventplayer-dispatch.m` as obsolete reference only |

## Local workflow delta

- Reduce the backing store first. `UIWindowBackingStoreRetained` is the normal default; `UIWindowBackingStoreRetainedOnMainThread` exists specifically as a debugging mode; `UIWindowBackingStoreVolatile` is the no-extra-thread baseline.
- Separate redraw bugs from present bugs. `setNeedsDisplayBit:` and `renderWithFrameInfo:displayBits:` drive new frame work; `setNeedsRefresh`, `refresh`, and `swapBuffers` only show an already rendered framebuffer.
- Treat `frameCallback` as a mode switch, not an extra hook. Once it is set, the header says UIView and CAAnimation handling are skipped for that frame path.
- Use `processOneFrame` or `renderAndSwapOneFrame` only for non-retained or main-thread-retained probes. `src/UIPureWindow+OneFrame.h` and `src/UIPureWindow+OneFrame.m` explicitly keep them out of the fully retained path.
- Missing `[app addWindow:window]` is a common false lead. Timers require it, and several tests add the window before asserting on render/event behavior.
- For screenshot-focused repros, prefer `mulle-sde -DUIWindowDebuggingFlags=0x08000000 run --mulleui-frames 1 --mulleui-trace 0 demo` to keep frame count and trace start deterministic.

## Verify and report

- Rendering bugs: report which callbacks fired and in what order; `test/20-window/window-rendering-test.stdout` is the local baseline.
- Event/property bugs: report whether `syncOSWindowPropertyChangesIfNeeded` changed the observed OS-window state.
- Thread/context bugs: report whether the bug reproduces in `Volatile`, `RetainedOnMainThread`, and `Retained`.
- Event-player bugs: say whether they still reproduce in `test/50-eventplayer/dummy-replay.m`; do not use `test/50-eventplayer/eventplayer-dispatch.m` as proof.
