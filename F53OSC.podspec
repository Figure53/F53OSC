Pod::Spec.new do |s|
  s.name         = "F53OSC"
  s.version      = "1.0.0"
  s.summary      = "A nice open source OSC library for Objective-C."

  s.description  = <<-DESC
                    * Hey neat, it's a nice open source OSC library for Objective-C.

                    * From your friends at Figure 53.

                    * For convenience, we've included a few public domain source files from CocoaAsyncSocket. But appropriate thanks, kudos, and curiosity about that code should be directed to the source.

                   * Think: Why did you write this? What is the focus? What does it do?
                   * CocoaPods will be using this to generate tags, and improve search results.
                   * Try to keep it short, snappy and to the point.
                   * Finally, don't worry about the indent, CocoaPods strips it!
                   DESC

  s.author       = "Figure53" 
  s.homepage     = "http://figure53.com/code/"

  s.license      = { :type => "BSD-like", :file => "LICENSE.txt" }

  s.social_media_url   = "https://twitter.com/figure53"

  s.source       = { :git => "https://github.com/Figure53/F53OSC.git", :tag => "v1.0.0" }
 
  s.source_files = '*.{h,m}'
  s.requires_arc = false

  s.exclude_files = "GCDAsync*.{h,m}"
  s.subspec 'arc' do |as|
    as.source_files = "GCDAsync*.{h,m}"
    as.requires_arc = true
  end
    
  s.frameworks = "Security", "CFNetwork"
end
