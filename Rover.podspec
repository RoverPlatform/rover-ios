Pod::Spec.new do |s|
  s.name              = "Rover"
  s.version           = "2.0.0-beta.3"
  s.summary           = "iOS framework for the Rover platform"
  s.homepage          = "https://www.rover.io"
  s.license           = "Apache License, Version 2.0"
  s.author            = { "Rover Labs Inc." => "support@rover.io" }
  s.platform          = :ios, "10.0"
  s.source            = { :git => "https://github.com/RoverPlatform/rover-ios.git", :tag => "v#{s.version}" }
  s.swift_version     = "4.1"
  s.cocoapods_version = ">= 1.4.0"

  s.subspec "RoverFoundation" do |fs|
    fs.source_files = "Sources/Foundation/**/*.swift"
    fs.frameworks = "Foundation"
  end

  s.subspec "RoverData" do |ds|
    ds.source_files = "Sources/Data/**/*.swift"
    ds.dependency "Rover/RoverFoundation"
    ds.frameworks = "SystemConfiguration", "UIKit"
  end

  s.subspec "RoverUI" do |us|
    us.source_files = "Sources/UI/**/*.swift"
    us.dependency "Rover/RoverData"
    us.frameworks = "SafariServices"
  end

  s.subspec "RoverExperiences" do |es|
    es.source_files = "Sources/Experiences/**/*.swift"
    es.dependency "Rover/RoverUI"
    es.frameworks = "WebKit"
  end

  s.subspec "RoverNotifications" do |ns|
    ns.source_files = "Sources/Notifications/**/*.swift"
    ns.dependency "Rover/RoverUI"
    ns.frameworks = "UserNotifications"
  end

  s.subspec "RoverLocation" do |ls|
    ls.source_files = "Sources/Location/**/*.swift"
    ls.dependency "Rover/RoverData"
    ls.frameworks = "CoreLocation"
  end

  s.subspec "RoverBluetooth" do |bs|
    bs.source_files = "Sources/Bluetooth/**/*.swift"
    bs.dependency "Rover/RoverData"
    bs.frameworks = "CoreBluetooth"
  end

  s.subspec "RoverDebug" do |ds|
    ds.source_files = "Sources/Debug/**/*.swift"
    ds.dependency "Rover/RoverUI"
  end
end
