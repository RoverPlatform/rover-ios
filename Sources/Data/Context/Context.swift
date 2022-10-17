//
//  Context.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-05-02.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation
#if !COCOAPODS
import RoverFoundation
#endif

public struct Context: Codable, Equatable {
    // MARK: AdSupport
    
    public var advertisingIdentifier: String?
    
    // MARK: Bluetooth
    
    public var isBluetoothEnabled: Bool?
    
    // MARK: Dark Mode
    
    public var isDarkModeEnabled: Bool?
    
    // MARK: Locale
    
    public var localeLanguage: String?
    public var localeRegion: String?
    public var localeScript: String?
    
    // MARK: Location
    
    public struct Location: Codable, Equatable {
        public struct Coordinate: Codable, Equatable {
            public var latitude: Double
            public var longitude: Double
            
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
        
        public struct Address: Codable, Equatable {
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
        
        public var coordinate: Coordinate
        public var altitude: Double
        public var horizontalAccuracy: Double
        public var verticalAccuracy: Double
        public var address: Address?
        public var timestamp: Date
        
        public init(
            coordinate: Coordinate,
            altitude: Double,
            horizontalAccuracy: Double,
            verticalAccuracy: Double,
            address: Address?,
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
    
    public var isLocationServicesEnabled: Bool?
    public var location: Location?
    public var locationAuthorization: String?
    
    // MARK: Notifications
    
    public var notificationAuthorization: String?
    
    // MARK: Push Token
    
    public struct PushToken: Codable, Equatable {
        public internal(set) var value: String
        public internal(set) var timestamp: Date
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
    
    public var userInfo: Attributes?
    
    // MARK: Conversions
    public var conversions: [String]?
    
    public init(
        advertisingIdentifier: String?,
        isDarkModeEnabled: Bool?,
        isBluetoothEnabled: Bool?,
        localeLanguage: String?,
        localeRegion: String?,
        localeScript: String?,
        isLocationServicesEnabled: Bool?,
        location: Location?,
        locationAuthorization: String?,
        notificationAuthorization: String?,
        pushToken: PushToken?,
        isCellularEnabled: Bool?,
        isWifiEnabled: Bool?,
        appBadgeNumber: Int?,
        appBuild: String?,
        appIdentifier: String?,
        appVersion: String?,
        buildEnvironment: BuildEnvironment?,
        deviceIdentifier: String?,
        deviceManufacturer: String?,
        deviceModel: String?,
        deviceName: String?,
        operatingSystemName: String?,
        operatingSystemVersion: String?,
        screenHeight: Int?,
        screenWidth: Int?,
        sdkVersion: String?,
        carrierName: String?,
        radio: String?,
        isTestDevice: Bool?,
        timeZone: String?,
        userInfo: Attributes?,
        conversions: [String]?
    ) {
        self.advertisingIdentifier = advertisingIdentifier
        self.isDarkModeEnabled = isDarkModeEnabled
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
        self.conversions = conversions
    }
}
