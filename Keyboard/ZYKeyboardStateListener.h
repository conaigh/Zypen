#import "headers.h"

@interface ZYKeyboardStateListener : NSObject
+ (instancetype)sharedInstance;
@property (nonatomic, readonly) BOOL visible;
@property (nonatomic, readonly) CGSize size;


- (void)_setVisible:(BOOL)val;
- (void)_setSize:(CGSize)size;
@end
