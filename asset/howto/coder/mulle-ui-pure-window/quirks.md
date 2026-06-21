<!-- Keywords: quirks, thread ownership, refresh, display bits, event overflow, timer, wayland, obsolete test -->
# Quirks

## Rendering and geometry

- In this library, a "frame" is the render/layout/animation span that fills the framebuffer; event handling time is explicitly separate in `src/UIPureWindow.h`.
- `UIWindowStyleMaskDefault` already includes retained mode. Use `UIWindowStyleMaskNonRetained` only when your draw path is fast enough that resize-time flicker is acceptable (`README.md`, `src/UIPureWindow.h`).
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

## Loop selection and test guidance

- `src/UIPureWindow+OneFrame.h` calls the OneFrame API a conventional GLFW-style loop that has "fallen out of favor" for `UIApplication`. Use it for simple/direct loops, not as a drop-in replacement for the normal app-managed retained path.
- `test/50-eventplayer/eventplayer-dispatch.m` says the test is obsolete and intentionally not the right replay pattern. Use `test/50-eventplayer/dummy-replay.m` as the live reference instead.

## Framerate gate — `UIWindowFrameRateAsync` is silent

`UIWindowFrameRateAsync = INFINITY` is the default. `displayFrameIfNeeded:` silently skips presentation whenever `remainingFrameTime > 0`, so with the default setting nothing is ever presented unless a display event fires. No error, no log, no assertion.

For continuous rendering (anything that drives display changes outside a `CAAnimation`) you must set a rate via `setFrameRate:`, `setFrameRateSynced`, or `setFrameRateHz:`. See the `mulle-uios` coder and debugger howtos for the full event-driven vs. continuous rendering decision and the `CAAnimation` lift behaviour.
