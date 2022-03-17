#import "UIView+CAAnimation.h"

#import "import-private.h"


//
// Actually we only want to animate CALayers. But when we do a
// -[UIView setFrame:] we implicitly change the layers geometry. We do this
// explicitly, when we call -layout afterwards.
//
// Insight: We animate transition from one -layout to another -layout. Which
//          means that there should be no -layout calls during animation.
//
// For implicit animation it would be enough to have the animated UIViews
// layout and set the layer properties, which are also animatable. And then
// completely ignore the UIView values. That would work visually but has these
// problems:
//
// * Who changes the initial and UIView values ?
// * How can be events be handled at the iteration sections ?
//
// So view values should be animated as well, BUT, they shouldn't trigger a
// layout.
//
// During the render, animated properties will be copied down to the layers.
//
// Problem: animations run on the renderQueue.

@interface UIAnimatableViewPropertiesSnapshot : NSObject <UIAnimatableViewProperties>

UI_VIEW_ANIMATABLE_PROPERTIES;

@end


@implementation UIAnimatableViewPropertiesSnapshot

- (void) willChange
{
   // nothing
}

@end


@implementation UIView ( CAAnimation)

//
// This is called very often during animation, it would be good if the
// animation code could use a different setter that does not call
// will change..
//
- (void) willChange
{
   id   manager;

   // this is called frequently so use C
   manager = CATransactionGetCurrentTransaction();
   if( ! manager)
      return;
   if( _snapshot)
      return;

   _snapshot = [UIAnimatableViewPropertiesSnapshot new];

   // the only "graphics" properties
   [_snapshot setAlpha:_alpha];

   // these are all "layout" properties
   [_snapshot setBounds:[self bounds]]; // need interpreted value
   [_snapshot setFrame:_frame];
   [_snapshot setMargins:_margins];
   [_snapshot setPadding:_padding];

   // add with priority
   [manager addAnimatableObject:self];
}



- (void) commitImplicitAnimations:(CAAnimationGroup *) group
{
   if( ! _snapshot)
      return;

   /** Our animatable properties
       subclasses might want to add more
    **/
   [self animatePropertiesWithSnapshot:_snapshot
                        animationGroup:group];

   [(NSObject *) _snapshot autorelease];
   _snapshot = nil;
}



+ (void) beginAnimations:(char *) animationID
                 context:(id) context
{
   CATransaction   *transaction;

   transaction = [CATransaction new];

   [transaction begin];

   [transaction setAnimationID:animationID];
   [transaction setContext:context];
   [transaction setAnimationDuration:2.0];
   [transaction setAnimationRepeatCount:1.0];
   [transaction setAnimationCurve:UIViewAnimationCurveEaseInOut];
}


+ (CAAnimationGroup *) commitAnimations
{
   CATransaction      *transaction;
   CAAnimationGroup   *group;

   transaction = CATransactionGetCurrentTransaction();
   assert( transaction);
   group = [transaction commit];
   [transaction autorelease];

   return( group);
}



+ (BOOL) areAnimationsEnabled
{
   return( UIViewAreAnimationsEnabled());
}


+ (void) addAnimatableObject:(id <CAImplicitlyAnimatableObject>) layer
{
   CATransaction   *transaction;

   transaction = CATransactionGetCurrentTransaction();
   assert( transaction);
   [transaction addAnimatableObject:layer];
}

/* "properties" */


+ (id) animationDelegate
{
   CATransaction   *transaction;

   transaction = CATransactionGetCurrentTransaction();
   assert( transaction);
   return( [transaction animationDelegate]);
}


+ (SEL) animationDidStopSelector
{
   CATransaction   *transaction;

   transaction = CATransactionGetCurrentTransaction();
   assert( transaction);
   return( [transaction animationDidStopSelector]);
}


+ (SEL) animationWillStartSelector
{
   CATransaction   *transaction;

   transaction = CATransactionGetCurrentTransaction();
   assert( transaction);
   return( [transaction animationWillStartSelector]);
}


+ (void) setAnimationDelegate:(id) value
{
   CATransaction   *transaction;

   transaction = CATransactionGetCurrentTransaction();
   assert( transaction);
   [transaction setAnimationDelegate:value];
}


+ (void) setAnimationDidStopSelector:(SEL) value
{
   CATransaction   *transaction;

   transaction = CATransactionGetCurrentTransaction();
   assert( transaction);
   [transaction setAnimationDidStopSelector:value];
}


+ (void) setAnimationWillStartSelector:(SEL) value
{
   CATransaction   *transaction;

   transaction = CATransactionGetCurrentTransaction();
   assert( transaction);
   [transaction setAnimationWillStartSelector:value];
}



//
+ (mulle_relativetime_t) animationDelay
{
   CATransaction   *transaction;

   transaction = CATransactionGetCurrentTransaction();
   assert( transaction);
   return( [transaction animationDelay]);
}


+ (void) setAnimationDelay:(mulle_relativetime_t) delay
{
   CATransaction   *transaction;

   transaction = CATransactionGetCurrentTransaction();
   assert( transaction);
   [transaction setAnimationDelay:delay];
}



+ (mulle_relativetime_t) animationDuration
{
   CATransaction   *transaction;

   transaction = CATransactionGetCurrentTransaction();
   assert( transaction);
   return( [transaction animationDuration]);
}


+ (void) setAnimationDuration:(mulle_relativetime_t) duration
{
   CATransaction   *transaction;

   transaction = CATransactionGetCurrentTransaction();
   assert( transaction);
   [transaction setAnimationDelay:duration];
}


+ (NSUInteger) animationCurve
{
   CATransaction   *transaction;

   transaction = CATransactionGetCurrentTransaction();
   assert( transaction);
   return( [transaction animationCurve]);
}


+ (void) setAnimationCurve:(NSUInteger) value
{
   CATransaction   *transaction;

   transaction = CATransactionGetCurrentTransaction();
   assert( transaction);

   [transaction setAnimationCurve:value];
}


+ (CATweenFunction *) animationTweenFunction
{
   CATransaction   *transaction;

   transaction = CATransactionGetCurrentTransaction();
   assert( transaction);
   return( [transaction animationTweenFunction]);
}


+ (void) setAnimationTweenFunction:(CATweenFunction *) tween
{
   CATransaction   *transaction;

   transaction = CATransactionGetCurrentTransaction();
   assert( transaction);
   [transaction setAnimationTweenFunction:tween];
}


+ (BOOL) animationRepeatAutoreverses
{
   CATransaction   *transaction;

   transaction = CATransactionGetCurrentTransaction();
   assert( transaction);
   return( [transaction animationAutoreverses]);
}


+ (void) setAnimationRepeatAutoreverses:(BOOL) flag
{
   CATransaction   *transaction;

   transaction = CATransactionGetCurrentTransaction();
   assert( transaction);
   [transaction setAnimationAutoreverses:flag];
}


+ (BOOL) animationAutoreverses
{
   CATransaction   *transaction;

   transaction = CATransactionGetCurrentTransaction();
   assert( transaction);
   return( [transaction animationAutoreverses]);
}


+ (void) setAnimationAutoreverses:(BOOL) flag
{
   CATransaction   *transaction;

   transaction = CATransactionGetCurrentTransaction();
   assert( transaction);
   [transaction setAnimationAutoreverses:flag];
}

// incompatible
+ (BOOL) animationIsAdditive
{
   CATransaction   *transaction;

   transaction = CATransactionGetCurrentTransaction();
   assert( transaction);
   return( [transaction animationIsAdditive]);
}


+ (void) setAnimationIsAdditive:(BOOL) flag;
{
   CATransaction   *transaction;

   transaction = CATransactionGetCurrentTransaction();
   assert( transaction);
   [transaction setAnimationIsAdditive:flag];
}


// incompatible
+ (float) animationRepeatCount
{
   CATransaction   *transaction;

   transaction = CATransactionGetCurrentTransaction();
   assert( transaction);
   return( [transaction animationRepeatCount]);
}


+ (void) setAnimationRepeatCount:(float) value
{
   CATransaction   *transaction;

   transaction = CATransactionGetCurrentTransaction();
   assert( transaction);
   [transaction setAnimationRepeatCount:value];
}


// incompatible
+ (BOOL) mulleAnimationRepeats
{
   CATransaction   *transaction;

   transaction = CATransactionGetCurrentTransaction();
   assert( transaction);
   return( [transaction animationRepeatCount] >= 1.0);
}


+ (void) mulleSetAnimationRepeats:(BOOL) flag
{
   CATransaction   *transaction;

   transaction = CATransactionGetCurrentTransaction();
   assert( transaction);
   [transaction setAnimationRepeatCount:flag ? INFINITY : 0.0];
}

@end
