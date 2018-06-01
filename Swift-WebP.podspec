Pod::Spec.new do |s|
  s.name = 'Swift-WebP'
  s.version = '0.0.5'
  s.license = { :type => 'MIT', :file => 'LICENSE' }
  s.summary = 'Very thin libwebp wrapper written by Swift'

  # This description is used to generate tags and improve search results.
  #   * Think: What does it do? Why did you write it? What is the focus?
  #   * Try to keep it short, snappy and to the point.
  #   * Write the description between the DESC delimiters below.
  #   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description = <<-DESC
  *Currently this pod is very experimental phase.*
  This is the library that allows you to easily use libwebp for both encoding and decoding from Swift.
  DESC

  s.homepage = 'https://github.com/ainame/Swift-WebP'
  s.authors = { 'ainame' => 's.namai.09@gmail.com' }
  s.source = { :git => 'https://github.com/ainame/Swift-WebP.git', :tag => s.version }
  s.ios.deployment_target = '8.0'
  s.source_files = 'Sources/*.{h,swift}'
end
