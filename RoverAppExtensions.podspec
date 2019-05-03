Pod::Spec.new do |s|
  s.name              = "RoverAppExtensions"
  s.version           = "2.4.1"
  s.summary           = "Rover iOS App Extensions"
  s.homepage          = "https://www.rover.io"
  s.license           = "Apache License, Version 2.0"
  s.author            = { "Rover Labs Inc." => "support@rover.io" }
  s.platform          = :ios, "10.0"
  s.source            = { :git => "https://github.com/RoverPlatform/rover-ios.git", :tag => "v#{s.version}" }
  s.cocoapods_version = ">= 1.4.0"
  s.source_files      = "Sources/Foundation/**/*.swift", "Sources/AppExtensions/**/*.swift"
  s.frameworks        = "MobileCoreServices", "UserNotifications"
end
