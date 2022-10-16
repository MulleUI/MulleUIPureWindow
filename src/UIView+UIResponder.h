#import "import.h"


@interface UIView (UIResponder) <UIResponder>

- (void) didResignFirstResponder;


// return nil, should probably be real properties soon
- (id <UIResponder>) previousFirstResponder;
- (id <UIResponder>) nextFirstResponder;

@end
