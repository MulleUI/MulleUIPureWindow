

static void   drawFlag( struct NVGcontext *vg, CGRect canvas, CGColor colors[ 3])
{
   canvas.size.height /= 3.0;

   // red stripe
   nvgBeginPath( vg);
   nvgRect( vg, canvas.origin.x,
                canvas.origin.y,
                canvas.size.width,
                canvas.size.height);
   nvgFillColor( vg, colors[ 0]);
   nvgFill( vg);

   // white stripe
   nvgBeginPath( vg);
   nvgRect( vg, canvas.origin.x,
                canvas.origin.y + canvas.size.height * 1,
                canvas.size.width,
                canvas.size.height);
   nvgFillColor( vg, colors[ 1]);
   nvgFill( vg);

   // blue stripe
   nvgBeginPath( vg);
   nvgRect( vg, canvas.origin.x,
                canvas.origin.y + canvas.size.height * 2,
                canvas.size.width,
                canvas.size.height);
   nvgFillColor( vg, colors[ 2]);
   nvgFill( vg);
}


static void   drawRedWhiteBlueFlag( struct NVGcontext *vg, CGRect canvas)
{
   CGColor   colors[ 3];

   colors[ 0] = CGColorMakeRed();
   colors[ 1] = CGColorMakeWhite();
   colors[ 2] = CGColorMakeBlue();

   drawFlag( vg, canvas, colors);
}
