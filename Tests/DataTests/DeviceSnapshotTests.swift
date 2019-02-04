//
//  DeviceSnapshotTests.swift
//  RoverDataTests
//
//  Created by Andrew Clunis on 2018-12-10.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

@testable import RoverData
import XCTest

class DeviceSnapshotTests: XCTestCase {
    let exampleComprehensiveDevice = DeviceSnapshot(
        advertisingIdentifier: "ad id",
        isBluetoothEnabled: nil,
        localeLanguage: "en",
        localeRegion: "en_US",
        localeScript: nil,
        isLocationServicesEnabled: false,
        location: LocationSnapshot(
            coordinate: CoordinateSnapshot(latitude: 45.0, longitude: 24.0),
            altitude: 200,
            horizontalAccuracy: 20,
            verticalAccuracy: 20,
            address: AddressSnapshot(
                street: "55 Adelaide St E",
                city: "Toronto",
                state: "Ontario",
                postalCode: "M5C 1K6",
                country: "Canada",
                isoCountryCode: "ca",
                subAdministrativeArea: "Toronto Division",
                subLocality: "Old Toronto"
            ),
            timestamp: Date(timeIntervalSinceReferenceDate: 0)
        ),
        locationAuthorization: "authorized",
        notificationAuthorization: "authorized",
        pushToken: PushTokenSnapshot(
            value: "push token",
            timestamp: Date(timeIntervalSinceReferenceDate: 0)
        ),
        isCellularEnabled: true,
        isWifiEnabled: false,
        appBadgeNumber: 42,
        appBuild: "42",
        appIdentifier: "io.rover.tests",
        appVersion: "1.0.0",
        buildEnvironment: BuildEnvironment.development,
        deviceIdentifier: "F33EDA3D-A0CC-4CD4-A431-4972D170F72D",
        deviceManufacturer: "Fruit Company",
        deviceModel: "Bananaphone",
        deviceName: "Sean's Bananaphone",
        operatingSystemName: "Android",
        operatingSystemVersion: "9.0",
        screenHeight: 800,
        screenWidth: 480,
        sdkVersion: "2.2.3",
        carrierName: "Bell",
        radio: nil,
        isTestDevice: true,
        timeZone: "America/Toronto",
        userInfo: Attributes(
            rawValue: [
                "testInt": 42,
                "anArray": [1, 2, 3, 4],
                "testTrueBoolean": true,
                "testString": "donut",
                "testFalseBoolean": false,
                "nestedObject": ["anArray": [1, 2, 3, 4]]
            ]
        )
    )
    
    func verifyDecodedSnapshot(decodedDeviceSnapshot: DeviceSnapshot) {
        // use XCTAssertEqual for all matchers to make it read better.
        // swiftlint:disable xct_specific_matcher
        XCTAssertEqual(decodedDeviceSnapshot.advertisingIdentifier, "ad id")
        XCTAssertEqual(decodedDeviceSnapshot.isBluetoothEnabled, nil)
        XCTAssertEqual(decodedDeviceSnapshot.localeLanguage, "en")
        XCTAssertEqual(decodedDeviceSnapshot.localeRegion, "en_US")
        XCTAssertEqual(decodedDeviceSnapshot.isLocationServicesEnabled, false)
        XCTAssertEqual(decodedDeviceSnapshot.localeScript, nil)
        XCTAssertEqual(decodedDeviceSnapshot.location?.coordinate.latitude, 45.0)
        XCTAssertEqual(decodedDeviceSnapshot.location?.coordinate.longitude, 24.0)
        XCTAssertEqual(decodedDeviceSnapshot.location?.altitude, 200)
        XCTAssertEqual(decodedDeviceSnapshot.location?.horizontalAccuracy, 20)
        XCTAssertEqual(decodedDeviceSnapshot.location?.verticalAccuracy, 20)
        XCTAssertEqual(decodedDeviceSnapshot.location?.address?.city, "Toronto")
        XCTAssertEqual(decodedDeviceSnapshot.location?.address?.street, "55 Adelaide St E")
        XCTAssertEqual(decodedDeviceSnapshot.location?.address?.state, "Ontario")
        XCTAssertEqual(decodedDeviceSnapshot.location?.address?.postalCode, "M5C 1K6")
        XCTAssertEqual(decodedDeviceSnapshot.location?.address?.country, "Canada")
        XCTAssertEqual(decodedDeviceSnapshot.location?.address?.isoCountryCode, "ca")
        XCTAssertEqual(decodedDeviceSnapshot.location?.address?.subAdministrativeArea, "Toronto Division")
        XCTAssertEqual(decodedDeviceSnapshot.location?.address?.subLocality, "Old Toronto")
        XCTAssertEqual(decodedDeviceSnapshot.locationAuthorization, "authorized")
        XCTAssertEqual(decodedDeviceSnapshot.notificationAuthorization, "authorized")
        XCTAssertEqual(decodedDeviceSnapshot.pushToken?.value, "push token")
        XCTAssertEqual(decodedDeviceSnapshot.pushToken?.timestamp, Date(timeIntervalSinceReferenceDate: 0))
        XCTAssertEqual(decodedDeviceSnapshot.isCellularEnabled, true)
        XCTAssertEqual(decodedDeviceSnapshot.isWifiEnabled, false)
        XCTAssertEqual(decodedDeviceSnapshot.appBadgeNumber, 42)
        XCTAssertEqual(decodedDeviceSnapshot.appBuild, "42")
        XCTAssertEqual(decodedDeviceSnapshot.appIdentifier, "io.rover.tests")
        XCTAssertEqual(decodedDeviceSnapshot.appVersion, "1.0.0")
        XCTAssertEqual(decodedDeviceSnapshot.buildEnvironment, .development)
        XCTAssertEqual(decodedDeviceSnapshot.deviceIdentifier, "F33EDA3D-A0CC-4CD4-A431-4972D170F72D")
        XCTAssertEqual(decodedDeviceSnapshot.deviceModel, "Bananaphone")
        XCTAssertEqual(decodedDeviceSnapshot.deviceName, "Sean's Bananaphone")
        XCTAssertEqual(decodedDeviceSnapshot.operatingSystemName, "Android")
        XCTAssertEqual(decodedDeviceSnapshot.operatingSystemVersion, "9.0")
        XCTAssertEqual(decodedDeviceSnapshot.screenWidth, 480)
        XCTAssertEqual(decodedDeviceSnapshot.screenHeight, 800)
        XCTAssertEqual(decodedDeviceSnapshot.sdkVersion, "2.2.3")
        XCTAssertEqual(decodedDeviceSnapshot.carrierName, "Bell")
        XCTAssertEqual(decodedDeviceSnapshot.radio, nil)
        XCTAssertEqual(decodedDeviceSnapshot.isTestDevice, true)
        XCTAssertEqual(decodedDeviceSnapshot.timeZone, "America/Toronto")
        XCTAssertEqual((decodedDeviceSnapshot.userInfo?.rawValue["testInt"]) as! Int, 42)
        XCTAssertEqual((decodedDeviceSnapshot.userInfo?.rawValue["anArray"]) as! [Int], [1, 2, 3, 4])
        XCTAssertEqual((decodedDeviceSnapshot.userInfo?.rawValue["testTrueBoolean"]) as! Bool, true)
        XCTAssertEqual((decodedDeviceSnapshot.userInfo?.rawValue["testString"]) as! String, "donut")
        XCTAssertEqual((decodedDeviceSnapshot.userInfo?.rawValue["testFalseBoolean"]) as! Bool, false)
        XCTAssertEqual(((decodedDeviceSnapshot.userInfo?.rawValue["nestedObject"]) as! Attributes).rawValue["anArray"] as! [Int], [1, 2, 3, 4])
        // swiftlint:enable xct_specific_matcher
    }
    
    func testDeviceSnapshotNSCodingRoundtrip() throws {
        let archiver = NSKeyedArchiver(requiringSecureCoding: false)
        archiver.encodeRootObject(exampleComprehensiveDevice)
        //archiver.outputFormat = .xml
        archiver.finishEncoding()
        let archivedData = archiver.encodedData
        let dearchiver = try NSKeyedUnarchiver(forReadingFrom: archivedData)
        dearchiver.requiresSecureCoding = false
        dearchiver.decodingFailurePolicy = .raiseException
        let decodedDeviceSnapshot = dearchiver.decodeObject() as! DeviceSnapshot
        verifyDecodedSnapshot(decodedDeviceSnapshot: decodedDeviceSnapshot)
    }
    
    func testDeviceSnapshotCodableRoundtrip() throws {
        // use JSONEncoder to test that Codable was synthesized properly.
        let json = try JSONEncoder.default.encode(exampleComprehensiveDevice)
        
        do {
            let decodedDeviceSnapshot = try JSONDecoder.default.decode(DeviceSnapshot.self, from: json)
            
            verifyDecodedSnapshot(decodedDeviceSnapshot: decodedDeviceSnapshot)
        } catch {
            // Print the error so the all-important UserInfo is captured:
            print("Error decoding device: \(error)")
            throw error
        }
    }
}
