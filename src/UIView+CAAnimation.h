#import "import.h"


typedef NS_ENUM( NSUInteger, UIViewAnimationCurve)
{
   UIViewAnimationCurveEaseInOut = CAAnimationCurveEaseInOut,
   UIViewAnimationCurveEaseIn    = CAAnimationCurveEaseIn,
   UIViewAnimationCurveEaseOut   = CAAnimationCurveEaseOut,
   UIViewAnimationCurveLinear    = CAAnimationCurveLinear
};


//
// Doing it like this is kinda bad, because different windows could have
// different threads but they couldn't create animations at the same time
// because it is tied to the class. On the other, one can reuse more
// UIKit code, by keeping this as is.
// Possible solution: Have [UIWindow window] in a thread local variable
// and forward all these UIView calls there
//
// TODO: outsource this into CATransaction ?
//
@interface UIView ( CAAnimation) <CAImplicitlyAnimatableObject>

+ (void) beginAnimations:(char *) animationID
                 context:(id) context;

//
// this is different to UIView, you get a CAAnimationGroup and have to
// add it to the window of your choice
//
+ (CAAnimationGroup *) commitAnimations;

+ (BOOL) areAnimationsEnabled;

+ (void) setAnimationDelegate:(id) delegate;
+ (void) setAnimationWillStartSelector:(SEL) selector;
+ (void) setAnimationDidStopSelector:(SEL) selector;

+ (NSUInteger) animationCurve;
+ (void) setAnimationCurve:(NSUInteger) curve;

+ (CATweenFunction *) animationTweenFunction;
+ (void) setAnimationTweenFunction:(CATweenFunction *) curve;

+ (mulle_relativetime_t) animationDelay;
+ (void) setAnimationDelay:(mulle_relativetime_t) delay;

+ (mulle_relativetime_t) animationDuration;
+ (void) setAnimationDuration:(mulle_relativetime_t) duration;

+ (BOOL) animationRepeatAutoreverses;
+ (void) setAnimationRepeatAutoreverses:(BOOL) flag;

+ (BOOL) animationIsAdditive;
+ (void) setAnimationIsAdditive:(BOOL) flag;

// incompatible, this like setAnimationRepeatCount:-1 (YES)
// or setAnimationRepeatCount:0
+ (BOOL) mulleAnimationRepeats;
+ (void) mulleSetAnimationRepeats:(BOOL) flag;

// if repeatCount < 0.0 then it repeats indefinitely
+ (void ) setAnimationRepeatCount:(float) repeatCount;
+ (float) animationRepeatCount;

+ (void) addAnimatableObject:(id <CAImplicitlyAnimatableObject>) object;

- (void) willChange;

@end

static inline BOOL   UIViewAreAnimationsEnabled( void)
{
   return( CATransactionGetCurrentTransaction() != nil);
}
