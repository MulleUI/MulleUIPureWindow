# MulleUICore demos

MulleUICore introduces UIWindow, UIView and UIEvent.


#### autoresizingmask

The auto resizing mask in action. Small UIViews are placed into each corner
and stay there, when the window gets resized. They don't scale though

![](autoresizingmask.png)

[source](src/autoresizingmask.m)


#### candycrash

Pretty demo just being pretty.

![](candycrash.png)

[source](src/main-candycrash.m)


#### demo + demo-resizable

Just some super-basic drawing code. It's like the first demo to code
for MulleUICore:

![](demo.png)

[source](src/main-demo.m)
[source](src/main-demo-resizable.m)

#### fps + swapinterval

The fps demo allows the framerate to be set via an argument.

```
Usage: fps <refresh rate>

Refresh rate can be a floating point refresh rate in HZ or one of the
following words:
   synced   : synced to (primary) monitor refresh rate
   unsynced : runs as fast as possible
   async    : waits for events (like mouse movements)
```

![](fps-demo.png)

[source](src/main-fps.m)

Swapinterval looks like fps, but here you can give the swapinterval on the
commandline (0-3).

[source](src/main-swapinterval.m)



#### star

Another pretty demo just being pretty.

![](star.gif)

[source](src/main-starg.m)


#### glfw-sharing

Share a GPU texture between three windows.

![](glfw-sharing.png)

[source](src/main-glfw-sharing.m)


#### glfw-texture

Small GLUT demo transformed into a GLFWOSWindow with minimal effort.
A small texture is mapped onto a spinning rectangle.

![](glfw-texture.png)

[source](src/main-glfw-texture.m)



## Build

This is a [mulle-sde](https://mulle-sde.github.io/) project.

It comes with its own virtual environment and list of dependencies.
To fetch and build everything say:

```
mulle-sde craft --release
```
