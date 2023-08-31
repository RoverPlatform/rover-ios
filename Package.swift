// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Rover",
    defaultLocalization: "en",
    platforms: [.iOS(.v13)],
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
            name: "RoverSeatGeek",
            targets: ["RoverSeatGeek"]),
        .library(
            name: "RoverAppExtensions",
            targets: ["RoverAppExtensions"]),
    ],
    dependencies: [
        .package(url: "https://github.com/WeTransfer/Mocker", .upToNextMajor(from: "3.0.1")),
        .package(url:"https://github.com/weichsel/ZIPFoundation", .upToNextMinor(from: "0.9.16"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "RoverFoundation",
            dependencies: [],
            path: "Sources/Foundation"),
        .target(
            name: "RoverData",
            dependencies: ["RoverFoundation"],
            path: "Sources/Data"),
        .target(
            name: "RoverUI",
            dependencies: ["RoverData"],
            path: "Sources/UI"),
        .target(
            name: "RoverAdSupport",
            dependencies: ["RoverData"],
            path: "Sources/AdSupport"),
        .target(
            name: "RoverAppExtensions",
            dependencies: ["RoverFoundation"],
            path: "Sources/AppExtensions"),
        .target(
            name: "RoverBluetooth",
            dependencies: ["RoverData"],
            path: "Sources/Bluetooth"),
        .target(
            name: "RoverDebug",
            dependencies: ["RoverUI"],
            path: "Sources/Debug"),
        .target(
            name: "RoverExperiences",
            dependencies: ["RoverUI", "RoverFoundation", "RoverData", "ZIPFoundation"],
            path: "Sources/Experiences"),
        .target(
            name: "RoverLocation",
            dependencies: ["RoverData"],
            path: "Sources/Location"),
        .target(
            name: "RoverNotifications",
            dependencies: ["RoverData", "RoverUI"],
            path: "Sources/Notifications"),
        .target(
            name: "RoverTelephony",
            dependencies: ["RoverData"],
            path: "Sources/Telephony"),
        .target(
            name: "RoverTicketmaster",
            dependencies: ["RoverData"],
            path: "Sources/Ticketmaster"),
        .target(
            name: "RoverSeatGeek",
            dependencies: ["RoverData"],
            path: "Sources/SeatGeek")
    ]
)
