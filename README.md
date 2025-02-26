# 🛸 MulleUIPureWindow

#### 🛸 MulleUIPureWindow provides UIWindow and extends UIView functionality

![](mulle-tiny-logo-255x256.png)

See live on stream how it progresses: [https://www.twitch.tv/mulle_kybernetik_tv/](). Every Wednesday at 14:00-18:00 CEST.


![](demos/candycrash.png)

There is no actual "drawing" code in MulleUIPureWindow. Use "MulleGraphics" for
drawing. See "MulleUIControl" for widgets.


## Tracking Areas

Tracking areas are attached to their UIView. They are called upon by the
UIWindow on demand. 

So add your UIView to the trackingViews to a window, and then wait for getting 
called to provide the rectangles.
 

### You are here

![Overview](overview.dot.svg)


MulleUIPureWindow is based on [MulleObjCLockFoundation](//github.com/MulleFoundation/MulleObjCFoundation). 
Foundation datatype methods (e.g. `setDebugName:(NSString *)` are added by 
[MulleUIFoundation](//github.com/MulleUI/MulleUIFoundation).
