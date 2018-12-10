//
//  RoverDataTests.swift
//  RoverDataTests
//
//  Created by Sean Rucker on 2018-06-01.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import XCTest
@testable import RoverData

/// A simple test object to illustrate usage of NSCoding.
class MyThingy: NSObject, NSCoding {
    let myField: Date?
    let myBool: Bool?
    
    override init() {
        myField = Date()
        myBool = true
        super.init()
    }
    
    init(withDate date: Date?) {
        myField = date
        myBool = true
        super.init()
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(self.myField, forKey: "myField")
        aCoder.encode(self.myBool, forKey: "myBool")
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.myField = aDecoder.decodeObject(forKey: "myField") as? Date
        self.myBool = aDecoder.decodeObject(forKey: "myBool") as? Bool
    }
}

class RoverDataTests: XCTestCase {
    
    let exampleComprehensiveDevice = DeviceSnapshot(
        advertisingIdentifier: "ad id",
        isBluetoothEnabled: nil,
        localeLanguage: "en",
        localeRegion: "en_US",
        localeScript: nil,
        isLocationServicesEnabled: false,
        location: DeviceLocation.init(
            coordinate: DeviceCoordinate.init(latitude: 45.0, longitude: 24.0),
            altitude: 200,
            horizontalAccuracy: 20,
            verticalAccuracy: 20,
            address: DeviceAddress.init(
                street: "55 Adelaide St E",
                city: "Toronto",
                state: "Ontario",
                postalCode: "M2C yadda yadda",
                country: "Canada",
                isoCountryCode: "ca",
                subAdministrativeArea: "Toronto Division",
                subLocality: "Old Toronto"
            ),
            timestamp: Date.init(timeIntervalSinceReferenceDate: 0)
        ),
        locationAuthorization: "authorized",
        notificationAuthorization: "authorized",
        pushToken: DevicePushToken.init(
            value: "i am a push token beep boop",
            timestamp: Date.init(timeIntervalSinceReferenceDate: 0)
        ),
        isCellularEnabled: true,
        isWifiEnabled: false,
        appBadgeNumber: 42,
        appBuild: "69",
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
        userInfo: Attributes.init(["testField":42])
    )
    
    func verifyDecodedSnapshot(decodedDeviceSnapshot: DeviceSnapshot) {
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
        XCTAssertEqual(decodedDeviceSnapshot.location?.address?.postalCode, "M2C yadda yadda")
        XCTAssertEqual(decodedDeviceSnapshot.location?.address?.country, "Canada")
        XCTAssertEqual(decodedDeviceSnapshot.location?.address?.isoCountryCode, "ca")
        XCTAssertEqual(decodedDeviceSnapshot.location?.address?.subAdministrativeArea, "Toronto Division")
        XCTAssertEqual(decodedDeviceSnapshot.location?.address?.subLocality, "Old Toronto")
        XCTAssertEqual(decodedDeviceSnapshot.locationAuthorization, "authorized")
        XCTAssertEqual(decodedDeviceSnapshot.notificationAuthorization, "authorized")
        XCTAssertEqual(decodedDeviceSnapshot.pushToken?.value, "i am a push token beep boop")
        XCTAssertEqual(decodedDeviceSnapshot.pushToken?.timestamp, Date.init(timeIntervalSinceReferenceDate: 0))
        XCTAssertEqual(decodedDeviceSnapshot.isCellularEnabled, true)
        XCTAssertEqual(decodedDeviceSnapshot.isWifiEnabled, false)
        XCTAssertEqual(decodedDeviceSnapshot.appBadgeNumber, 42)
        XCTAssertEqual(decodedDeviceSnapshot.appBuild, "69")
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
        XCTAssertEqual((decodedDeviceSnapshot.userInfo?.rawValue["testField"]) as! Int, 42)
    }
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testAttributesCoerction() {
        let dictionary = ["thing": 42]
        let attributes = dictionary.attributes
    }
    
    func testNscodingUsage() throws {
        let thingy = MyThingy()
        let archiver = NSKeyedArchiver.init(requiringSecureCoding: false)
        archiver.encodeRootObject(thingy)
        //archiver.outputFormat = .xml
        archiver.finishEncoding()
        let archivedData = archiver.encodedData
        let dearchiver = try NSKeyedUnarchiver.init(forReadingFrom: archivedData)
        dearchiver.requiresSecureCoding = false
        dearchiver.decodingFailurePolicy = .raiseException
        XCTAssertNotNil(dearchiver.decodeObject())
    }
    
    func testDeviceSnapshotNSCodingRoundtrip() throws {
        let archiver = NSKeyedArchiver.init(requiringSecureCoding: false)
        archiver.encodeRootObject(exampleComprehensiveDevice)
        //archiver.outputFormat = .xml
        archiver.finishEncoding()
        let archivedData = archiver.encodedData
        let dearchiver = try NSKeyedUnarchiver.init(forReadingFrom: archivedData)
        dearchiver.requiresSecureCoding = false
        dearchiver.decodingFailurePolicy = .raiseException
        let decodedDeviceSnapshot = dearchiver.decodeObject() as! DeviceSnapshot
        verifyDecodedSnapshot(decodedDeviceSnapshot: decodedDeviceSnapshot)
    }
    
    func testDeviceSnapshotCodableRoundtrip() throws {
        // use JSONEncoder to test that Codable was synthesized properly.
        let json = try JSONEncoder.default.encode(exampleComprehensiveDevice)
        
        let decodedDeviceSnapshot = try JSONDecoder.default.decode(DeviceSnapshot.self, from: json)
        
        verifyDecodedSnapshot(decodedDeviceSnapshot: decodedDeviceSnapshot)
    }
}
