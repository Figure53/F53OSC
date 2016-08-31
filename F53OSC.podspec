Pod::Spec.new do |s|
  s.name         = 'F53OSC'
  s.version      = '1.0.1'
  s.summary      = 'A nice open source OSC library for Objective-C.'

  s.description  = <<-DESC
                    * Hey neat, it's a nice open source OSC library for Objective-C.

                    * From your friends at Figure 53.

                    * For convenience, we've included a few public domain source files from CocoaAsyncSocket. But appropriate thanks, kudos, and curiosity about that code should be directed to the source.
                   DESC

  s.author       = 'Figure 53, LLC'
  s.homepage     = 'http://figure53.com/code/'

  s.license      = { :type => 'BSD-like', :file => 'LICENSE.txt' }

  s.social_media_url   = 'https://twitter.com/figure53'
  
  s.platforms     = { :ios => '8.4' }
  s.source        = { :git => 'https://github.com/Figure53/F53OSC.git', :tag => 'v1.0.1' }
    
  
  s.source_files = '*.{h,m}'
  s.requires_arc = true
  
  s.ios.exclude_files = 'F53OSC Monitor/*'
  s.tvos.exclude_files = 'F53OSC Monitor/*'
    
  s.frameworks = 'Security', 'CFNetwork'
end
