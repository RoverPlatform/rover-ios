Pod::Spec.new do |s|
  s.name              = "Rover"
  s.version           = "4.0.0"
  s.summary           = "iOS framework for the Rover platform"
  s.homepage          = "https://www.rover.io"
  s.license           = "Apache License, Version 2.0"
  s.author            = { "Rover Labs Inc." => "support@rover.io" }
  s.platform          = :ios, "10.0"
  s.swift_versions    = ["5.5", "5.4", "5.3", "5.2", "5.1", "5.0"]
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
    ss.dependency "Rover/Data"
    ss.frameworks = "SafariServices", "WebKit"
  end

  s.subspec "Notifications" do |ss|
    ss.source_files = "Sources/Notifications/**/*.swift"
    ss.dependency "Rover/UI"
    ss.frameworks = "UserNotifications"
  end

  s.subspec "Location" do |ss|
    ss.source_files = "Sources/Location/**/*.swift"
    ss.resources = "Sources/Location/Model/RoverLocation.xcdatamodeld"
    ss.dependency "Rover/Data"
    ss.frameworks = "CoreLocation"
  end

  s.subspec "Bluetooth" do |ss|
    ss.source_files = "Sources/Bluetooth/**/*.swift"
    ss.dependency "Rover/Data"
    ss.frameworks = "CoreBluetooth"
  end

  s.subspec "Debug" do |ss|
    ss.source_files = "Sources/Debug/**/*.swift"
    ss.dependency "Rover/UI"
  end

  s.subspec "Telephony" do |ss|
    ss.source_files = "Sources/Telephony/**/*.swift"
    ss.dependency "Rover/Data"
    ss.frameworks = "CoreTelephony"
  end

  s.subspec "AdSupport" do |ss|
    ss.source_files = "Sources/AdSupport/**/*.swift"
    ss.dependency "Rover/Data"
    ss.frameworks = "AdSupport"
  end

  s.subspec "Ticketmaster" do |ss|
    ss.source_files = "Sources/Ticketmaster/**/*.swift"
    ss.dependency "Rover/Data"
  end
end
