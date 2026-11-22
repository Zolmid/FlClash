Pod::Spec.new do |s|
  s.name = 'ZolnitCloudDnsSdk'
  s.version = '2.3.1'
  s.summary = 'Official Alibaba Cloud DNS SDK for ZolNit loopback FusionDNS'
  s.homepage = 'https://help.aliyun.com/zh/dns/httpdns-ios-sdk-development-guide'
  s.license = { :type => 'Apache-2.0' }
  s.author = 'Alibaba Cloud'
  s.source = { :http => 'https://dns-tool.oss-cn-beijing.aliyuncs.com/doh-sdk/prod/alidns_ios_demo.zip',
    :sha256 => 'b81532101dac5ed2ddf195f10607bb6f94627aca398561f91c56c351afd25444' }
  s.platform = :ios, '15.0'
  s.static_framework = true
  s.vendored_frameworks = 'DNSResolverDemo/DNSResolverDemo/pdns-sdk-ios.framework'
  s.frameworks = 'Foundation', 'SystemConfiguration', 'CoreTelephony'
  s.libraries = 'c++', 'resolv'
  s.user_target_xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) ZOLNIT_CLOUD_DNS_SDK=1',
    'OTHER_LDFLAGS' => '$(inherited) -ObjC' }
end
