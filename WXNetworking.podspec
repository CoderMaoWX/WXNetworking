#
# Be sure to run `pod lib lint WXNetworking.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |spec|
    
  spec.name         = 'WXNetworking'
  spec.version      ='3.2'
  spec.ios.deployment_target = '9.0'
  spec.summary      = 'iOS基于AFN封装可定制的网络请求框架'
  spec.homepage     = 'https://github.com/CoderMaoWX/WXNetworking'
  spec.license      = { :type => 'MIT', :file => 'LICENSE' }
  spec.author       = { 'maowangxin' => 'maowangxin_2013@163.com' }
  spec.source       = { :git => 'https://github.com/CoderMaoWX/WXNetworking.git', :tag => spec.version }
  spec.source_files = 'WXNetworking/*.{h,m}'
  spec.requires_arc = true
  
  spec.dependency 'AFNetworking'
  spec.dependency 'YYCache'
  spec.dependency 'YYModel'
  
end
