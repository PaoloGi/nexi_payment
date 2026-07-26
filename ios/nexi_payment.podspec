#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint nexi_payment.podspec' to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'nexi_payment'
  s.version          = '2.1.0'
  s.summary          = 'Flutter plugin for Nexi payments (XPay and NPG gateways).'
  s.description      = <<-DESC
Flutter plugin for Nexi payments: classic XPay WebView payments and the
NPG (developer.nexigroup.com) Hosted Payment Page.
                       DESC
  s.homepage         = 'https://github.com/PaoloGi/nexi_payment'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Paolo Gianfelici' => 'paolo.gianfelici.dev@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  # The Nexi SDKs are downloaded from Nexi's own release repositories at
  # install time and pinned by SHA-256, rather than being redistributed here.
  # This mirrors what Nexi's official Nexi_XPay podspec does.
  #
  # We do not simply depend on that pod: it ships an arm64 device slice only,
  # so anything built for the simulator fails with "No such module 'XPaySDK'".
  # The script merges Nexi's separate device and simulator archives instead.
  s.prepare_command = 'bash scripts/fetch_frameworks.sh'
  s.vendored_frameworks = 'Frameworks/XPaySDK.xcframework', 'Frameworks/ThreeDS_SDK.xcframework', 'Frameworks/NPGSDK.xcframework'
  s.preserve_paths = 'Frameworks/*.xcframework', 'scripts/fetch_frameworks.sh'
  s.ios.deployment_target = '14.4'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
