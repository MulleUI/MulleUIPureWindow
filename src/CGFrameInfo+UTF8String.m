//
// Copyright (c) 2022 Nat!, Mulle kybernetiK
//
#import "CGFrameInfo+UTF8String.h"

#import "import-private.h"


char   *CGWindowInfoUTF8String( struct CGWindowInfo *info)
{
   auto char  *s;

   if( ! info)
      return( "nil");

   s = MulleObjC_asprintf( 
"(frame = %.2f %.2f %.2f %.2f,"
" framebufferSize = %td %td,"
" UIScale = %.2f %.2f,"
" pixelRatio = %.2f )",
   info->frame.origin.x, info->frame.origin.y, 
   info->frame.size.width, info->frame.size.height, 
   info->framebufferSize.width, info->framebufferSize.height, 
   info->UIScale.dx, info->UIScale.dy,
   info->pixelRatio);

   return( s);
}


char   *CGFrameInfoUTF8String( struct CGFrameInfo *info)
{
   auto char  *s;

   if( ! info)
      return( "nil");

   s = MulleObjC_asprintf( 
"(frame = %.2f %.2f %.2f %.2f,"
" framebufferSize = %td %td,"
" UIScale = %.2f %.2f,"
" pixelRatio = %.2f,"
" viewportFrame = %td %td %td %td,"
" alpha = %.6f,"
" now = %.6f )",
   info->window.frame.origin.x, info->window.frame.origin.y, 
   info->window.frame.size.width, info->window.frame.size.height, 
   info->window.framebufferSize.width, info->window.framebufferSize.height, 
   info->window.UIScale.dx, info->window.UIScale.dy,
   info->window.pixelRatio,
   info->viewportFrame.origin.x, 
   info->viewportFrame.origin.y, 
   info->viewportFrame.size.width, 
   info->viewportFrame.size.height, 
   info->alpha,
   info->now);

   return( s);
}

