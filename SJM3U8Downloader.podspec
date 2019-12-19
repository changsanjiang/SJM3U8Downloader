#
# Be sure to run `pod lib lint SJM3U8Downloader.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'SJM3U8Downloader'
  s.version          = '0.0.1'
  s.summary          = 'm3u8 downloader.'

  s.description      = <<-DESC
        https://github.com/changsanjiang/SJM3U8Downloader/blob/master/README.md
                       DESC

  s.homepage         = 'https://github.com/changsanjiang/SJM3U8Downloader'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'changsanjiang@gmail.com' => 'changsanjiang@gmail.com' }
  s.source           = { :git => 'https://github.com/changsanjiang/SJM3U8Downloader.git', :tag => s.version.to_s }
  s.ios.deployment_target = '8.0'

  s.source_files = 'SJM3U8Downloader/*.{h,m}'
  s.subspec 'Core' do |ss|
      ss.source_files = 'SJM3U8Downloader/Core/*.{h,m}'
  end
  
  s.dependency 'SJDownloadDataTask'
  s.dependency 'CocoaHTTPServer'
  s.dependency 'SJUIKit/SQLite3'
end
