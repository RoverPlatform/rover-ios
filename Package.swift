// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Rover",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "RoverFoundation",
            targets: ["RoverFoundation"]),
        .library(
            name: "RoverData",
            targets: ["RoverData"]),
        .library(
            name: "RoverUI",
            targets: ["RoverUI"]),
        .library(
            name: "RoverExperiences",
            targets: ["RoverExperiences"]),
        .library(
            name: "RoverNotifications",
            targets: ["RoverNotifications"]),
        .library(
            name: "RoverLocation",
            targets: ["RoverLocation"]),
        .library(
            name: "RoverDebug",
            targets: ["RoverDebug"]),
        .library(
            name: "RoverTelephony",
            targets: ["RoverTelephony"]),
        .library(
            name: "RoverTicketmaster",
            targets: ["RoverTicketmaster"]),
        .library(
            name: "RoverSeatGeek",
            targets: ["RoverSeatGeek"]),
        .library(
            name: "RoverAdobeExperience",
            targets: ["RoverAdobeExperience"]),
        .library(
            name: "RoverAppExtensions",
            targets: ["RoverAppExtensions"]),
    ],
    dependencies: [
        .package(url:"https://github.com/weichsel/ZIPFoundation", .upToNextMinor(from: "0.9.19")),
        .package(url:"https://github.com/ticketmaster/iOS-TicketmasterSDK.git", .upToNextMinor(from: "1.7.0")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "RoverFoundation",
            dependencies: [],
            path: "Sources/Foundation",
            resources: [.copy("Resources/PrivacyInfo.xcprivacy")]),
        .target(
            name: "RoverData",
            dependencies: ["RoverFoundation"],
            path: "Sources/Data",
            resources: [.copy("Resources/PrivacyInfo.xcprivacy")]),
        .target(
            name: "RoverUI",
            dependencies: ["RoverData"],
            path: "Sources/UI",
            resources: [.copy("Resources/PrivacyInfo.xcprivacy")]),
        .target(
            name: "RoverAppExtensions",
            dependencies: ["RoverFoundation"],
            path: "Sources/AppExtensions"),
        .target(
            name: "RoverDebug",
            dependencies: ["RoverUI"],
            path: "Sources/Debug"),
        .target(
            name: "RoverExperiences",
            dependencies: ["RoverUI", "RoverFoundation", "RoverData", "ZIPFoundation"],
            path: "Sources/Experiences",
            resources: [.copy("Resources/PrivacyInfo.xcprivacy")]),
        .target(
            name: "RoverLocation",
            dependencies: ["RoverData"],
            path: "Sources/Location",
            resources: [.copy("Resources/PrivacyInfo.xcprivacy")]),
        .target(
            name: "RoverNotifications",
            dependencies: ["RoverData", "RoverUI"],
            path: "Sources/Notifications",
            resources: [.copy("Resources/PrivacyInfo.xcprivacy")]),
        .target(
            name: "RoverTelephony",
            dependencies: ["RoverData"],
            path: "Sources/Telephony",
            resources: [.copy("Resources/PrivacyInfo.xcprivacy")]),
        .target(
            name: "RoverTicketmaster",
            dependencies: [
                "RoverData",
                .product(name: "TicketmasterFoundation",
                         package: "iOS-TicketmasterSDK"),
                .product(name: "TicketmasterAuthentication",
                         package: "iOS-TicketmasterSDK"),
                .product(name: "TicketmasterSecureEntry",
                         package: "iOS-TicketmasterSDK"),
                .product(name: "TicketmasterTickets",
                         package: "iOS-TicketmasterSDK"),
                .product(name: "TicketmasterDiscoveryAPI",
                         package: "iOS-TicketmasterSDK"),
                .product(name: "TicketmasterPurchase",
                        package: "iOS-TicketmasterSDK"),
            ],
            path: "Sources/Ticketmaster",
            resources: [.copy("Resources/PrivacyInfo.xcprivacy")]),
        .target(
            name: "RoverSeatGeek",
            dependencies: ["RoverData"],
            path: "Sources/SeatGeek",
            resources: [.copy("Resources/PrivacyInfo.xcprivacy")]),
        .target(
            name: "RoverAdobeExperience",
            dependencies: ["RoverData"],
            path: "Sources/AdobeExperience",
            resources: [.copy("Resources/PrivacyInfo.xcprivacy")]),
    ]
)
