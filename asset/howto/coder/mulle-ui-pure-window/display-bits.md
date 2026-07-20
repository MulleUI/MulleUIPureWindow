<!-- keywords: coder, mulle-ui-pure-window, display-bits, needsDisplay, needsNextFrame, frame-scheduling, atomic -->
# UIPureWindow Display Bits

UIPureWindow manages an atomic `_needsDisplay` bitfield that drives frame
scheduling. It does **not** know about UIViews, layout, styling, or render
queues — those are UIWindow concerns.

## Contract

- If `_needsDisplay != 0`, run the frame callback (`_frameCallback`).
- PureWindow passes `displayBits` through to the frame callback without
  interpreting them (except for scheduling).

## Bits that PureWindow cares about

| Bit | Value | PureWindow meaning |
| --- | --- | --- |
| `UIWindowDisplayNeedsNextFrame` | 0x8 | Use animation-rate timeout (don't sleep long) |
| Any bit != 0 | — | Wake up and run the frame callback |

All other bits (NeedsDisplay, NeedsLayout, NeedsStyling) are opaque to
PureWindow — they're passed through to the frame callback where UIWindow
interprets them.

## API

```objc
// Set a single bit (atomic OR)
[self setNeedsDisplayBit:UIWindowDisplayNeedsLayout];

// Set bits (atomic write, replaces all)
[self setNeedsDisplayBits:bits];

// "Something changed, need a frame" (writes NeedsDisplay = 0x1)
[self setNeedsDisplay];

// Atomically read and clear all bits
UIWindowDisplayBits bits = [self needsDisplayBitsClearIfSet];

// Read without clearing
UIWindowDisplayBits bits = [self needsDisplay];
```

## Frame Scheduling

PureWindow checks `NeedsNextFrame` to decide sleep duration:

- `NeedsNextFrame` only → sleep for animation rate, then wake
- Other bits set → wake immediately and render
- No bits → sleep indefinitely (wait for events)

## Resize Events

PureWindow sets `UIWindowDisplayNeedsLayout` on window/framebuffer resize
events. This is a notification to the frame callback ("geometry changed"),
not an action PureWindow takes itself.

```objc
// In UIPureWindow+UIEvent.m
case UIWindowEventTypeResize:
   [self setNeedsDisplayBits:UIWindowDisplayNeedsLayout];
   ...

// In UIPureWindow+Render.m (frame size change detection)
if( ! CGSizeEqualToSize( info->window.frame.size, [self frame].size))
   displayBits |= UIWindowDisplayNeedsLayout;
```

## Frame Loop (renderAndSwapOneFrame)

```objc
displayBits  = [self needsDisplayBitsClearIfSet];  // read + clear
displayBits |= UIWindowDisplayNeedsDisplay;        // ensure frame runs
[self renderWithFrameInfo:&frameInfo displayBits:displayBits];
[self swapBuffers];
[self setNeedsDisplayBits:returnBits];  // store back bits for next frame
```

The frame callback (set by UIWindow to `UIWindowDefaultRenderViews`) receives
`displayBits` and decides what work to do.
