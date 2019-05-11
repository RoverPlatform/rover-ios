Pod::Spec.new do |s|
  s.name              = "Rover"
  s.version           = "3.0.0-beta.1"
  s.summary           = "iOS framework for the Rover platform"
  s.homepage          = "https://www.rover.io"
  s.license           = "Apache License, Version 2.0"
  s.author            = { "Rover Labs Inc." => "support@rover.io" }
  s.platform          = :ios, "10.0"
  s.source            = { :git => "https://github.com/RoverPlatform/rover-ios.git", :tag => "v#{s.version}" }
  s.cocoapods_version = ">= 1.4.0"
  s.swift_version     = "5.0"
  s.source_files      = "Sources/**/*.swift"
  s.frameworks        = "SafariServices", "WebKit"
end
