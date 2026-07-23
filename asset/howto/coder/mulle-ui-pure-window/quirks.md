<!-- Keywords: quirks, thread ownership, refresh, display bits, event overflow, timer, wayland, obsolete test, opaque, framestatistics, screenshot, profiling -->
# Quirks

## The `opaque` property bypasses framebuffer clearing

Setting `[window setOpaque:YES]` (from `src/UIPureWindow.h`) tells the render pipeline it can skip clearing the color buffer. If your drawing leaves transparent pixels they will show garbage. The header comment says the benefit is bandwidth savings. Use `opaque = NO` (the default behavior) unless every pixel is covered every frame.

## Rendering and geometry

- In this library, a "frame" is the render/layout/animation span that fills the framebuffer; event handling time is explicitly separate in `src/UIPureWindow.h`.
- `UIWindowStyleMaskDefault` already includes retained mode. Use `UIWindowStyleMaskNonRetained` only when your draw path is fast enough that resize-time flicker is acceptable (`README.md`, `src/UIPureWindow.h`).
- Volatile mode is still dual-buffered by default. Use `UIWindowStyleSingleBuffer` on top of `UIWindowBackingStoreVolatile` to get single-buffered behavior (`src/UIPureWindow.h`).
- `frameCallback` is not just an extra hook. The comment in `src/UIPureWindow.h` says it replaces UIView/CAAnimation handling for the frame; do not expect the normal view-driven path once you set it.
- `setNeedsDisplay...` and `setNeedsRefresh` are different levers. The first schedules new frame work; the second only asks for presentation of what was already rendered.
- `frame` is not a portable move/resize control on every backend. `src/UIPureWindow.h` notes that Wayland does not let you move or resize through that property.

## Graphics-context ownership

- `renderGraphicsContext` is only valid while rendering or while you have explicitly activated the render context. The public comment says it will abort if it is nil.
- Do not mix visible and offscreen context activation across threads. `src/UIPureWindow+UIGraphicsContext.h` says the main thread should not activate the offscreen context once the render thread runs, and the render thread should not activate the visible window context.
- Keep an autorelease pool between activate/deactivate calls when you create temporary GPU resources. That rule is spelled out in `src/UIPureWindow+UIGraphicsContext.h`.
- `keepOSGraphicsContextActive = YES` is only for a single frequently-rendered window on that thread. `src/UIPureWindow.h` warns that multiple windows on the same thread must not all keep their OS context active.

## Events, timers, and queues

- `test/20-window/window-events-test.m` shows that OS-window-visible state may lag behind a thread-safe setter until `syncOSWindowPropertyChangesIfNeeded` runs.
- `src/UIPureWindow+UIEvent.h` warns that discard hooks may run without an autorelease pool. If you need to keep an event, retain it yourself and return `NO`.
- Event and timer overflow are real public extension points here. Override `willDiscardOverflowEvent:`, `willDiscardPendingEvent:`, `willDiscardOverflowTimer:`, or `willDiscardPendingTimer:` instead of assuming the queues never fill.
- The timer API is window-owned, but `src/UIPureWindow+NSTimer.h` says the window must already be added to `UIApplication` before you add timers.
- Use the window's named `MulleInvocationQueue` registry rather than storing raw queues elsewhere; the public API includes `pollInvocationQueues` and `terminateAllInvocationQueues` because the window owns that lifecycle.

## Frame statistics are internal but affect timing

`struct UIWindowFrameStatistics` in `src/UIPureWindow.h` maintains a 4-entry rolling average of frame times used for adaptive timing. The init function sets a 0.0005s seed value. You cannot inspect or tune these from outside — they are window-thread-only ivars (`_windowThreadStatistics`, `_mainThreadStatistics`).

## Profiling queue is opt-in and unbounded

`extractProfileQueue` returns a `struct mulle_structqueue` of `MulleWindowProfileEntry` records (64 bytes each). The header comment warns it grows to ~13 MB/hour at 60 Hz with no cap. Only enable via a special window flag when actively debugging performance. Call `UIWindowDestroyProfileQueue()` to tear it down.

## Screenshot timing matters

`screenshotBitmap` and related methods in `src/UIPureWindow+Frame.h` capture the last rendered framebuffer. In retained mode the render thread owns the offscreen buffer, so the screenshot may lag one frame behind the display. Use only from the main thread and call after a `setNeedsRefresh` cycle completes.

## Loop selection and test guidance

- `src/UIPureWindow+OneFrame.h` calls the OneFrame API a conventional GLFW-style loop that has "fallen out of favor" for `UIApplication`. Use it for simple/direct loops, not as a drop-in replacement for the normal app-managed retained path.
- `test/50-eventplayer/eventplayer-dispatch.m` says the test is obsolete and intentionally not the right replay pattern. Use `test/50-eventplayer/dummy-replay.m` as the live reference instead.

## Framerate gate — `UIWindowFrameRateAsync` is silent

`UIWindowFrameRateAsync = INFINITY` is the default. `displayFrameIfNeeded:` silently skips presentation whenever `remainingFrameTime > 0`, so with the default setting nothing is ever presented unless a display event fires. No error, no log, no assertion.

For continuous rendering (anything that drives display changes outside a `CAAnimation`) you must set a rate via `setFrameRate:`, `setFrameRateSynced`, or `setFrameRateHz:`. See the `mulle-uios` coder and debugger howtos for the full event-driven vs. continuous rendering decision and the `CAAnimation` lift behaviour.

The demo files (`demo/src/main-backend.inc`, `demo/src/main-context-retained-keep.m`) consistently use `setFrameRateHz:` with a value like `60.0` or `0.5` to drive their loops.
