#
# Be sure to run `pod lib lint Rover.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "Rover"
  s.version          = "0.1.0"
  s.summary          = "A short description of Rover."

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!  
  s.description      = <<-DESC
                        Rover SDK
                       DESC

  s.homepage         = "https://github.com/<GITHUB_USERNAME>/Rover"
  # s.screenshots     = "www.example.com/screenshots_1", "www.example.com/screenshots_2"
  s.license          = 'MIT'
  s.author           = { "ata_n" => "ata.namvari@gmail.com" }
  s.source           = { :git => "https://github.com/<GITHUB_USERNAME>/Rover.git", :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.platform     = :ios, '8.0'
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
