#import "import.h"


// some of these functions are tied to UIWindow... Historically
// These methods clobber some of the methods in UIView+UIEvent
@interface UIView (UIFirstResponder)

// return nil, should probably be real properties soon
- (id <UIResponder>) previousFirstResponder;
- (id <UIResponder>) nextFirstResponder;

- (BOOL) becomeFirstResponder;
- (BOOL) resignFirstResponder;
- (BOOL) isFirstResponder;

- (id <UIResponder>) previousFirstResponder;
- (id <UIResponder>) nextFirstResponder;

@end

