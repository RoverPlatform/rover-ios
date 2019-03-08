Pod::Spec.new do |s|
  s.name              = "Rover"
  s.module_name       = "RoverKit"
  s.version           = "3.0"
  s.summary           = "iOS framework for the Rover platform"
  s.homepage          = "https://www.rover.io"
  s.license           = "Apache License, Version 2.0"
  s.author            = { "Rover Labs Inc." => "support@rover.io" }
  s.platform          = :ios, "10.0"
  s.source            = { :git => "https://github.com/RoverPlatform/rover-ios.git", :tag => "v#{s.version}" }
  s.cocoapods_version = ">= 1.4.0"
  s.default_subspec   = "Core"

  s.subspec "Core" do |ss|
    ss.dependency "Rover/Experiences"
    ss.dependency "Rover/Notifications"
    ss.dependency "Rover/Location"
    ss.dependency "Rover/Debug"
  end

  s.subspec "Foundation" do |ss|
    ss.source_files = "Sources/Foundation/**/*.swift"
    ss.frameworks = "Foundation"
  end

  s.subspec "Data" do |ss|
    ss.source_files = "Sources/Data/**/*.swift"
    ss.dependency "Rover/Foundation"
    ss.frameworks = "SystemConfiguration", "UIKit"
  end

  s.subspec "UI" do |ss|
    ss.source_files = "Sources/UI/**/*.swift"
    ss.dependency "Rover/Data"
    ss.frameworks = "SafariServices"
  end

  s.subspec "Experiences" do |ss|
    ss.source_files = "Sources/Experiences/**/*.swift"
    ss.dependency "Rover/UI"
    ss.frameworks = "WebKit"
  end

  s.subspec "Debug" do |ss|
    ss.source_files = "Sources/Debug/**/*.swift"
    ss.dependency "Rover/UI"
  end
end
