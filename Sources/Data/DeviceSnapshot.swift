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
        //
        aCoder.encode(self.advertisingIdentifier, forKey: "advertisingIdentifier")
        aCoder.encode(self.isBluetoothEnabled, forKey: "isBluetoothEnabled")
        aCoder.encode(self.localeLanguage, forKey: "localeLanguage")
        aCoder.encode(self.localeRegion, forKey: "localeRegion")
        aCoder.encode(self.localeScript, forKey: "localeScript")
        aCoder.encode(self.isLocationServicesEnabled, forKey: "isLocationServicesEnabled")
        aCoder.encode(self.location, forKey: "location")
        aCoder.encode(self.locationAuthorization, forKey: "locationAuthorization")
        aCoder.encode(self.notificationAuthorization, forKey: "notificationAuthorization")
        aCoder.encode(self.isBluetoothEnabled, forKey: "isBluetoothEnabled")
        aCoder.encode(self.pushToken, forKey: "pushToken")
        aCoder.encode(self.isCellularEnabled, forKey: "isCellularEnabled")
        aCoder.encode(self.isWifiEnabled, forKey: "isWifiEnabled")
        aCoder.encode(self.appBadgeNumber, forKey: "appBadgeNumber")
        aCoder.encode(self.appBuild, forKey: "appBuild")
        aCoder.encode(self.appIdentifier, forKey: "appIdentifier")
        aCoder.encode(self.appVersion, forKey: "appVersion")
        aCoder.encode(self.buildEnvironment, forKey: "buildEnvironment")
        aCoder.encode(self.deviceIdentifier, forKey: "deviceIdentifier")
        aCoder.encode(self.deviceManufacturer, forKey: "deviceManufacturer")
        aCoder.encode(self.deviceModel, forKey: "deviceModel")
        aCoder.encode(self.deviceName, forKey: "deviceName")
        aCoder.encode(self.operatingSystemName, forKey: "operatingSystemName")
        aCoder.encode(self.operatingSystemVersion, forKey: "operatingSystemVersion")
        aCoder.encode(self.screenHeight, forKey: "screenHeight")
        aCoder.encode(self.screenWidth, forKey: "screenWidth")
        aCoder.encode(self.sdkVersion, forKey: "sdkVersion")
        aCoder.encode(self.carrierName, forKey: "carrierName")
        aCoder.encode(self.radio, forKey: "radio")
        aCoder.encode(self.isTestDevice, forKey: "isTestDevice")
        aCoder.encode(self.timeZone, forKey: "timeZone")
        aCoder.encode(self.userInfo, forKey: "userInfo")
    }
    
    public required init?(coder aDecoder: NSCoder) {
        // we must implement Decodable manually because the NSDictionary field used for Attributes (which itself was used in lieu of Swift Dictionary in order to enable NSCoding) prevents Codable being synthesized.
        
        
        self.isBluetoothEnabled = aDecoder.decodeBool(forKey: "isBluetoothEnabled")
        // TODO: manual decodings
    }
    
    public required init(from decoder: Decoder) throws {
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.advertisingIdentifier = try container.decode(String.self, forKey: .advertisingIdentifier)
        self.isBluetoothEnabled = try container.decode(Bool.self, forKey: .isBluetoothEnabled)
        // TODO: manual decodings
    }
    
    public func encode(to encoder: Encoder) throws {
        // TODO: manual encodings
    }
    
    // TODO: ripout
    enum CodingKeys : String, CodingKey {
        case advertisingIdentifier
        case isBluetoothEnabled
        case localeLanguage
        case localeRegion
        case localeScript
        case isLocationServicesEnabled
        case location
        case locationAuthorization
        case notificationAuthorization
        case pushToken
        case isCellularEnabled
        case isWifiEnabled
        case appBadgeNumber
        case appBuild
        case appIdentifier
        case appVersion
        case buildEnvironment
        case deviceIdentifier
        case deviceManufacturer
        case deviceModel
        case deviceName
        case operatingSystemName
        case operatingSystemVersion
        case screenHeight
        case screenWidth
        case sdkVersion
        case carrierName
        case radio
        case isTestDevice
        case timeZone
        case userInfo
    }
    
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
    
    public var pushToken: DevicePushToken?
    
    // MARK: Reachability
    
    public var isCellularEnabled: Bool?
    public var isWifiEnabled: Bool?
    
    // MARK: Static Context
    
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
    
    // As Rover Attributes, with all of the constraints thereof implied.
    // This is using NSDictionary in lieu of Swift Dictionary in order to enable
    // public var userInfo: NSDictionary?
    public var userInfo: Attributes?
    
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
        pushToken: DevicePushToken? = nil,
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
        userInfo: Attributes? = nil
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

// MARK: Push Token

public class DevicePushToken: NSCoding, Codable {
    public var value: String
    public var timestamp: Date
    
    public init(
        value: String,
        timestamp: Date
        ) {
        self.value = value
        self.timestamp = timestamp
    }
    
    public func encode(with aCoder: NSCoder) {
        // TODO
    }
    
    public required init?(coder aDecoder: NSCoder) {
        // TODO
    }
    
    public required init(from decoder: Decoder) throws {
        // TODO
    }
    
    public func encode(to encoder: Encoder) throws {
        // TODO
    }
}

// MARK: Build Environment

public enum BuildEnvironment: String, Codable, Equatable {
    case production = "PRODUCTION"
    case development = "DEVELOPMENT"
    case simulator = "SIMULATOR"
}

// MARK: Location

public class DeviceCoordinate: NSObject, Codable, NSCoding {
    public var latitude: Double
    public var longitude: Double
    
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(self.latitude, forKey: "latitude")
        aCoder.encode(self.longitude, forKey: "longitude")
    }
    
    public required init?(coder aDecoder: NSCoder) {
        self.latitude = aDecoder.decodeDouble(forKey: "latitude")
        self.longitude = aDecoder.decodeDouble(forKey: "longitude")
        // TODO: manual decodings
    }
    
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
    
    public required init(from decoder: Decoder) throws {
        // we want to represent coordinate as a tuple in our JSON as per our GraphQL API rather than a hash of name-value pairs as the default synthesized implementation of Codable would have done.
        var container = try decoder.unkeyedContainer()
        latitude = try container.decode(Double.self)
        longitude = try container.decode(Double.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        // we want to represent coordinate as a tuple in our JSON as per our GraphQL API rather than a hash of name-value pairs as the default synthesized implementation of Codable would have done.
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
    
    // TODO: NSCoding implementation
    
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(self.coordinate, forKey: "coordinate")
        // TODO: manual encodings
    }
    
    public required init?(coder aDecoder: NSCoder) {
        guard let coordinate = aDecoder.decodeObject(forKey: "coordinate") as? DeviceCoordinate else {
            return nil
        }
        self.coordinate = coordinate
        // TODO: manual decodings
    }
    
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
    
    // TODO: NSCoding implementation
    
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(self.street, forKey: "street")
        aCoder.encode(self.city, forKey: "city")
        // TODO: manual encodings
    }
    
    public required init?(coder aDecoder: NSCoder) {
        self.street = aDecoder.decodeObject(forKey: "street") as? String ?? ""
        // TODO: manual decodings
    }
    
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

