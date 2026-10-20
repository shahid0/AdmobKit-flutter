#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint admob_kit_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'admob_kit_flutter'
  s.version          = '0.0.1'
  s.summary          = 'Flutter AdMob ads with native templates and adaptive banners.'
  s.description      = <<-DESC
Google AdMob ads for Flutter with consent-aware loading, adaptive banners, native templates, fullscreen presentation and live native styling.
                       DESC
  s.homepage         = 'https://github.com/shahid0/AdmobKit-flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Shahid' => 'https://github.com/shahid0' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'google_mobile_ads'
  s.platform = :ios, '13.0'
  s.static_framework = true

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES'
  }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'flutter_ads_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
