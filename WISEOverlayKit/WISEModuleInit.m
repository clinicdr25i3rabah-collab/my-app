#import <UIKit/UIKit.h>

FOUNDATION_EXPORT void WISEOverlayKitBootstrap(void);

__attribute__((constructor))
static void WISEOverlayKitModuleConstructor(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        WISEOverlayKitBootstrap();
    });
}