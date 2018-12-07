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
        let deviceSnapshot = DeviceSnapshot(
            advertisingIdentifier: "ad id",
            isBluetoothEnabled: true,
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
            radio: "LTE",
            isTestDevice: true,
            timeZone: "America/Toronto",
            userInfo: Attributes.init(["testField":42])
        )
        
        let archiver = NSKeyedArchiver.init(requiringSecureCoding: false)
        archiver.encodeRootObject(deviceSnapshot)
        //archiver.outputFormat = .xml
        archiver.finishEncoding()
        let archivedData = archiver.encodedData
        let dearchiver = try NSKeyedUnarchiver.init(forReadingFrom: archivedData)
        dearchiver.requiresSecureCoding = false
        dearchiver.decodingFailurePolicy = .raiseException
        let decodedDeviceSnapshot = dearchiver.decodeObject() as! DeviceSnapshot
        
        XCTAssertEqual(decodedDeviceSnapshot.advertisingIdentifier, "ad id")
        XCTAssertEqual(decodedDeviceSnapshot.isBluetoothEnabled, true)
        XCTAssertEqual(decodedDeviceSnapshot.localeLanguage, "en")
        XCTAssertEqual(decodedDeviceSnapshot.localeRegion, "en_US")
        XCTAssertEqual(decodedDeviceSnapshot.isLocationServicesEnabled, false)
        XCTAssertEqual(decodedDeviceSnapshot.localeScript, nil)
        XCTAssertEqual(decodedDeviceSnapshot.location?.coordinate.latitude, 45.0)
        XCTAssertEqual(decodedDeviceSnapshot.location?.coordinate.longitude, 24.0)
        XCTAssertEqual(decodedDeviceSnapshot.location?.altitude, 200)
        XCTAssertEqual(decodedDeviceSnapshot.location?.horizontalAccuracy, 20)
        XCTAssertEqual(decodedDeviceSnapshot.location?.verticalAccuracy, 20)
        
        // TODO: ANDREW START HERE AND FINISH COVERAGE FOR REMAINING FIELDS.  MAKE SURE THERE'S AT LEAST ONE NIL DOUBLE.
    }
    
    func testDeviceSnapshotNilValuesNSCodingRoundtrip() {
        // test that nil values carry through properly
    }
    
    func testDeviceSnapshotCodableRoundtrip() {
        
    }
}
