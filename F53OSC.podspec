Pod::Spec.new do |s|
  s.name         = 'F53OSC'
  s.version      = '1.2.0'
  s.summary      = 'A nice open source OSC library for Objective-C.'

  s.description  = <<-DESC
                    * Hey neat, it's a nice open source OSC library for Objective-C.

                    * From your friends at Figure 53.

                    * For convenience, we've included a few public domain source files from CocoaAsyncSocket. But appropriate thanks, kudos, and curiosity about that code should be directed to the source.
                   DESC

  s.author       = 'Figure 53, LLC'
  s.homepage     = 'https://figure53.com/studio/'

  s.license      = { :type => 'BSD-like', :file => 'LICENSE.txt' }

  s.social_media_url   = 'https://twitter.com/figure53'
  
  s.platforms     = { :osx => '11.0', :ios => '14.0', :tvos => '14.0' }
  s.swift_version = '5.0'
  s.source        = { :git => 'https://github.com/Figure53/F53OSC.git', :tag => "#{s.version}", }
  
  s.requires_arc = true
  s.source_files = [
    'Sources/F53OSC/*.{h,m,swift}',
    'Sources/Vendor/CocoaAsyncSocket/*.{h,m}',
  ]
  
  s.frameworks = 'Security', 'CFNetwork'
end
