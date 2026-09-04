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
   Class                    contextClass;
   Class                    windowClass;
   UIOSWindowGraphicsHints  graphicsHints;
   BOOL                     hasGraphicsHints;
} ClassStatic;


+ (void) setOSWindowClass:(Class) cls
{
   assert( ! cls || [cls isSubclassOfClass:[GLFWOSWindow class]]);
   ClassStatic.windowClass = cls;
}


+ (void) setOSGraphicsContextClass:(Class) cls
{
   assert( ! cls || [cls isSubclassOfClass:[CGContext class]]);
   ClassStatic.contextClass = cls;
}


+ (Class) osWindowClass
{
   return( ClassStatic.windowClass ? ClassStatic.windowClass : [GLFWOSWindow class]);
}


+ (Class) osGraphicsContextClass
{
   return( ClassStatic.contextClass ? ClassStatic.contextClass : [CGContext class]);
}

+ (void) setOSGraphicsHints:(UIOSWindowGraphicsHints) hints
{
   ClassStatic.graphicsHints    = hints;
   ClassStatic.hasGraphicsHints = YES;
}


+ (UIOSWindowGraphicsHints) osGraphicsHints
{
   UIOSWindowGraphicsHints   hints;

   if( ClassStatic.hasGraphicsHints)
      return( ClassStatic.graphicsHints);

   hints = GLFWGraphicsHintsDefault;
   switch( [CGContext nanoVGBackend])
   {
   case CG_GL3     : hints = GLFWGraphicsHintsGL3; break;
   case CG_GL3_2   : hints = GLFWGraphicsHintsGL3_2; break;
   case CG_GLES2   : hints = GLFWGraphicsHintsGLES2; break;
   case CG_GLES3   : hints = GLFWGraphicsHintsGLES3; break;
   case CG_GLES3_2 : hints = GLFWGraphicsHintsGLES3_2; break;
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
