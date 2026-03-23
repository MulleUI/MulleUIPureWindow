//
// necessary glue code, as long as you don't have MulleUIOS
//
// forward declare backend method (defined in MulleCGNanoVG)
@interface CGContext( NanoVGBackend)
+ (CGContextNanoVGBackend) nanoVGBackend;
@end

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

- (id) imageWithFramebuffer:(id) framebuffer
             nameUTF8String:(char *) nameUTF8String
{
   CGFramebuffer   *layer = (CGFramebuffer *) framebuffer;
   CGImage         *image;

   assert( [framebuffer isKindOfClass:[CGFramebuffer class]]);

   image = [[[CGImage alloc] initWithSharedGPUTexture:[layer sharedGPUTexture]
                                           bitmapSize:[layer bitmapSize]
                                         textureFlags:[layer textureFlags]
                                       nameUTF8String:nameUTF8String
                                              context:self] autorelease];
   return( image);
}


@end