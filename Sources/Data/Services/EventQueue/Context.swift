//
//  Context.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-05-02.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

public struct Context: Codable, Equatable {
    public var appBadgeNumber: Int?
    public var appBuild: String?
    public var appIdentifier: String?
    public var appVersion: String?
    public var attributes: Attributes?
    public var carrierName: String?
    public var deviceIdentifier: String?
    public var deviceManufacturer: String?
    public var deviceModel: String?
    public var deviceName: String?
    public var isBluetoothEnabled: Bool?
    public var isCellularEnabled: Bool?
    public var isLocationServicesEnabled: Bool?
    public var isTestDevice: Bool?
    public var isWifiEnabled: Bool?
    public var locationAuthorization: String?
    public var localeLanguage: String?
    public var localeRegion: String?
    public var localeScript: String?
    public var notificationAuthorization: String?
    public var operatingSystemName: String?
    public var operatingSystemVersion: String?
    public var pushEnvironment: String?
    public var pushToken: String?
    public var radio: String?
    public var screenWidth: Int?
    public var screenHeight: Int?
    public var sdkVersion: String?
    public var timeZone: String?
    
    public init(appBadgeNumber: Int? = nil, appBuild: String? = nil, appIdentifier: String? = nil, appVersion: String? = nil, attributes: Attributes? = nil, carrierName: String? = nil, deviceIdentifier: String? = nil, deviceManufacturer: String? = nil, deviceModel: String? = nil, isBluetoothEnabled: Bool? = nil, isCellularEnabled: Bool? = nil, isLocationServicesEnabled: Bool? = nil, isTestDevice: Bool? = nil, isWifiEnabled: Bool? = nil, locationAuthorization: String? = nil, localeLanguage: String? = nil, localeRegion: String? = nil, localeScript: String? = nil, notificationAuthorization: String? = nil, operatingSystemName: String? = nil, operatingSystemVersion: String? = nil, pushEnvironment: String? = nil, pushToken: String? = nil, radio: String? = nil, screenWidth: Int? = nil, screenHeight: Int? = nil, sdkVersion: String? = nil, timeZone: String? = nil) {
        self.appBadgeNumber = appBadgeNumber
        self.appBuild = appBuild
        self.appIdentifier = appIdentifier
        self.appVersion = appVersion
        self.attributes = attributes
        self.carrierName = carrierName
        self.deviceIdentifier = deviceIdentifier
        self.deviceManufacturer = deviceManufacturer
        self.deviceModel = deviceModel
        self.isBluetoothEnabled = isBluetoothEnabled
        self.isCellularEnabled = isCellularEnabled
        self.isLocationServicesEnabled = isLocationServicesEnabled
        self.isTestDevice = isTestDevice
        self.isWifiEnabled = isWifiEnabled
        self.locationAuthorization = locationAuthorization
        self.localeLanguage = localeLanguage
        self.localeRegion = localeRegion
        self.localeScript = localeScript
        self.notificationAuthorization = notificationAuthorization
        self.operatingSystemName = operatingSystemName
        self.operatingSystemVersion = operatingSystemVersion
        self.pushEnvironment = pushEnvironment
        self.pushToken = pushToken
        self.radio = radio
        self.screenWidth = screenWidth
        self.screenHeight = screenHeight
        self.sdkVersion = sdkVersion
        self.timeZone = timeZone
    }
}
