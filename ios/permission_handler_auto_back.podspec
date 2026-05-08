#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint permission_handler_auto_back.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'permission_handler_auto_back'
  s.version          = '0.0.1'
  s.summary          = 'permission_handler wrapper that auto-returns the app on Android after Settings.'
  s.description      = <<-DESC
Wraps permission_handler and brings your Flutter app back to the foreground on Android
after the user grants a special permission in Settings.
                       DESC
  s.homepage         = 'https://github.com/lequangkydev/permission_handler_auto_back'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Le Quang Ky' => 'kylq@vtn-global.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'flutter_permission_auto_return_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
