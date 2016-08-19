Pod::Spec.new do |s|
  s.name             = "Rover"
  s.version          = "0.0.1"
  s.summary          = "Rover iOS SDK for using the Rover platform."
  s.description      = <<-DESC
                       	The Rover iOS SDK enables proximity, location based and scheduled messaging via the Rover platform.
			Requires an account with [www.rover.io](http://www.rover.io)
                       DESC

  s.homepage         = "https://github.com/RoverPlatform/rover-ios"
  # s.screenshots     = "www.example.com/screenshots_1", "www.example.com/screenshots_2"
  s.license          = 'MIT'
  s.author           = { "Ata N" => "ata@rover.io" }
  s.source           = { :git => "https://github.com/RoverPlatform/rover-ios.git", :tag => s.version.to_s }

  s.platform     = :ios, '8.4'
  s.requires_arc = true

  s.source_files = 'Pod/Classes/**/*'
  s.resources = ['Pod/Resources/**/*.xcdatamodeld']
  s.resource_bundles = {
    'Rover' => ['Pod/Assets/*.png']
  }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  
  s.frameworks = 'UIKit', 'CoreLocation'

#  s.subspec 'Network' do |ss|
#    ss.source_files = 'Pod/Classes/Network/**/*'
#  end

#  s.subspec 'Model' do |ss|
#    ss.source_files = 'Pod/Classes/Model/**/*'
#  end

#  s.subspec 'Common' do |ss|
#    ss.source_files = 'Pod/Classes/Common/**/*'
#  end

#  s.subspec 'UI' do |ss|
#   ss.source_files = 'Pod/Classes/UI/**/*'
#  end

end
