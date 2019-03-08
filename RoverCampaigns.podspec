Pod::Spec.new do |s|
  s.name              = "RoverCampaigns"
  s.module_name       = "RoverCampaignsKit"
  s.version           = "3.0.0"
  s.summary           = "iOS framework for the Rover Campaigns app"
  s.homepage          = "https://www.rover.io"
  s.license           = "Apache License, Version 2.0"
  s.author            = { "Rover Labs Inc." => "support@rover.io" }
  s.platform          = :ios, "10.0"
  s.source            = { :git => "https://github.com/RoverPlatform/rover-ios.git", :tag => "v#{s.version}" }
  s.cocoapods_version = ">= 1.4.0"
  s.default_subspec   = "Core"

  s.subspec "Core" do |ss|
    ss.dependency "RoverCampaigns/Experiences"
    ss.dependency "RoverCampaigns/Notifications"
    ss.dependency "RoverCampaigns/Location"
    ss.dependency "RoverCampaigns/Debug"
  end

  s.subspec "Foundation" do |ss|
    ss.source_files = "Sources/Foundation/**/*.swift"
    ss.frameworks = "Foundation"
  end

  s.subspec "Data" do |ss|
    ss.source_files = "Sources/Data/**/*.swift"
    ss.dependency "RoverCampaigns/Foundation"
    ss.frameworks = "SystemConfiguration", "UIKit"
  end

  s.subspec "UI" do |ss|
    ss.source_files = "Sources/UI/**/*.swift"
    ss.dependency "RoverCampaigns/Data"
    ss.frameworks = "SafariServices"
  end

  s.subspec "Notifications" do |ss|
    ss.source_files = "Sources/Notifications/**/*.swift"
    ss.dependency "RoverCampaigns/UI"
    ss.frameworks = "UserNotifications"
  end

  s.subspec "Location" do |ss|
    ss.source_files = "Sources/Location/**/*.swift"
    ss.resources = "Sources/Location/Model/RoverLocation.xcdatamodeld"
    ss.dependency "RoverCampaigns/Data"
    ss.frameworks = "CoreLocation"
  end

  s.subspec "Bluetooth" do |ss|
    ss.source_files = "Sources/Bluetooth/**/*.swift"
    ss.dependency "RoverCampaigns/Data"
    ss.frameworks = "CoreBluetooth"
  end

  s.subspec "Debug" do |ss|
    ss.source_files = "Sources/Debug/**/*.swift"
    ss.dependency "RoverCampaigns/UI"
  end

  s.subspec "Telephony" do |ss|
    ss.source_files = "Sources/Telephony/**/*.swift"
    ss.dependency "RoverCampaigns/Data"
    ss.frameworks = "CoreTelephony"
  end

  s.subspec "AdSupport" do |ss|
    ss.source_files = "Sources/AdSupport/**/*.swift"
    ss.dependency "RoverCampaigns/Data"
    ss.frameworks = "AdSupport"
  end

  s.subspec "Ticketmaster" do |ss|
    ss.source_files = "Sources/Ticketmaster/**/*.swift"
    ss.dependency "RoverCampaigns/Data"
  end
end
