#import "OwnedDnsSdkBridge.h"
#import <arpa/inet.h>

#if DEBUG && ZOLNIT_CLOUD_DNS_SDK_DIAGNOSTIC
#import <pdns-sdk-ios/DNSResolver.h>
#endif

#if DEBUG && ZOLNIT_CLOUD_DNS_SDK_DIAGNOSTIC
static BOOL OwnedSdkIPv4(struct in_addr address) {
  uint32_t value = ntohl(address.s_addr);
  return value != 0 && (value >> 24) != 127 && !IN_MULTICAST(value);
}

static BOOL OwnedSdkAddress(id value) {
  if (![value isKindOfClass:NSString.class] || [value length] > 45) return NO;
  struct in_addr v4;
  if (inet_pton(AF_INET, [value UTF8String], &v4) == 1) return OwnedSdkIPv4(v4);
  struct in6_addr v6;
  if (inet_pton(AF_INET6, [value UTF8String], &v6) != 1 || IN6_IS_ADDR_UNSPECIFIED(&v6) ||
      IN6_IS_ADDR_LOOPBACK(&v6) || IN6_IS_ADDR_MULTICAST(&v6)) return NO;
  if (IN6_IS_ADDR_V4MAPPED(&v6)) {
    memcpy(&v4, &v6.s6_addr[12], sizeof(v4));
    return OwnedSdkIPv4(v4);
  }
  return YES;
}

#endif

@implementation OwnedDnsSdkBridge {
  dispatch_queue_t _queue;
  NSSet<NSString *> *_hosts;
  NSUInteger _generation;
}

- (instancetype)init {
  if ((self = [super init])) {
    _queue = dispatch_queue_create("com.zolmid.zolnit.cloud-dns-diagnostic", DISPATCH_QUEUE_SERIAL);
    _hosts = [NSSet set];
  }
  return self;
}

- (void)configureDiagnostic:(NSDictionary *)arguments complete:(void (^)(BOOL))complete {
  complete(NO);
}

#if DEBUG && ZOLNIT_CLOUD_DNS_SDK_DIAGNOSTIC
- (void)strictFlags:(DNSResolver *)resolver {
  [DNSResolver disableLog];
  resolver.localdnsEnable = NO;
  resolver.scheme = DNSResolverSchemeHttps;
  resolver.cacheEnable = NO;
  resolver.immutableCacheEnable = NO;
  resolver.speedTestEnable = NO;
  resolver.timeout = 2;
  [resolver setKeepAliveDomains:@[]];
}
#endif

- (void)lookup:(NSString *)host complete:(void (^)(NSArray<NSString *> *))complete {
#if DEBUG && ZOLNIT_CLOUD_DNS_SDK_DIAGNOSTIC
  dispatch_async(_queue, ^{
    if (![self->_hosts containsObject:host]) { complete(@[]); return; }
    NSUInteger generation = self->_generation;
    __block BOOL completed = NO;
    void (^finish)(NSArray *) = ^(NSArray *values) {
      dispatch_async(self->_queue, ^{
        if (completed) return;
        completed = YES;
        if (generation != self->_generation || ![self->_hosts containsObject:host] ||
            ![values isKindOfClass:NSArray.class] || values.count == 0 || values.count > 32) { complete(@[]); return; }
        for (id address in values) { if (!OwnedSdkAddress(address)) { complete(@[]); return; } }
        complete(values);
      });
    };
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), self->_queue, ^{ finish(@[]); });
    @try {
      DNSResolver *resolver = [DNSResolver share];
      [self strictFlags:resolver];
      if (resolver.localdnsEnable || resolver.scheme != DNSResolverSchemeHttps) { finish(@[]); return; }
      [resolver getIpsDataWithDomain:host complete:finish];
    } @catch (NSException *exception) { finish(@[]); }
  });
#else
  complete(@[]);
#endif
}

- (void)disable {
  dispatch_async(_queue, ^{ self->_generation++; self->_hosts = [NSSet set]; });
}
@end
