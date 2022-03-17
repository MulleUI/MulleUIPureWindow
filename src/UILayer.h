// Make CALayer conform to this protocol
// then MulleUIWindow does not need to inherit from MulleGraphics

@protocol UILayer < NSObject>

@property( assign) CGRect              frame;
@property( assign) CGRect              bounds;
@property( assign) CGFloat             alpha;

@property( assign) CGAffineTransform   transform;
@property( assign) CGRect              clipRect;

- (void) dumpWithIndent:(NSUInteger) indent;

@end

