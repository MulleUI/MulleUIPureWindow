## 0.1.0




feature: support no-backend (Metal) OS windows and harden window teardown

* OS window backends can now honor or reject requested window styles via a new `effectiveWindowStyleMask` hook; a Metal `(GLFW_NO_API)` backend drops `UIWindowStyleRetained`, falling back to volatile backing store
* only share a GL context with the offscreen window when it actually has one, fixing `glfwCreateWindow` failing with "The specified window has no context"
* OS windows can supply their own graphics context class; no-backend windows get `CGNullContext` instead of a known-empty GPU context
* ``_doneInvocationQueues`` is now idempotent, guarding against double teardown; window shutdown uses it instead of `terminateAllInvocationQueues`
* retired the outdated ``ui_window_pointer_fifo_read_barrier`` alias in favor of ``_mulle__pointerfifo128_read``


### 0.0.1

Various small improvements
