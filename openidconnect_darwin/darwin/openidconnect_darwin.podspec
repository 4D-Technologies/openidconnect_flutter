#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint openidconnect_darwin.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'openidconnect_darwin'
  s.version          = '2.0.0'
  s.summary          = 'Darwin implementation for OpenIdConnect.'
  s.description      = <<-DESC
Darwin implementation for OpenIdConnect.
                       DESC
  s.homepage         = 'https://github.com/4D-Technologies/openidconnect_flutter/tree/main/openidconnect_darwin'
  s.license          = { :file => '../LICENSE' }
  s.author           = { '4D Technologies' => 'support@4d-technologies.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'openidconnect_darwin/Sources/openidconnect_darwin/**/*'

  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'

  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'

  s.ios.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.osx.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }

  s.swift_version = '5.0'
end
