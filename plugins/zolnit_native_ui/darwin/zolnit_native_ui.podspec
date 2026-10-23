Pod::Spec.new do |s|
  s.name = 'zolnit_native_ui'
  s.version = '0.1.0'
  s.summary = 'Native ZolNit connection presentation for Flutter.'
  s.description = <<-DESC
Native SwiftUI presentation and Flutter platform-view bridge for ZolNit.
  DESC
  s.homepage = 'https://github.com/Zolmid/FlClash'
  s.license = { :file => '../LICENSE' }
  s.author = 'ZolNit contributors'
  s.source = { :path => '.' }
  s.source_files = 'Sources/**/*.swift'
  s.resources = 'Sources/ZolnitNativeUiCore/Resources/*.png'
  s.swift_version = '5.9'
  s.static_framework = true
  s.ios.deployment_target = '15.0'
  s.osx.deployment_target = '12.0'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
end
