#
# Be sure to run `pod lib lint InsDownloader.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'InsDownloader'
  s.version          = '0.1.0'
  s.summary          = 'Fast handling of insLink'
  s.homepage         = 'https://github.com/Girlsmile/InsDownloader'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Girlsmile' => 'gzp@softin-tech.com' }
  s.source           = { :git => 'https://github.com/Girlsmile/InsDownloader.git', :tag => s.version.to_s }
  s.ios.deployment_target = '9.0'
  s.source_files = 'InsDownloader/Classes/**/*.{swift,h,m}'
  s.xcconfig = { 'HEADER_SEARCH_PATHS' => '$(SDKROOT)/usr/include/libxml2' }
  s.swift_version = '4.2'
  s.dependency 'Common', '~> 4.0.32'
  s.dependency 'FEAssetKit'
  s.dependency 'Kanna'
  s.dependency 'SnapKit', '~> 4.2.0'
end
