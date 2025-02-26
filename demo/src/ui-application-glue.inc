@implementation UIPureWindow( UIApplicationGlue)

static struct
{
   Class   contextClass;
   Class   windowClass;
} Self;


+ (void) setOSWindowClass:(Class) cls
{
   assert( ! cls || [cls isSubclassOfClass:[GLFWOSWindow class]]);
   Self.windowClass = cls;
}


+ (void) setOSGraphicsContextClass:(Class) cls
{
   assert( ! cls || [cls isSubclassOfClass:[CGContext class]]);
   Self.contextClass = cls;
}


+ (Class) osWindowClass
{
   return( Self.windowClass ? Self.windowClass : [GLFWOSWindow class]);
}


+ (Class) osGraphicsContextClass
{
   return( Self.contextClass ? Self.contextClass : [CGContext class]);
}


+ (NSUInteger) osGraphicsHints
{
   NSUInteger   hints;

   hints = GLFW_DEFAULT_CONTEXT;
   switch( [CGContext nanoVGBackend])
   {
   case CG_GL3     : hints = GLFW_GL3_CONTEXT; break;
   case CG_GL3_2   : hints = GLFW_GL3_2_CONTEXT; break;
   case CG_GLES2   : hints = GLFW_GLES2_CONTEXT; break;
   case CG_GLES3   : hints = GLFW_GLES3_CONTEXT; break;
   case CG_GLES3_2 : hints = GLFW_GLES3_2_CONTEXT; break;
   }
   return( hints);
}

@end


@implementation CGContext( UIWindow)

- (void) setActive:(BOOL) flag
{
#ifdef ACTIVE_DEBUG
   if( (_activeThread != nil) != flag)
      MulleUILog( "<%@ %p> transitions from %s to %s",
                  self, self,
                  (_activeThread != nil) ? "YES": "NO",
                  flag ? "YES": "NO");
#endif
   _activeThread = flag ? [NSThread currentThread] : nil;
}


- (id) imageWithFramebuffer:(id) framebuffer
{
   CGFramebuffer   *layer = (CGFramebuffer *) framebuffer;
   CGImage         *image;

   assert( [framebuffer isKindOfClass:[CGFramebuffer class]]);

   image = [[[CGImage alloc] initWithSharedGPUTexture:[layer sharedGPUTexture]
                                           bitmapSize:[layer bitmapSize]
                                         textureFlags:[layer textureFlags]
                                              context:self] autorelease];
   return( image);
}


@end