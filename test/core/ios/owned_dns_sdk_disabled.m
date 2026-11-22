#import <Foundation/Foundation.h>
#import "OwnedDnsSdkBridge.h"

int main(void) {
  @autoreleasepool {
    OwnedDnsSdkBridge *bridge = [OwnedDnsSdkBridge new];
    for (NSDictionary *arguments in @[@{}, @{@"hosts": @[@"link.zolmid.com"],
        @"accountId": @"SYNTHETIC_ACCOUNT", @"accessKeyId": @"SYNTHETIC_KEY", @"accessKeySecret": @"SYNTHETIC_SECRET"}]) {
      __block BOOL called = NO;
      [bridge configureDiagnostic:arguments complete:^(BOOL available) { NSCAssert(!available, @"release diagnostic boundary"); called = YES; }];
      NSCAssert(called, @"disabled completion");
    }
    [bridge lookup:@"link.zolmid.com" complete:^(NSArray *values) { NSCAssert(values.count == 0, @"no SDK/local DNS"); }];
    [bridge disable];
  }
  return 0;
}
