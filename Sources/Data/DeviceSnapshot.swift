//
//  DeviceSnapshot.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-05-02.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

class DeviceSnapshot: NSObject, Codable, NSCoding {
    func encode(with aCoder: NSCoder) {
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
    
    required init?(coder aDecoder: NSCoder) {
        // we must implement Decodable manually because the NSDictionary field used for Attributes (which itself was used in lieu of Swift Dictionary in order to enable NSCoding) prevents Codable being synthesized.
        
        // TODO: ANDREW START HERE and handle nil cases for any values that may improperly coerce nil values as empty or falsy.
        
        self.advertisingIdentifier = aDecoder.decodeObject(forKey: "advertisingIdentifier") as? String
        
        self.isBluetoothEnabled = aDecoder.decodeBool(forKey: "isBluetoothEnabled")
        self.localeLanguage = aDecoder.decodeObject(forKey: "localeLanguage") as? String
        self.localeScript = aDecoder.decodeObject(forKey: "localeScript") as? String
        
        self.isLocationServicesEnabled = aDecoder.decodeBool(forKey: "isLocationServicesEnabled")
        self.location = aDecoder.decodeObject(forKey: "location") as? DeviceLocation
        self.locationAuthorization = aDecoder.decodeObject(forKey: "locationAuthorization") as? String
        self.notificationAuthorization = aDecoder.decodeObject(forKey: "notificationAuthorization") as? String
        
        self.isBluetoothEnabled = aDecoder.decodeBool(forKey: "isBluetoothEnabled")
        
        self.pushToken = aDecoder.decodeObject(forKey: "pushToken") as? DevicePushToken
        
        self.isCellularEnabled = aDecoder.decodeBool(forKey: "isCellularEnabled")
        
        self.isWifiEnabled = aDecoder.decodeBool(forKey: "isWifiEnabled")
        self.appBadgeNumber = aDecoder.decodeInteger(forKey: "appBadgeNumber")
        
        self.appBuild = aDecoder.decodeObject(forKey: "appBuild") as? String
        self.appIdentifier = aDecoder.decodeObject(forKey: "appIdentifier") as? String
        self.appVersion = aDecoder.decodeObject(forKey: "appVersion") as? String
        self.buildEnvironment = aDecoder.decodeObject(forKey: "buildEnvironment") as? BuildEnvironment
        self.deviceIdentifier = aDecoder.decodeObject(forKey: "deviceIdentifier") as? String
        self.deviceManufacturer = aDecoder.decodeObject(forKey: "deviceManufacturer") as? String
        self.deviceModel = aDecoder.decodeObject(forKey: "deviceModel") as? String
        self.deviceName = aDecoder.decodeObject(forKey: "deviceName") as? String
        self.operatingSystemName = aDecoder.decodeObject(forKey: "operatingSystemName") as? String
        self.operatingSystemVersion = aDecoder.decodeObject(forKey: "operatingSystemVersion") as? String
        self.screenHeight = aDecoder.decodeInteger(forKey: "screenHeight")
        self.screenWidth = aDecoder.decodeInteger(forKey: "screenWidth")
        self.sdkVersion = aDecoder.decodeObject(forKey: "sdkVersion") as? String
        self.carrierName = aDecoder.decodeObject(forKey: "carrierName") as? String
        self.radio = aDecoder.decodeObject(forKey: "radio") as? String
        
        if aDecoder.containsValue(forKey: "isTestDevice") {
            self.isTestDevice = aDecoder.decodeBool(forKey: "isTestDevice")
        }
        
        
        self.timeZone = aDecoder.decodeObject(forKey: "timeZone") as? String
        self.userInfo = aDecoder.decodeObject(forKey: "userInfo") as? Attributes
    }
    
    // MARK: AdSupport
    
    var advertisingIdentifier: String?
    
    // MARK: Bluetooth
    
    var isBluetoothEnabled: Bool?
    
    // MARK: Locale
    
    var localeLanguage: String?
    var localeRegion: String?
    var localeScript: String?

    
    var isLocationServicesEnabled: Bool?
    var location: DeviceLocation?
    var locationAuthorization: String?
    
    // MARK: Notifications
    
    var notificationAuthorization: String?
    
    // MARK: Push Token
    
    var pushToken: DevicePushToken?
    
    // MARK: Reachability
    
    var isCellularEnabled: Bool?
    var isWifiEnabled: Bool?
    
    // MARK: Static Context
    
    var appBadgeNumber: Int?
    var appBuild: String?
    var appIdentifier: String?
    var appVersion: String?
    var buildEnvironment: BuildEnvironment?
    var deviceIdentifier: String?
    var deviceManufacturer: String?
    var deviceModel: String?
    var deviceName: String?
    var operatingSystemName: String?
    var operatingSystemVersion: String?
    var screenHeight: Int?
    var screenWidth: Int?
    var sdkVersion: String?
    
    // MARK: Telephony
    
    var carrierName: String?
    var radio: String?
    
    // MARK: Testing
    
    var isTestDevice: Bool?
    
    // MARK: Time Zone
    
    var timeZone: String?
    
    // MARK: User Info
    
    /// As Rover Attributes, with all of the constraints thereof implied.
    var userInfo: Attributes?
    
    init(
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

class DevicePushToken: NSCoding, Codable {
    var value: String
    var timestamp: Date
    
    init(
        value: String,
        timestamp: Date
        ) {
        self.value = value
        self.timestamp = timestamp
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(value, forKey: "value")
        aCoder.encode(timestamp, forKey: "date")
    }
    
    required init?(coder aDecoder: NSCoder) {
        guard let value = aDecoder.decodeObject(forKey: "value") as? NSString else { return nil }
        self.value = String(value)
        guard let timestamp = aDecoder.decodeObject(forKey: "timestamp") as? Date else { return nil }
        self.timestamp = timestamp
    }
}

// MARK: Build Environment

enum BuildEnvironment: String, Codable, Equatable {
    case production = "PRODUCTION"
    case development = "DEVELOPMENT"
    case simulator = "SIMULATOR"
}

// MARK: Location

class DeviceCoordinate: NSObject, Codable, NSCoding {
    var latitude: Double
    var longitude: Double
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(self.latitude, forKey: "latitude")
        aCoder.encode(self.longitude, forKey: "longitude")
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.latitude = aDecoder.decodeDouble(forKey: "latitude")
        self.longitude = aDecoder.decodeDouble(forKey: "longitude")
        // TODO: manual decodings
    }
    
    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
    
    required init(from decoder: Decoder) throws {
        // we want to represent coordinate as a tuple in our JSON as per our GraphQL API rather than a hash of name-value pairs as the default synthesized implementation of Codable would have done.
        var container = try decoder.unkeyedContainer()
        latitude = try container.decode(Double.self)
        longitude = try container.decode(Double.self)
    }
    
    func encode(to encoder: Encoder) throws {
        // we want to represent coordinate as a tuple in our JSON as per our GraphQL API rather than a hash of name-value pairs as the default synthesized implementation of Codable would have done.
        var container = encoder.unkeyedContainer()
        try container.encode(latitude)
        try container.encode(longitude)
    }
}

class DeviceLocation: Codable, NSCoding {
    var coordinate: DeviceCoordinate
    var altitude: Double
    var horizontalAccuracy: Double
    var verticalAccuracy: Double
    var address: DeviceAddress?
    var timestamp: Date
    
    // TODO: NSCoding implementation
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(self.coordinate, forKey: "coordinate")
        // TODO: manual encodings
    }
    
    required init?(coder aDecoder: NSCoder) {
        guard let coordinate = aDecoder.decodeObject(forKey: "coordinate") as? DeviceCoordinate else {
            return nil
        }
        self.coordinate = coordinate
        // TODO: manual decodings
    }
    
    init(
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

    
class DeviceAddress: Codable, NSCoding {
    var street: String?
    var city: String?
    var state: String?
    var postalCode: String?
    var country: String?
    var isoCountryCode: String?
    var subAdministrativeArea: String?
    var subLocality: String?
    
    // TODO: NSCoding implementation
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(self.street, forKey: "street")
        aCoder.encode(self.city, forKey: "city")
        // TODO: manual encodings
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.street = aDecoder.decodeObject(forKey: "street") as? String ?? ""
        // TODO: manual decodings
    }
    
    init(
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
