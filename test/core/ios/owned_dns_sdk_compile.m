#import <Foundation/Foundation.h>
#import "OwnedDnsSdkBridge.h"

int main(void) {
  @autoreleasepool {
    OwnedDnsSdkBridge *bridge = [OwnedDnsSdkBridge new];
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    [bridge configureDiagnostic:@{} complete:^(BOOL available) {
      NSCAssert(!available, @"missing credentials must not initialize SDK");
      [bridge lookup:@"link.zolmid.com" complete:^(NSArray *values) {
        NSCAssert(values.count == 0, @"missing credentials must not resolve");
        dispatch_semaphore_signal(done);
      }];
    }];
    return dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0 ? 0 : 1;
  }
}
