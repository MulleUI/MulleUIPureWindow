

static void   drawFlag( CGContext *context, CGRect canvas, CGColor colors[ 3])
{
   canvas.size.height /= 3.0;

   // red stripe
   CGContextBeginPath( context);
   CGContextRect( context, CGRectMake( canvas.origin.x,
                                      canvas.origin.y,
                                      canvas.size.width,
                                      canvas.size.height));
   CGContextFillColor( context, colors[ 0]);
   CGContextFill( context);

   // white stripe
   CGContextBeginPath( context);
   CGContextRect( context, CGRectMake( canvas.origin.x,
                                      canvas.origin.y + canvas.size.height * 1,
                                      canvas.size.width,
                                      canvas.size.height));
   CGContextFillColor( context, colors[ 1]);
   CGContextFill( context);

   // blue stripe
   CGContextBeginPath( context);
   CGContextRect( context, CGRectMake( canvas.origin.x,
                                      canvas.origin.y + canvas.size.height * 2,
                                      canvas.size.width,
                                      canvas.size.height));
   CGContextFillColor( context, colors[ 2]);
   CGContextFill( context);
}


static void   drawRedWhiteBlueFlag( CGContext *context, CGRect canvas)
{
   CGColor   colors[ 3];

   colors[ 0] = CGColorMakeRed();
   colors[ 1] = CGColorMakeWhite();
   colors[ 2] = CGColorMakeBlue();

   drawFlag( context, canvas, colors);
}
