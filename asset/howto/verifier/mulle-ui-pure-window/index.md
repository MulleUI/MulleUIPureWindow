<!-- Keywords: screenshot, tracing, debug flags, render callbacks, property sync, event overflow, timers, invocation queue -->
# mulle-ui-pure-window

Use this topic when user code around `UIPureWindow` fails differently by backing store, render-hook order, OS-window sync, or window-owned timer/queue state. The useful local verifier surface is not just the public constructor API: startup debug flags live in `src/UIPureWindow.m`, screenshot and dump helpers in `src/UIPureWindow+Frame.h` and `src/UIPureWindow+UIEvent.m`, retained-refresh diagnostics in `src/UIPureWindow+DebugPrivate.h` and `src/UIPureWindow+ThreadRefresh.m`, and the repo already carries low-noise repro fixtures for rendering, events, event replay, and invocation queues.

## Understand first

```bash
mulle-sde api cat UIPureWindow
mulle-sde code search UIWindowDebuggingFlags
mulle-sde code search writeScreenshotToPNGUTF8String
mulle-sde code search syncOSWindowPropertyChangesIfNeeded
mulle-sde code search willDiscardOverflowEvent
mulle-sde code search invocationQueueForNameUTF8String
```

## Local references

- `README.md`
- `asset/dox/TOC.md`
- `src/UIPureWindow.h`
- `src/UIPureWindow+Frame.h`
- `src/UIPureWindow+UIGraphicsContext.h`
- `src/UIPureWindow+UIEvent.h`
- `src/UIPureWindow+NSTimer.h`
- `src/UIPureWindow+InvocationQueue.h`
- `src/UIPureWindow+OneFrame.h`
- `src/UIPureWindow+DebugPrivate.h`
- `src/UIPureWindow.m`
- `src/UIPureWindow+UIEvent.m`
- `src/UIPureWindow+UIWindow.m`
- `src/UIPureWindow+ThreadRefresh.m`
- `demo/src/main-backend-singlethread-retained.m`
- `demo/src/main-context-retained-keep.m`
- `test/20-window/window-rendering-test.m`
- `test/20-window/window-rendering-test.stdout`
- `test/20-window/window-events-test.m`
- `test/50-eventplayer/dummy-replay.m`
- `test/60-invocationqueue/queue.m`

## Main local subareas

| Scenario | Start here |
| --- | --- |
| Too much retained-thread noise | `UIWindowStyleRetainedOnMainThread`, `UIWindowStyleMaskNonRetained`, `src/UIPureWindow+OneFrame.h`, `demo/src/main-backend-singlethread-retained.m` |
| Need render-order proof or a one-frame repro | `willRenderFrameCallback`, `frameCallback`, `didRenderFrameCallback`, `didSwapBuffersCallback`, `test/20-window/window-rendering-test.m`, `test/20-window/window-rendering-test.stdout` |
| Need screenshots, live dumps, or trace output | `writeScreenshotToPNGUTF8String:`, `screenshotBitmapImage`, `dump`, `extractProfileQueue`, `F7`, `F8`, `F9`, `src/UIPureWindow+Frame.h`, `src/UIPureWindow+UIEvent.m` |
| Suspect stale OS-window state or dropped input | `syncOSWindowPropertyChangesIfNeeded`, `discardEventsMask`, `willDiscardOverflowEvent:`, `willDiscardPendingEvent:`, `UIWindowAbortOnEventOverflow`, `test/20-window/window-events-test.m`, `test/50-eventplayer/dummy-replay.m` |
| Suspect timer or invocation-queue wakeups | `addTimer:`, `invocationQueueForNameUTF8String:`, `pollInvocationQueues`, `src/UIPureWindow+NSTimer.h`, `src/UIPureWindow+InvocationQueue.h`, `test/60-invocationqueue/queue.m` |

## Local verification delta

- Set debug flags before process start. `src/UIPureWindow.m` samples `UIWindowDebuggingFlags` first and falls back to `UIDebuggingFlags` in `+initialize`, so late changes miss startup and early render setup.
- The most useful local flags from `src/UIPureWindow+DebugPrivate.h` are `0x04000000` (`UIWindowDebugTraceDrawCalls`), `0x08000000` (`UIWindowDebugDumpFrameToFile`), and `0x80000000` (`UIWindowAbortOnEventOverflow`). Use them through `mulle-sde -DUIWindowDebuggingFlags=... run` or the equivalent environment variable.
- For deterministic refresh repros, bound the run up front. `src/UIPureWindow.m` reads `UIPureWindowMaxRenderedFrames` and `UIPureWindowStartTraceAtFrame` during init, so `mulle-sde -DUIWindowDebuggingFlags=0x08000000 run --mulleui-frames 1 --mulleui-trace 0` gives a stable screenshot/trace window.
- Reduce the backing store before blaming app logic. `UIWindowStyleMaskDefault` is retained/threaded, `UIWindowStyleRetainedOnMainThread` exists for debugging only, and `UIWindowStyleMaskNonRetained` is the no-extra-thread baseline. `processOneFrame` is only for the non-retained or retained-on-main-thread probes.
- Separate redraw from presentation. `setNeedsDisplay...`, render callbacks, and `renderAndSwapOneFrame` create a frame; `setNeedsRefresh`, `refresh`, and `swapBuffers` only present an already rendered framebuffer.
- Treat `renderGraphicsContext` as owned state. `src/UIPureWindow.h` says it aborts if nil, and `src/UIPureWindow+UIGraphicsContext.h` warns against mixing visible and offscreen context activation across threads. For resource-prebuild probes, follow `demo/src/main-context-retained-keep.m` and keep an autorelease pool around `activateRenderGraphicsContext` / `deactivateRenderGraphicsContextKeepState:`.
- Sync thread-safe property writes before asserting on the OS window. `test/20-window/window-events-test.m` only sees the changed `discardEventsMask` after `syncOSWindowPropertyChangesIfNeeded`.
- Add the window to `UIApplication` before diagnosing timer failures. `src/UIPureWindow+NSTimer.h` explicitly says timers are invalid before registration.

## Verify and report

- Report the backing-store mode that reproduces the bug: `Volatile`, `RetainedOnMainThread`, or default `Retained`.
- Report the exact debug flags and frame-limit env used, and whether they were set before launch.
- For rendering bugs, report callback order against `test/20-window/window-rendering-test.stdout`.
- For screenshot or refresh bugs, say whether `F7`/`writeScreenshotToPNGUTF8String:` and `UIWindowDebugDumpFrameToFile` show the same pixels.
- For event/property bugs, say whether the stale state disappeared only after `syncOSWindowPropertyChangesIfNeeded`, and whether overflow hooks or `UIWindowAbortOnEventOverflow` triggered.
- For timer/queue bugs, say whether `[app addWindow:window]` happened before `addTimer:` and whether work was attached through the window's named invocation-queue registry.
