//
//  DeviceSnapshot.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-05-02.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

public class DeviceSnapshot: NSObject, Codable, NSCoding {
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(self.advertisingIdentifier, forKey: "advertisingIdentifier")
        aCoder.encode(self.isBluetoothEnabled, forKey: "isBluetoothEnabled")
        aCoder.encode(self.localeLanguage, forKey: "localeLanguage")
        aCoder.encode(self.localeRegion, forKey: "localeRegion")
        aCoder.encode(self.localeScript, forKey: "localeScript")
        aCoder.encode(self.isBluetoothEnabled, forKey: "isBluetoothEnabled")
        aCoder.encode(self.isBluetoothEnabled, forKey: "isBluetoothEnabled")
        aCoder.encode(self.isBluetoothEnabled, forKey: "isBluetoothEnabled")
        aCoder.encode(self.isBluetoothEnabled, forKey: "isBluetoothEnabled")

        
        // TODO: manual encodings
    }
    
    public required init?(coder aDecoder: NSCoder) {
        self.isBluetoothEnabled = aDecoder.decodeBool(forKey: "isBluetoothEnabled")
        // TODO: manual decodings
    }
    
    // TODO: manual implementation of Codable.
    
    // MARK: AdSupport
    
    public var advertisingIdentifier: String?
    
    // MARK: Bluetooth
    
    public var isBluetoothEnabled: Bool?
    
    // MARK: Locale
    
    public var localeLanguage: String?
    public var localeRegion: String?
    public var localeScript: String?

    
    public var isLocationServicesEnabled: Bool?
    public var location: DeviceLocation?
    public var locationAuthorization: String?
    
    // MARK: Notifications
    
    public var notificationAuthorization: String?
    
    // MARK: Push Token
    
    public struct PushToken: Codable, Equatable {
        public var value: String
        public var timestamp: Date
        
        public init(
            value: String,
            timestamp: Date
        ) {
            self.value = value
            self.timestamp = timestamp
        }
    }
    
    public var pushToken: PushToken?
    
    // MARK: Reachability
    
    public var isCellularEnabled: Bool?
    public var isWifiEnabled: Bool?
    
    // MARK: Static Context
    
    public enum BuildEnvironment: String, Codable, Equatable {
        case production = "PRODUCTION"
        case development = "DEVELOPMENT"
        case simulator = "SIMULATOR"
    }
    
    public var appBadgeNumber: Int?
    public var appBuild: String?
    public var appIdentifier: String?
    public var appVersion: String?
    public var buildEnvironment: BuildEnvironment?
    public var deviceIdentifier: String?
    public var deviceManufacturer: String?
    public var deviceModel: String?
    public var deviceName: String?
    public var operatingSystemName: String?
    public var operatingSystemVersion: String?
    public var screenHeight: Int?
    public var screenWidth: Int?
    public var sdkVersion: String?
    
    // MARK: Telephony
    
    public var carrierName: String?
    public var radio: String?
    
    // MARK: Testing
    
    public var isTestDevice: Bool?
    
    // MARK: Time Zone
    
    public var timeZone: String?
    
    // MARK: User Info
    
    public var userInfo: NSDictionary?
    
    public init(
        advertisingIdentifier: String? = nil,
        isBluetoothEnabled: Bool? = nil,
        localeLanguage: String? = nil,
        localeRegion: String? = nil,
        localeScript: String? = nil,
        isLocationServicesEnabled: Bool? = nil,
        location: DeviceLocation? = nil,
        locationAuthorization: String? = nil,
        notificationAuthorization: String? = nil,
        pushToken: PushToken? = nil,
        isCellularEnabled: Bool? = nil,
        isWifiEnabled: Bool? = nil,
        appBadgeNumber: Int? = nil,
        appBuild: String? = nil,
        appIdentifier: String? = nil,
        appVersion: String? = nil,
        buildEnvironment: BuildEnvironment? = nil,
        deviceIdentifier: String? = nil,
        deviceManufacturer: String? = nil,
        deviceModel: String? = nil,
        deviceName: String? = nil,
        operatingSystemName: String? = nil,
        operatingSystemVersion: String? = nil,
        screenHeight: Int? = nil,
        screenWidth: Int? = nil,
        sdkVersion: String? = nil,
        carrierName: String? = nil,
        radio: String? = nil,
        isTestDevice: Bool? = nil,
        timeZone: String? = nil,
        userInfo: NSDictionary? = nil
    ) {
        self.advertisingIdentifier = advertisingIdentifier
        self.isBluetoothEnabled = isBluetoothEnabled
        self.localeLanguage = localeLanguage
        self.localeRegion = localeRegion
        self.localeScript = localeScript
        self.isLocationServicesEnabled = isLocationServicesEnabled
        self.location = location
        self.locationAuthorization = locationAuthorization
        self.notificationAuthorization = notificationAuthorization
        self.pushToken = pushToken
        self.isCellularEnabled = isCellularEnabled
        self.isWifiEnabled = isWifiEnabled
        self.appBadgeNumber = appBadgeNumber
        self.appBuild = appBuild
        self.appIdentifier = appIdentifier
        self.appVersion = appVersion
        self.buildEnvironment = buildEnvironment
        self.deviceIdentifier = deviceIdentifier
        self.deviceManufacturer = deviceManufacturer
        self.deviceModel = deviceModel
        self.deviceName = deviceName
        self.operatingSystemName = operatingSystemName
        self.operatingSystemVersion = operatingSystemVersion
        self.screenHeight = screenHeight
        self.screenWidth = screenWidth
        self.sdkVersion = sdkVersion
        self.carrierName = carrierName
        self.radio = radio
        self.isTestDevice = isTestDevice
        self.timeZone = timeZone
        self.userInfo = userInfo
    }
}

// MARK: Location

public class DeviceCoordinate: NSObject, Codable, NSCoding {
    public var latitude: Double
    public var longitude: Double
    
    // TODO: NSCoding implementation
    
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let latitude = try container.decode(Double.self)
        let longitude = try container.decode(Double.self)
        self.init(latitude: latitude, longitude: longitude)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(latitude)
        try container.encode(longitude)
    }
}

public class DeviceLocation: Codable, NSCoding {
    public var coordinate: DeviceCoordinate
    public var altitude: Double
    public var horizontalAccuracy: Double
    public var verticalAccuracy: Double
    public var address: DeviceAddress?
    public var timestamp: Date
    
    public init(
        coordinate: DeviceCoordinate,
        altitude: Double,
        horizontalAccuracy: Double,
        verticalAccuracy: Double,
        address: DeviceAddress?,
        timestamp: Date
        ) {
        self.coordinate = coordinate
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
        self.verticalAccuracy = verticalAccuracy
        self.address = address
        self.timestamp = timestamp
    }
}

    
public class DeviceAddress: Codable, NSCoding {
    public var street: String?
    public var city: String?
    public var state: String?
    public var postalCode: String?
    public var country: String?
    public var isoCountryCode: String?
    public var subAdministrativeArea: String?
    public var subLocality: String?
    
    public init(
        street: String?,
        city: String?,
        state: String?,
        postalCode: String?,
        country: String?,
        isoCountryCode: String?,
        subAdministrativeArea: String?,
        subLocality: String?
        ) {
        self.street = street
        self.city = city
        self.state = state
        self.postalCode = postalCode
        self.country = country
        self.isoCountryCode = isoCountryCode
        self.subAdministrativeArea = subAdministrativeArea
        self.subLocality = subLocality
    }
}
