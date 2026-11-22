#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface OwnedDnsSdkBridge : NSObject
- (void)configureDiagnostic:(NSDictionary *)arguments complete:(void (^)(BOOL))complete;
- (void)lookup:(NSString *)host complete:(void (^)(NSArray<NSString *> *))complete;
- (void)disable;
@end
NS_ASSUME_NONNULL_END
