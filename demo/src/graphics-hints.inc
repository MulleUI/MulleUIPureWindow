#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

@interface UIPureWindow( UIApplicationGlue)
+ (void) setOSGraphicsHints:(UIOSWindowGraphicsHints) hints;
+ (UIOSWindowGraphicsHints) osGraphicsHints;
@end


static void  UIPrintGraphicsHintsUsage( FILE *fp)
{
   fprintf( fp,
"Graphics options:\n"
"   --gl3 | --gl3_2 | --gles2 | --gles3 | --gles3_2\n"
"   --default-context | --no-context\n"
"   --native | --egl | --osmesa\n"
"   --any | --core | --compat\n"
"   --forward | --no-forward\n"
"   --mesa-vendor\n"
"   --driver <vendor[:driver][@gpu]>\n"
"   --mesa-path <dir>\n"
"   --software\n");
}


static void  UIWarnOptionOverride( char *current,
                                   char *previous,
                                   char *category)
{
   if( previous && strcmp( previous, current))
      fprintf( stderr, "warning: %s overrides %s for %s\n", current, previous, category);
}


static int   UIContextChanged( UIOSWindowGraphicsHints *hints,
                               UIOSWindowGraphicsHints *preset)
{
   return( hints->profile != preset->profile
           || hints->api != preset->api
           || hints->major != preset->major
           || hints->minor != preset->minor);
}


static void  UIApplyContextPreset( UIOSWindowGraphicsHints *hints,
                                   UIOSWindowGraphicsHints preset)
{
   hints->profile = preset.profile;
   hints->api     = preset.api;
   hints->major   = preset.major;
   hints->minor   = preset.minor;
}


static int   UIParseGraphicsHints( UIOSWindowGraphicsHints *hints,
                                   int argc,
                                   char *argv[])
{
   int            i;
   char           *contextOption;
   char           *libOption;
   char           *profileOption;
   char           *forwardOption;

   contextOption = NULL;
   libOption     = NULL;
   profileOption = NULL;
   forwardOption = NULL;

   for( i = 1; i < argc; i++)
   {
      char   *s;

      s = argv[ i];
      if( ! s)
         continue;

      if( ! strcmp( s, "--"))
      {
         argv[ i] = NULL;
         continue;
      }

      if( s[ 0] != '-' || s[ 1] != '-')
         continue;

      if( ! strcmp( s, "--default-context"))
      {
         UIOSWindowGraphicsHints   preset;

         preset = GLFW_DEFAULT_CONTEXT;
         if( UIContextChanged( hints, &preset))
            UIWarnOptionOverride( s, contextOption, "context");
         UIApplyContextPreset( hints, preset);
         contextOption = s;
         argv[ i] = NULL;
         continue;
      }
      if( ! strcmp( s, "--no-context"))
      {
         UIOSWindowGraphicsHints   preset;

         preset = GLFW_NO_CONTEXT;
         if( UIContextChanged( hints, &preset))
            UIWarnOptionOverride( s, contextOption, "context");
         UIApplyContextPreset( hints, preset);
         contextOption = s;
         argv[ i] = NULL;
         continue;
      }
      if( ! strcmp( s, "--gl3"))
      {
         UIOSWindowGraphicsHints   preset;

         preset = GLFW_GL3_CONTEXT;
         if( UIContextChanged( hints, &preset))
            UIWarnOptionOverride( s, contextOption, "context");
         UIApplyContextPreset( hints, preset);
         contextOption = s;
         argv[ i] = NULL;
         continue;
      }
      if( ! strcmp( s, "--gl3_2"))
      {
         UIOSWindowGraphicsHints   preset;

         preset = GLFW_GL3_2_CONTEXT;
         if( UIContextChanged( hints, &preset))
            UIWarnOptionOverride( s, contextOption, "context");
         UIApplyContextPreset( hints, preset);
         contextOption = s;
         argv[ i] = NULL;
         continue;
      }
      if( ! strcmp( s, "--gles2"))
      {
         UIOSWindowGraphicsHints   preset;

         preset = GLFW_GLES2_CONTEXT;
         if( UIContextChanged( hints, &preset))
            UIWarnOptionOverride( s, contextOption, "context");
         UIApplyContextPreset( hints, preset);
         contextOption = s;
         argv[ i] = NULL;
         continue;
      }
      if( ! strcmp( s, "--gles3"))
      {
         UIOSWindowGraphicsHints   preset;

         preset = GLFW_GLES3_CONTEXT;
         if( UIContextChanged( hints, &preset))
            UIWarnOptionOverride( s, contextOption, "context");
         UIApplyContextPreset( hints, preset);
         contextOption = s;
         argv[ i] = NULL;
         continue;
      }
      if( ! strcmp( s, "--gles3_2"))
      {
         UIOSWindowGraphicsHints   preset;

         preset = GLFW_GLES3_2_CONTEXT;
         if( UIContextChanged( hints, &preset))
            UIWarnOptionOverride( s, contextOption, "context");
         UIApplyContextPreset( hints, preset);
         contextOption = s;
         argv[ i] = NULL;
         continue;
      }
      if( ! strcmp( s, "--any"))
      {
         if( hints->profile != 1)
            UIWarnOptionOverride( s, profileOption, "profile");
         hints->profile = 1;
         profileOption  = s;
         argv[ i]       = NULL;
         continue;
      }
      if( ! strcmp( s, "--core"))
      {
         if( hints->profile != 2)
            UIWarnOptionOverride( s, profileOption, "profile");
         hints->profile = 2;
         profileOption  = s;
         argv[ i]       = NULL;
         continue;
      }
      if( ! strcmp( s, "--compat"))
      {
         if( hints->profile != 3)
            UIWarnOptionOverride( s, profileOption, "profile");
         hints->profile = 3;
         profileOption  = s;
         argv[ i]       = NULL;
         continue;
      }
      if( ! strcmp( s, "--native"))
      {
         if( hints->lib != 1)
            UIWarnOptionOverride( s, libOption, "context API library");
         hints->lib = 1;
         libOption  = s;
         argv[ i]   = NULL;
         continue;
      }
      if( ! strcmp( s, "--egl"))
      {
         if( hints->lib != 2)
            UIWarnOptionOverride( s, libOption, "context API library");
         hints->lib = 2;
         libOption  = s;
         argv[ i]   = NULL;
         continue;
      }
      if( ! strcmp( s, "--osmesa"))
      {
         if( hints->lib != 3)
            UIWarnOptionOverride( s, libOption, "context API library");
         hints->lib = 3;
         libOption  = s;
         argv[ i]   = NULL;
         continue;
      }
      if( ! strcmp( s, "--forward"))
      {
         if( hints->forward != 1)
            UIWarnOptionOverride( s, forwardOption, "forward-compatibility");
         hints->forward = 1;
         forwardOption  = s;
         argv[ i]       = NULL;
         continue;
      }
      if( ! strcmp( s, "--no-forward"))
      {
         if( hints->forward != 0)
            UIWarnOptionOverride( s, forwardOption, "forward-compatibility");
         hints->forward = 0;
         forwardOption  = s;
         argv[ i]       = NULL;
         continue;
      }
      if( ! strcmp( s, "--software"))
      {
         hints->software = 1;
         argv[ i]        = NULL;
         continue;
      }
      if( ! strcmp( s, "--mesa-vendor"))
      {
         hints->glx_vendor = "mesa";
         argv[ i]          = NULL;
         continue;
      }
      if( ! strcmp( s, "--mesa-path"))
      {
         if( ++i >= argc)
            return( 0);
         if( hints->lib != 3)
            UIWarnOptionOverride( s, libOption, "context API library");
         hints->lib      = 3;
         hints->lib_path = argv[ i];
         libOption       = s;
         argv[ i - 1]    = NULL;
         argv[ i]        = NULL;
         continue;
      }
      if( ! strcmp( s, "--driver"))
      {
         char   spec[ 256];
         char   *drv;
         char   *gpu;
         char   *at;
         char   *colon;

         if( ++i >= argc)
            return( 0);

         strncpy( spec, argv[ i], sizeof( spec) - 1);
         spec[ sizeof( spec) - 1] = '\0';

         at = strchr( spec, '@');
         if( at) { *at = '\0'; gpu = at + 1; } else gpu = NULL;

         colon = strchr( spec, ':');
         if( colon) { *colon = '\0'; drv = colon + 1; } else drv = NULL;

         hints->glx_vendor = strdup( spec);
         if( drv)
            hints->driver = strdup( drv);
         if( gpu)
            hints->dri_prime = (unsigned int) atoi( gpu) + 1;

         argv[ i - 1] = NULL;
         argv[ i]     = NULL;
         continue;
      }

      return( 0);
   }

   return( 1);
}


static int   UIConfigureGraphicsHints( int argc,
                                       char *argv[],
                                       UIOSWindowGraphicsHints *hints)
{
   *hints = [UIPureWindow osGraphicsHints];
   if( ! UIParseGraphicsHints( hints, argc, argv))
      return( 0);
#ifdef HAVE_IMPORT__MULLE_GLFW
   GLFWGraphicsHintsApplyDriverEnv( *hints);
#endif
   [UIPureWindow setOSGraphicsHints:*hints];
   return( 1);
}
