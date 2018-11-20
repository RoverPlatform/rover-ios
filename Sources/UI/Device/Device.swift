//
//  Device.swift
//  RoverUI
//
//  Created by Andrew Clunis on 2018-11-20.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation
import os
import UIKit
import UserNotifications

class Device {
    
    let userDefaults: UserDefaults
    let jsonDecoder: JSONDecoder
    let jsonEncoder: JSONEncoder
    
    let adSupportInfoProvider: AdSupportInfoProvider?
    let bluetoothInfoProvider: BluetoothInfoProvider?
    let telephonyInfoProvider: TelephonyInfoProvider?
    let locationInfoProvider: LocationInfoProvider?
    
    let reachability = Reachability(hostname: "google.com")!
    let userNotificationCenter = UNUserNotificationCenter.current()
    
    public init(
        userDefaults: UserDefaults,
        jsonDecoder: JSONDecoder,
        jsonEncoder: JSONEncoder,
        adSupportInfoProvider: AdSupportInfoProvider?,
        bluetoothInfoProvider: BluetoothInfoProvider?,
        telephonyInfoProvider: TelephonyInfoProvider?,
        locationInfoProvider: LocationInfoProvider?
    ) {
        self.userDefaults = userDefaults
        self.jsonDecoder = jsonDecoder
        self.jsonEncoder = jsonEncoder
        self.adSupportInfoProvider = adSupportInfoProvider
        self.bluetoothInfoProvider = bluetoothInfoProvider
        self.telephonyInfoProvider = telephonyInfoProvider
        self.locationInfoProvider = locationInfoProvider
    }
    
    public var snapshot: DeviceSnapshot {
        return DeviceSnapshot(
            advertisingIdentifier: advertisingIdentifier,
            isBluetoothEnabled: isBluetoothEnabled,
            localeLanguage: localeLanguage,
            localeRegion: localeRegion,
            localeScript: localeScript,
            isLocationServicesEnabled: isLocationServicesEnabled,
            location: location,
            locationAuthorization: locationAuthorization,
            notificationAuthorization: notificationAuthorization,
            pushToken: pushToken,
            isCellularEnabled: isCellularEnabled,
            isWifiEnabled: isWifiEnabled,
            appBadgeNumber: appBadgeNumber,
            appBuild: appBuild,
            appIdentifier: appIdentifier,
            appVersion: appVersion,
            buildEnvironment: buildEnvironment,
            deviceIdentifier: deviceIdentifier,
            deviceManufacturer: deviceManufacturer,
            deviceModel: deviceModel,
            deviceName: deviceName,
            operatingSystemName: operatingSystemName,
            operatingSystemVersion: operatingSystemVersion,
            screenHeight: screenHeight,
            screenWidth: screenWidth,
            sdkVersion: sdkVersion,
            carrierName: carrierName,
            radio: radio,
            isTestDevice: isTestDevice,
            timeZone: timeZone,
            userInfo: userInfo
        )
    }
    
    public private(set) var pushToken: DeviceSnapshot.PushToken? {
        get {
            guard let data = userDefaults.data(forKey: "io.rover.RoverData.pushToken") else {
                return nil
            }
            
            do {
                return try jsonDecoder.decode(DeviceSnapshot.PushToken.self, from: data)
            } catch {
                os_log("Failed to decode pushToken: %@", log: .general, type: .error, error.localizedDescription)
                return nil
            }
        }
        set {
            do {
                let data = try jsonEncoder.encode(newValue)
                userDefaults.set(data, forKey: "io.rover.RoverData.pushToken")
            } catch {
                os_log("Failed to encode pushToken: %@", log: .general, type: .error, error.localizedDescription)
            }
        }
    }
    
    // MARK: Locale
    
    public var localeLanguage: String? {
        return Locale.current.languageCode
    }
    
    public var localeRegion: String? {
        return Locale.current.regionCode
    }
    
    public var localeScript: String? {
        return Locale.current.scriptCode
    }
    
    // MARK: Locale
    
    public var isCellularEnabled: Bool {
        return self.reachability.isReachableViaWWAN
    }
    
    public var isWifiEnabled: Bool {
        return self.reachability.isReachableViaWiFi
    }
    
    // MARK: Statics
    
    public var appBadgeNumber: Int {
        if Thread.isMainThread {
            return UIApplication.shared.applicationIconBadgeNumber
        } else {
            return DispatchQueue.main.sync {
                return UIApplication.shared.applicationIconBadgeNumber
            }
        }
    }
    
    public var appBuild: String {
        return Bundle.main.infoDictionary!["CFBundleVersion"] as! String
    }
    
    public var appIdentifier: String {
        return Bundle.main.bundleIdentifier!
    }
    
    public var appVersion: String {
        return Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String
    }
    
    public var buildEnvironment: DeviceSnapshot.BuildEnvironment {
        #if targetEnvironment(simulator)
        return .simulator
        #else
        guard let path = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") else {
            os_log("Provisioning profile not found", log: .context, type: .error)
            return .production
        }
        
        guard let embeddedProfile = try? String(contentsOfFile: path, encoding: String.Encoding.ascii) else {
            os_log("Failed to read provisioning profile at path: %@", log: .context, type: .error, path)
            return .production
        }
        
        let scanner = Scanner(string: embeddedProfile)
        var string: NSString?
        
        guard scanner.scanUpTo("<?xml version=\"1.0\" encoding=\"UTF-8\"?>", into: nil), scanner.scanUpTo("</plist>", into: &string) else {
            os_log("Unrecognized provisioning profile structure", log: .context, type: .error)
            return .production
        }
        
        guard let data = string?.appending("</plist>").data(using: String.Encoding.utf8) else {
            os_log("Failed to decode provisioning profile", log: .context, type: .error)
            return .production
        }
        
        guard let plist = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any] else {
            os_log("Failed to serialize provisioning profile", log: .context, type: .error)
            return .production
        }
        
        guard let entitlements = plist["Entitlements"] as? [String: Any], let apsEnvironment = entitlements["aps-environment"] as? String else {
            os_log("No entry for \"aps-environment\" found in Entitlements – defaulting to production", log: .context, type: .info)
            return .production
        }
        
        switch apsEnvironment {
        case "production":
            return .production
        case "development":
            return .development
        default:
            os_log("Unrecognized value for aps-environment: %@", log: .context, type: .error, apsEnvironment)
            return .production
        }
        #endif
    }
    
    public var deviceIdentifier: String {
        return UIDevice.current.identifierForVendor!.uuidString
    }
    
    public var deviceManufacturer: String {
        return "Apple"
    }
    
    public var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let size = MemoryLayout<CChar>.size
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: size) {
                String(cString: UnsafePointer<CChar>($0))
            }
        }
        
        guard let modelName = String(validatingUTF8: modelCode) else {
            fatalError("Invalid data")
        }
        
        guard let deviceModel = DeviceModel(modelName: modelName) else {
            os_log("Unknown model name: %@", log: .context, type: .error, modelName)
            return modelName
        }
        
        return deviceModel.description
    }
    
    public var deviceName: String {
        return UIDevice.current.name
    }
    
    public var operatingSystemName: String {
        return UIDevice.current.systemName
    }
    
    public var operatingSystemVersion: String {
        return UIDevice.current.systemVersion
    }
    
    public var screenHeight: Int {
        return Int(UIScreen.main.bounds.height)
    }
    
    public var screenWidth: Int {
        return Int(UIScreen.main.bounds.width)
    }
    
    public var sdkVersion: String {
        let bundle: Bundle = {
            if let bundle = Bundle(identifier: "io.rover.RoverFoundation") {
                return bundle
            }
            
            if let bundle = Bundle(identifier: "org.cocoapods.RoverKit") {
                return bundle
            }
            
            fatalError("No bundle found with identifier io.rover.RoverFoundation or org.cocoapods.RoverKit")
        }()
        
        return bundle.infoDictionary!["CFBundleShortVersionString"] as! String
    }
    
    // MARK: Time Zone
    
    public var timeZone: String {
        return (NSTimeZone.local as NSTimeZone).name
    }
    
    // MARK: User Info
    
    public private(set) var userInfo: Attributes? {
        get {
            guard let data = userDefaults.data(forKey: "io.rover.RoverData.userInfo") else {
                return nil
            }
            
            do {
                return try jsonDecoder.decode(Attributes.self, from: data)
            } catch {
                os_log("Failed to decode user info: %@", log: .general, type: .error, error.localizedDescription)
                return nil
            }
        }
        set {
            do {
                let data = try jsonEncoder.encode(newValue)
                userDefaults.set(data, forKey: "io.rover.RoverData.userInfo")
            } catch {
                os_log("Failed to encode user info: %@", log: .general, type: .error, error.localizedDescription)
            }
        }
    }
    
    // MARK: Notifications Authorization
    
    public var notificationAuthorization: String {
        // Refresh status for _next_ time context is requested
        userNotificationCenter.getNotificationSettings { [weak self] settings in
            self?.userDefaults.set(
                settings.authorizationStatus.rawValue,
                forKey: "io.rover.RoverNotifications.authorizationStatus"
            )
        }
        
        let authorizationStatus = UNAuthorizationStatus(
            // if value not yet set, then userDefaults returns 0, which conveniently maps to .notDetermined.
            rawValue: userDefaults.integer(forKey: "io.rover.RoverNotifications.authorizationStatus")
        ) ?? .notDetermined
        
        #if swift(>=4.2)
        switch authorizationStatus {
        case .authorized:
            return "authorized"
        case .denied:
            return "denied"
        case .notDetermined:
            return "notDetermined"
        case .provisional:
            return "provisional"
        }
        #else
        switch authorizationStatus {
        case .authorized:
        return "authorized"
        case .denied:
        return "denied"
        default:
        return "notDetermined"
        }
        #endif
    }
    
    // MARK: Debug Test Device
    
    public private(set) var isTestDevice: Bool {
        get {
            return userDefaults.bool(forKey: "io.rover.RoverData.userInfo")
        }
        set {
            userDefaults.set(newValue, forKey: "io.rover.RoverData.userInfo")
        }
    }

    // MARK: Token
    
    public func setToken(_ data: Data) {
        self.pushToken = DeviceSnapshot.PushToken(
            value: data.map { String(format: "%02.2hhx", $0) }.joined(),
            timestamp: Date()
        )
    }
    
    // MARK: Ad Support
    
    public var advertisingIdentifier: String? {
        return self.adSupportInfoProvider?.advertisingIdentifier
    }
    
    // MARK: Telephony
    
    public var carrierName: String? {
        return self.telephonyInfoProvider?.carrierName
    }
    
    public var radio: String? {
        return self.telephonyInfoProvider?.radio
    }
    
    // MARK: Bluetooth
    
    public var isBluetoothEnabled: Bool? {
        return bluetoothInfoProvider?.isBluetoothEnabled
    }
    
    // MARK: Location
    
    public var location: DeviceSnapshot.Location? {
        return locationInfoProvider?.location
    }
    
    public var locationAuthorization: String? {
        return locationInfoProvider?.locationAuthorization
    }
    
    public var isLocationServicesEnabled: Bool? {
        return locationInfoProvider?.isLocationServicesEnabled
    }
    
    // MARK: User Info
    
    public func updateUserInfo(block: (inout Attributes) -> Void) {
        var userInfo = self.userInfo ?? Attributes()
        block(&userInfo)
        self.userInfo = userInfo
    }
    
    public func clearUserInfo() {
        userDefaults.set(nil, forKey: "io.rover.RoverData.userInfo")
    }
}
