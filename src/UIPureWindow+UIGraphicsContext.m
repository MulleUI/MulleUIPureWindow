//
// Copyright (c) 2021 Nat!, Mulle kybernetiK
//
#define _GNU_SOURCE

#import "UIPureWindow+UIGraphicsContext.h"

#import "import-private.h"

#import "UIPureWindow+DebugPrivate.h"


//#define FAKE_MOUSE_MOTION_CALLBACK_DEBUG
//#define SWAP_DEBUG
//#define RENDERINFO_DEBUG

@interface UIPureWindow( Private)

- (void) _setPosition:(CGPoint) position MULLE_OBJC_THREADSAFE_METHOD;
//- (void) _setSize:(CGSize) size;
- (void) _setFrame:(CGRect) rect MULLE_OBJC_THREADSAFE_METHOD;
//- (void) _setFramebufferSize:(CGPixelSize) size;

@end


@implementation UIPureWindow ( UIGraphicsContext)

- (void) _createGraphicsContext        MULLE_OBJC_THREADSAFE_METHOD
{
   Class        cls;
   NSUInteger   options;

   UIWindowSwapLog( "creating offscreen context");

   // must activate to get nanoVG context
   [_OSWindow os_activateGraphicsContext];

   cls = [[self class] osGraphicsContextClass];

   options = 0;
   if( _styleMask & UIWindowStyleAntiAlias)
   {
      if( [_OSWindow isAntiAliasing] == NO ||
          [cls supportsAntiAliasing] == NO)
         options |= UIGraphicsEdgeAntiAliasing;
      else
         options |= UIGraphicsUseMSAA;
   }

   options |= (_styleMask & UIWindowStyleForceEdgeAntiAlias) ? UIGraphicsEdgeAntiAliasing : 0;
   options |= (_styleMask & UIWindowStyleClearType)          ? UIGraphicsUseClearType : 0;
   options |= (_styleMask & UIWindowStyleStencilStrokes)     ? UIGraphicsUseStencilStrokes : 0;

   _context = [[cls alloc] initWithOSGraphicsContext:_OSWindow
                                      nameUTF8String:"Window"
                                             shareID:[_OSWindow shareID]
                                             options:options];      // have to do this manually, because the context is created manually

   if( ! _context)
   {
      MulleUILog( "Could not acquire a graphics context for backend: 0x%tx shareID: 0x%tx options: 0x%tx",
                        [_OSWindow backend],
                        [_OSWindow shareID],
                        options);
      abort();
   }
   [_context setState:UIGraphicsContextAssociated|UIGraphicsContextActive];
}


- (void) _createOffscreenGraphicsContext     MULLE_OBJC_THREADSAFE_METHOD
{
   Class        cls;
   NSUInteger   options;

   UIWindowSwapLog( "creating offscreen context");

   [_offscreenOSWindow os_activateGraphicsContext];

   cls     = [[self class] osGraphicsContextClass];
   options = 0;

   //
   // If the window supports antiAliasing, we might still have a CGContext
   // that is just running GLES2.0, so we then still have to force
   // EdgeAntiAliasing.
   //
   if( _offscreenStyleMask & UIWindowStyleAntiAlias)
   {
      if( [_OSWindow isAntiAliasing] == NO ||
          [cls supportsAntiAliasing] == NO)
         options |= UIGraphicsEdgeAntiAliasing;
      else
         options |= UIGraphicsUseMSAA;
   }

   options |= (_offscreenStyleMask & UIWindowStyleForceEdgeAntiAlias) ? UIGraphicsEdgeAntiAliasing : 0;
   options |= (_offscreenStyleMask & UIWindowStyleClearType)          ? UIGraphicsUseClearType : 0;
   options |= (_offscreenStyleMask & UIWindowStyleStencilStrokes)     ? UIGraphicsUseStencilStrokes : 0;

   _offscreenContext = [[cls alloc] initWithOSGraphicsContext:_offscreenOSWindow
                                               nameUTF8String:"Offscreen"
                                                      shareID:[_offscreenOSWindow shareID]
                                                      options:options];
   if( ! _offscreenContext)
   {
      MulleUILog( "Could not acquire an offscreen context for backend: 0x%tx shareID: 0x%tx options: 0x%tx",
                        [_offscreenOSWindow backend],
                        [_offscreenOSWindow shareID],
                        options);
      abort();
   }
   [_offscreenContext setRendersOffScreen:YES];
   [_offscreenContext setState:UIGraphicsContextAssociated|UIGraphicsContextActive];
}


// TODO: memo, maybe the context triggers os_activateGraphicsContext ?
- (id <UIGraphicsContext>) activateGraphicsContext:(id <UIGraphicsContext>) context
                                          OSWindow:(id <UIOSWindow>) OSWindow
{
   NSUInteger   state;

   MulleWindowProfileBegin();

   // take renderlock here, relinquish later when wating for events
   // or when someone closes the window

   assert( OSWindow);

   state = [context state];

   if( ! (state & UIGraphicsContextActive))
   {
      [OSWindow os_activateGraphicsContext];
      state |= UIGraphicsContextActive;
      UIWindowSwapLog( "context %#@ now activated", context);
   }

   if( ! (state & UIGraphicsContextAssociated))
   {
      [context mulleGainAccess];
      UIWindowSwapLog( "context %#@ now associated with thread %#@", context, [NSThread currentThread]);
      state |= UIGraphicsContextAssociated;
   }

   [context setState:state];

   MulleWindowProfileEnd();

   return( context);
}


- (id <UIGraphicsContext>) activateWindowGraphicsContext
{
   assert( ! _mulle_objc_object_is_finalized( self));

   if( ! _context)
   {
      [self _createGraphicsContext];
      UIWindowSwapLog( "context %#@ created for OSWindow %#@",
                     _context, _OSWindow);
      assert( _context);
      return( _context);
   }

   return( [self activateGraphicsContext:_context
                                OSWindow:_OSWindow]);

}


- (id <UIGraphicsContext>) activateOffscreenGraphicsContext
{
   assert( (! _windowThread && [NSThread mulleIsMainThread]) ||
           [NSThread currentThread] == _windowThread);
   assert( ! _mulle_objc_object_is_finalized( self));

   if( ! _offscreenContext)
   {
      [self _createOffscreenGraphicsContext];
      UIWindowSwapLog( "context %#@ created for OSWindow %#@",
                     _offscreenContext, _offscreenOSWindow);
      assert( _offscreenContext);
      return( _offscreenContext);
   }

   return( [self activateGraphicsContext:_offscreenContext
                                OSWindow:_offscreenOSWindow]);
}


- (void) _deactivateGraphicsContext:(id <UIGraphicsContext>) context
                           OSWindow:(id <UIOSWindow>) OSWindow
                          keepState:(UIGraphicsContextState) keepState  MULLE_OBJC_THREADSAFE_METHOD
{
   UIGraphicsContextState   state;

   MulleWindowProfileBegin();

   state = [context state];

   // we can only deactivate if we properly activated before
   assert( (state & UIGraphicsContextActive|UIGraphicsContextAssociated) == (UIGraphicsContextActive|UIGraphicsContextAssociated));

   if( ! (keepState & UIGraphicsContextActive))
   {
      assert( state & UIGraphicsContextActive);
      [OSWindow os_deactivateGraphicsContext];
      UIWindowSwapLog( "context %#@ no longer active", context);
      state &= ~UIGraphicsContextActive;
   }

   if( ! (keepState & UIGraphicsContextAssociated))
   {
      state &= ~UIGraphicsContextAssociated;
      [context setState:state];

      UIWindowSwapLog( "context %#@ no longer associated with %#@", context, [NSThread currentThread]);
      [context mulleRelinquishAccess];
      // can't access context no longer
   }
   else
      [context setState:state];

   MulleWindowProfileEnd();
}


- (void) deactivateGraphicsContext:(id <UIGraphicsContext>) context
                         keepState:(UIGraphicsContextState) keepState
{
   id <UIOSWindow>   OSWindow;

   // memo: we can ask the context about this now...
   OSWindow = (context == _context)
              ? _OSWindow
              : _offscreenOSWindow;
   [self _deactivateGraphicsContext:context
                           OSWindow:OSWindow
                          keepState:keepState];
}


- (void) deactivateGraphicsContext:(id <UIGraphicsContext>) context
{
   UIGraphicsContextState   keepState;
   id <UIOSWindow>          OSWindow;

   // memo: we can ask the context about this now...
   OSWindow  = (context == _context)
               ? _OSWindow
               : _offscreenOSWindow;
   keepState = [self keepOSGraphicsContextActive];
   [self _deactivateGraphicsContext:context
                           OSWindow:OSWindow
                          keepState:keepState];
}


- (id <UIGraphicsContext>) renderGraphicsContext
{
   id <UIGraphicsContext>  context;

   // calling this method outside of rendering is an error
   context = _renderGraphicsContext;
   if( ! ([context state] & UIGraphicsContextActive))
      abort();
   return( context);
}


- (void) activateRenderGraphicsContext
{
   assert( ! _renderGraphicsContext);

   _renderGraphicsContext = (_backingStore == UIWindowBackingStoreVolatile)
                            ? [self activateWindowGraphicsContext]
                            : [self activateOffscreenGraphicsContext];
}


- (void) deactivateRenderGraphicsContext
{
   assert( _renderGraphicsContext);
   [self deactivateGraphicsContext:_renderGraphicsContext];
   _renderGraphicsContext = nil;
}


- (void) deactivateRenderGraphicsContextKeepState:(UIGraphicsContextState) keepState
{
   assert( _renderGraphicsContext);
   [self deactivateGraphicsContext:_renderGraphicsContext
                         keepState:keepState];
   _renderGraphicsContext = nil;
}



//
// only call this during construction of the window, when its effectively
// single-threaded
//
- (void) setKeepOSGraphicsContextActive:(UIGraphicsContextState) state
{
   assert( [NSThread mulleIsMainThread]);
   assert( _windowThread == nil);

#if 0
   NSThread   *activeThread;
   NSThread   *currentThread;

   // ez exit to keep it ez
   if( flag == _keepOSGraphicsContextActive)
      return;

   currentThread = [NSThread currentThread];

   //
   // if window has a context already, the right thing will happen
   // on deactivation depending on the flag, otherwise we eliminate
   // the context and let it be rebuilt
   //
   if( _context)
   {
      activeThread = [_context activeThread];
      if( activeThread)
      {
         if( currentThread != activeThread)
            abort();
      }
      else
      {
         [_context autorelease];
         _context = nil;
      }
   }

   if( _offscreenContext)
   {
      activeThread = [_offscreenContext activeThread];
      if( activeThread)
      {
         if( currentThread != activeThread)
            abort();
      }
      else
      {
         [_offscreenContext autorelease];
         _offscreenContext = nil;
      }
   }
#endif
   _keepOSGraphicsContextActive = state;
}

@end

// use this for screenshots or something ?

#if 0
- (struct CGBitmap)
   lastRenderedFramebufferBitmapType:(CGFramebufferBitmapType) type
                            inFlight:(BOOL) inFlight
                           allocator:(struct mulle_allocator *) allocator
{
   id <UIGraphicsContext>     context;
   struct CGBitmap   fb;

   context = [self activateRenderGraphicsContext];
   {
     // need to blit from offscreen window to onscreen here
     // get image of offscreen framebuffer
     // can do this only, if we have rendered something last frame
     fb = [context lastRenderedFramebufferBitmapType:type
                                            inFlight:(BOOL) inFlight
                                           allocator:allocator];
   }
   [self deactivateGraphicsContext:context];

   return( fb);
}


- (struct CGBitmap) lastRenderedFramebuffer
{
   return( [self lastRenderedFramebufferBitmapType:CGFramebufferRGBABytes
                                          inFlight:NO
                                         allocator:NULL]);
}


- (struct CGBitmap)
   lastRenderedOffscreenFramebufferBitmapType:(CGFramebufferBitmapType) type
                                    allocator:(struct mulle_allocator *) allocator
{
   id <UIGraphicsContext>     context;
   struct CGBitmap   fb;

   context = [self activateRenderGraphicsContext];
   {
     // need to blit from offscreen window to onscreen here
     // get image of offscreen framebuffer
     // can do this only, if we have rendered something last frame
     fb = [context lastRenderedOffscreenFramebufferBitmapType:type
                                                    allocator:allocator];
   }
   [self deactivateGraphicsContext:context];

   return( fb);
}


- (struct CGBitmap) lastRenderedOffscreenFramebuffer
{
   return( [self lastRenderedOffscreenFramebufferBitmapType:CGFramebufferRGBABytes
                                                  allocator:NULL]);
}

#endif

#if 0

- (void) copyBackingStore
{
   struct CGBitmap   fb;
   struct CGFrameInfo           info;
   id <UIGraphicsContext>     context;

   fb = [self lastRenderedOffscreenFramebuffer];
   // if there has nothing been rendered yet, we decline the swap
   if( fb.bytes == 0)
      return;

   // mulle_rgba_dump( fb.bytes, fb.info.size.width, fb.info.size.height);

   //
   // draw the image we got from the framebuffer into the window
   //
   context = [self activateWindowGraphicsContext];
   {
      [self syncFrameAndFramebufferSizeWithOSWindow];
      [self getFrameInfo:&info];

      [context beginRender:&info];
      // [context clearFramebuffer]; // probably not needed
      [context drawBitmap:&fb];
      [context endRender];
   }
   [self deactivateGraphicsContext:context];

   CGFramebufferBitmapDone( &fb);
}
#endif
