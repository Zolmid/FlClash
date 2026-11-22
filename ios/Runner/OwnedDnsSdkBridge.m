#import "OwnedDnsSdkBridge.h"
#import <arpa/inet.h>

#if ZOLNIT_CLOUD_DNS_SDK
#import <pdns-sdk-ios/DNSResolver.h>
#endif

#if ZOLNIT_CLOUD_DNS_SDK
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
  NSTimeInterval _expiresAt;
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

- (void)configureLoopback:(NSDictionary *)arguments complete:(void (^)(BOOL))complete {
#if ZOLNIT_CLOUD_DNS_SDK
  dispatch_async(_queue, ^{
    self->_generation++;
    self->_hosts = [NSSet set];
    NSArray *hosts = arguments[@"hosts"];
    NSNumber *port = arguments[@"port"], *expiry = arguments[@"expiresAt"];
    NSString *key = arguments[@"keyId"], *secret = arguments[@"secret"];
    NSCharacterSet *invalid = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"] invertedSet];
    if (![hosts isKindOfClass:NSArray.class] || hosts.count == 0 || hosts.count > 256 ||
        ![port isKindOfClass:NSNumber.class] || port.integerValue < 1 || port.integerValue > 65535 ||
        ![expiry isKindOfClass:NSNumber.class] || ![key isKindOfClass:NSString.class] ||
        ![secret isKindOfClass:NSString.class] || key.length != 64 || secret.length != 64 ||
        [key rangeOfCharacterFromSet:invalid].location != NSNotFound ||
        [secret rangeOfCharacterFromSet:invalid].location != NSNotFound) { complete(NO); return; }
    NSTimeInterval remaining = expiry.doubleValue / 1000.0 - NSDate.date.timeIntervalSince1970;
    if (remaining <= 0 || remaining > 300) { complete(NO); return; }
    NSCharacterSet *hostChars = [[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789.-"] invertedSet];
    for (id value in hosts) {
      if (![value isKindOfClass:NSString.class]) { complete(NO); return; }
      NSString *host = value;
      if (host.length > 253 || [host rangeOfCharacterFromSet:hostChars].location != NSNotFound ||
          !([host isEqualToString:@"link.zolmid.com"] || [host hasSuffix:@".nodes.zolmid.com"])) { complete(NO); return; }
      for (NSString *label in [host componentsSeparatedByString:@"."]) {
        if (label.length == 0 || label.length > 63 || [label hasPrefix:@"-"] || [label hasSuffix:@"-"]) { complete(NO); return; }
      }
    }
    NSTimeInterval deadline = NSProcessInfo.processInfo.systemUptime + remaining;
    @try {
      DNSResolver *resolver = [DNSResolver share];
      [self strictFlags:resolver];
      [resolver setFusionDNSWithIPv4:@[@"127.0.0.1"] IPv6:nil Host:nil Port:port.stringValue
        HealthCheckDomain:@"link.zolmid.com" accessKeyId:key accesskeySecret:secret];
      [self strictFlags:resolver];
      [resolver clearHostCache:hosts];
      self->_hosts = [NSSet setWithArray:hosts];
      self->_expiresAt = deadline;
      complete(YES);
    } @catch (NSException *exception) { complete(NO); }
  });
#else
  complete(NO);
#endif
}

#if ZOLNIT_CLOUD_DNS_SDK
- (void)strictFlags:(DNSResolver *)resolver {
  [DNSResolver disableLog];
  resolver.localdnsEnable = NO;
  resolver.scheme = DNSResolverSchemeHttp;
  resolver.cacheEnable = YES;
  resolver.minCacheTTL = 0;
  resolver.maxCacheTTL = 1;
  resolver.ispEnable = NO;
  resolver.immutableCacheEnable = NO;
  resolver.speedTestEnable = NO;
  resolver.timeout = 2;
  [resolver setKeepAliveDomains:@[]];
}
#endif

- (void)lookup:(NSString *)host complete:(void (^)(NSArray<NSString *> *))complete {
#if ZOLNIT_CLOUD_DNS_SDK
  dispatch_async(_queue, ^{
    if (![self->_hosts containsObject:host] || NSProcessInfo.processInfo.systemUptime >= self->_expiresAt) { complete(@[]); return; }
    NSUInteger generation = self->_generation;
    __block BOOL completed = NO;
    __block NSUInteger remaining = 2;
    NSMutableArray *answers = [NSMutableArray array];
    void (^finish)(NSArray *, BOOL) = ^(NSArray *values, BOOL timeout) {
      dispatch_async(self->_queue, ^{
        if (completed) return;
        if ([values isKindOfClass:NSArray.class]) [answers addObjectsFromArray:values];
        if (!timeout && --remaining > 0) return;
        completed = YES;
        if (generation != self->_generation || ![self->_hosts containsObject:host] ||
            NSProcessInfo.processInfo.systemUptime >= self->_expiresAt || answers.count == 0 || answers.count > 32) { complete(@[]); return; }
        for (id address in answers) { if (!OwnedSdkAddress(address)) { complete(@[]); return; } }
        complete(answers);
      });
    };
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2500 * NSEC_PER_MSEC), self->_queue, ^{ finish(@[], YES); });

    @try {
      DNSResolver *resolver = [DNSResolver share];
      [self strictFlags:resolver];
      if (resolver.localdnsEnable || resolver.scheme != DNSResolverSchemeHttp) { finish(@[], YES); return; }
      [resolver getIpv4DataWithDomain:host complete:^(NSArray *values) { finish(values, NO); }];
      [resolver getIpv6DataWithDomain:host complete:^(NSArray *values) { finish(values, NO); }];
    } @catch (NSException *exception) { finish(@[], YES); }
  });
#else
  complete(@[]);
#endif
}

- (void)disable {
  dispatch_async(_queue, ^{ self->_generation++; self->_hosts = [NSSet set]; });
}
@end
