// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RoverCampaigns",
    platforms: [.iOS(SupportedPlatform.IOSVersion.v10)],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
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
            name: "RoverBluetooth",
            targets: ["RoverBluetooth"]),
        .library(
            name: "RoverDebug",
            targets: ["RoverDebug"]),
        .library(
            name: "RoverTelephony",
            targets: ["RoverTelephony"]),
        .library(
            name: "RoverAdSupport",
            targets: ["RoverAdSupport"]),
        .library(
            name: "RoverTicketmaster",
            targets: ["RoverTicketmaster"]),
        .library(
            name: "RoverAppExtensions",
            targets: ["RoverAppExtensions"]),
    ],
    dependencies: [
        .package(url: "https://github.com/RoverPlatform/rover-ios", from: "3.9.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "RoverFoundation",
            dependencies: [],
            path: "Sources/Foundation",
            exclude: ["Info.plist"]),
        .target(
            name: "RoverData",
            dependencies: ["RoverFoundation"],
            path: "Sources/Data",
            exclude: ["Info.plist"]),
        .target(
            name: "RoverUI",
            dependencies: ["RoverData"],
            path: "Sources/UI",
            exclude: ["Info.plist"]),
        .target(
            name: "RoverAdSupport",
            dependencies: ["RoverData"],
            path: "Sources/AdSupport",
            exclude: ["Info.plist"]),
        .target(
            name: "RoverAppExtensions",
            dependencies: ["RoverFoundation"],
            path: "Sources/AppExtensions",
            exclude: ["Info.plist"]),
        .target(
            name: "RoverBluetooth",
            dependencies: ["RoverData"],
            path: "Sources/Bluetooth",
            exclude: ["Info.plist"]),
        .target(
            name: "RoverDebug",
            dependencies: ["RoverUI"],
            path: "Sources/Debug",
            exclude: ["Info.plist"]),
        .target(
            name: "RoverExperiences",
            dependencies: ["RoverUI", .product(name: "Rover", package: "rover-ios")],
            path: "Sources/Experiences",
            exclude: ["Info.plist"]),
        .target(
            name: "RoverLocation",
            dependencies: ["RoverData"],
            path: "Sources/Location",
            exclude: ["Info.plist"]),
        .target(
            name: "RoverNotifications",
            dependencies: ["RoverUI"],
            path: "Sources/Notifications",
            exclude: ["Info.plist"]),
        .target(
            name: "RoverTelephony",
            dependencies: ["RoverData"],
            path: "Sources/Telephony",
            exclude: ["Info.plist"]),
        .target(
            name: "RoverTicketmaster",
            dependencies: ["RoverData"],
            path: "Sources/Ticketmaster",
            exclude: ["Info.plist"])
    ]
)
