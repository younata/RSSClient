#import "WKExtension.h"

@interface WKExtension (Spec)

+ (void)setSharedExtension:(WKExtension *)sharedExtension;

- (void)setRootInterfaceController:(WKInterfaceController *)rootInterfaceController;

@end
