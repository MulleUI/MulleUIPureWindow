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

- (id <UIGraphicsContext>) activateWindowGraphicsContext
{
   Class        cls;
   NSUInteger   options;

   MulleWindowProfileBegin();

   assert( [NSThread mulleIsMainThread]);

   UIWindowSwapLog( "window context (%p)", _context);

   if( _keepOSGraphicsContextActive && _context)
   {
      [_context setActive:YES];
      MulleWindowProfileEnd();
      return( _context);
   }

   // this can actually be quite slow, especially the very first time

   [_OSWindow os_activateGraphicsContext];

   if( ! _context)
   {
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

      _context = [[cls alloc] initWithBackend:[_OSWindow backend]
                                      shareID:[_OSWindow shareID]
                                      options:options];
      if( ! _context)
      {
         MulleUILog( "Could not acquire a graphics context for backend: 0x%tx shareID: 0x%tx options: 0x%tx",
                           [_OSWindow backend],
                           [_OSWindow shareID],
                           options);
         abort();
      }
      [_context setOSWindow:_OSWindow];
      [_context mulleSetNameUTF8String:"Window"];

      UIWindowSwapLog( "context %#@ created for OSWindow %#@", _context, _OSWindow);
   }
   [_context setActive:YES];

   // TODO: mulleGainAccess ?
   MulleWindowProfileEnd();

   return( _context);
}


// TODO: memo, maybe the context triggers os_activateGraphicsContext ?
- (id <UIGraphicsContext>) activateOffscreenGraphicsContext
{
   Class        cls;
   NSUInteger   options;

   MulleWindowProfileBegin();

   assert( (! _windowThread && [NSThread mulleIsMainThread]) ||
           [NSThread currentThread] == _windowThread);

   // take renderlock here, relinquish later when wating for events
   // or when someone closes the window

   assert( _offscreenOSWindow);

   UIWindowSwapLog( "offscreen window context (%pp)", _offscreenContext);

   if( _keepOSGraphicsContextActive && _offscreenContext)
   {
      [_offscreenContext setActive:YES];
      MulleWindowProfileEnd();
      return( _offscreenContext);
   }

   [_offscreenOSWindow os_activateGraphicsContext];
   if( ! _offscreenContext)
   {
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

      _offscreenContext = [[cls alloc] initWithBackend:[_offscreenOSWindow backend]
                                               shareID:[_offscreenOSWindow shareID]
                                               options:options];
      if( ! _offscreenContext)
      {
         MulleUILog( "Could not acquire an offscren context for backend: 0x%tx shareID: 0x%tx options: 0x%tx",
                           [_offscreenOSWindow backend],
                           [_offscreenOSWindow shareID],
                           options);
         abort();
      }
      [_offscreenContext setRendersOffScreen:YES];
      [_offscreenContext setOSWindow:_offscreenOSWindow];
      [_offscreenContext mulleSetNameUTF8String:"Offscreen"];

      UIWindowSwapLog( "context %#@ created for offscreen OSWindow %#@",
                     _offscreenContext, _offscreenOSWindow);
   }
   [_offscreenContext setActive:YES];                        // just a flag

   UIWindowSwapLog( "offscreen context");

   MulleWindowProfileEnd();

   return( _offscreenContext);
}


// TODO: memo, maybe the context triggers os_activateGraphicsContext ?
- (void) deactivateGraphicsContext:(id <UIGraphicsContext>) context
{
   assert( context);

   [context setActive:NO];

   MulleWindowProfileBegin();

   if( context == _offscreenContext)
   {
      UIWindowSwapLog( "offscreen context");
      assert( (! _windowThread && [NSThread mulleIsMainThread]) ||
              [NSThread currentThread] == _windowThread);

      if( ! _keepOSGraphicsContextActive)
         [_offscreenOSWindow os_deactivateGraphicsContext];
   }
   else
   {
      UIWindowSwapLog( "window context");

      assert( [NSThread mulleIsMainThread]);

      if( ! _keepOSGraphicsContextActive)
         [_OSWindow os_deactivateGraphicsContext];
   }

   MulleWindowProfileEnd();
}


- (id <UIGraphicsContext>) renderGraphicsContext
{
   id <UIGraphicsContext>  context;

   // calling this method outside of rendering is an error
   context = _renderGraphicsContext;
   if( ! [context isActive])
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

//
// only call this during construction of the window, when its effectively
// single-threaded
//
- (void) setKeepOSGraphicsContextActive:(BOOL) flag
{
   NSThread   *activeThread;
   NSThread   *currentThread;

   assert( _windowThread == nil);

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
      activeThread  = [_context activeThread];
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
      activeThread  = [_offscreenContext activeThread];
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

   _keepOSGraphicsContextActive = flag;
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
