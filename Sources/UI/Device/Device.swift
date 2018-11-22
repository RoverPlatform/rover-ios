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

open class Device {
    let adSupportInfoProvider: AdSupportInfoProvider?
    let bluetoothInfoProvider: BluetoothInfoProvider?
    let telephonyInfoProvider: TelephonyInfoProvider?
    let locationInfoProvider: LocationInfoProvider?
    
    let reachability = Reachability(hostname: "google.com")!
    
    public init(
        adSupportInfoProvider: AdSupportInfoProvider?,
        bluetoothInfoProvider: BluetoothInfoProvider?,
        telephonyInfoProvider: TelephonyInfoProvider?,
        locationInfoProvider: LocationInfoProvider?
    ) {
        self.adSupportInfoProvider = adSupportInfoProvider
        self.bluetoothInfoProvider = bluetoothInfoProvider
        self.telephonyInfoProvider = telephonyInfoProvider
        self.locationInfoProvider = locationInfoProvider
    }
    
    public var snapshot: DeviceSnapshot {
        return DeviceSnapshot(
            advertisingIdentifier: self.advertisingIdentifier,
            isBluetoothEnabled: self.isBluetoothEnabled,
            localeLanguage: self.localeLanguage,
            localeRegion: self.localeRegion,
            localeScript: self.localeScript,
            isLocationServicesEnabled: self.isLocationServicesEnabled,
            location: self.location,
            locationAuthorization: self.locationAuthorization,
            notificationAuthorization: self.notificationAuthorization,
            pushToken: self.pushToken,
            isCellularEnabled: self.isCellularEnabled,
            isWifiEnabled: self.isWifiEnabled,
            appBadgeNumber: self.appBadgeNumber,
            appBuild: self.appBuild,
            appIdentifier: self.appIdentifier,
            appVersion: self.appVersion,
            buildEnvironment: self.buildEnvironment,
            deviceIdentifier: self.deviceIdentifier,
            deviceManufacturer: self.deviceManufacturer,
            deviceModel: self.deviceModel,
            deviceName: self.deviceName,
            operatingSystemName: self.operatingSystemName,
            operatingSystemVersion: self.operatingSystemVersion,
            screenHeight: self.screenHeight,
            screenWidth: self.screenWidth,
            sdkVersion: self.sdkVersion,
            carrierName: self.carrierName,
            radio: self.radio,
            isTestDevice: self.isTestDevice,
            timeZone: self.timeZone,
            userInfo: self.userInfo
        )
    }
    
    open private(set) var pushToken: DeviceSnapshot.PushToken? {
        get {
            guard let data = UserDefaults.standard.data(forKey: "io.rover.RoverData.pushToken") else {
                return nil
            }
            
            do {
                return try JSONDecoder.default.decode(DeviceSnapshot.PushToken.self, from: data)
            } catch {
                os_log("Failed to decode pushToken: %@", log: .general, type: .error, error.localizedDescription)
                return nil
            }
        }
        set {
            do {
                let data = try JSONEncoder.default.encode(newValue)
                UserDefaults.standard.set(data, forKey: "io.rover.RoverData.pushToken")
            } catch {
                os_log("Failed to encode pushToken: %@", log: .general, type: .error, error.localizedDescription)
            }
        }
    }
    
    // MARK: Locale
    
    open var localeLanguage: String? {
        return Locale.current.languageCode
    }
    
    open var localeRegion: String? {
        return Locale.current.regionCode
    }
    
    open var localeScript: String? {
        return Locale.current.scriptCode
    }
    
    // MARK: Telephony
    
    open var isCellularEnabled: Bool {
        return self.reachability.isReachableViaWWAN
    }
    
    open var isWifiEnabled: Bool {
        return self.reachability.isReachableViaWiFi
    }
    
    // MARK: Statics
    
    open var appBadgeNumber: Int {
        if Thread.isMainThread {
            return UIApplication.shared.applicationIconBadgeNumber
        } else {
            return DispatchQueue.main.sync {
                return UIApplication.shared.applicationIconBadgeNumber
            }
        }
    }
    
    open var appBuild: String {
        return Bundle.main.infoDictionary!["CFBundleVersion"] as! String
    }
    
    open var appIdentifier: String {
        return Bundle.main.bundleIdentifier!
    }
    
    open var appVersion: String {
        return Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String
    }
    
    open var buildEnvironment: DeviceSnapshot.BuildEnvironment {
        #if targetEnvironment(simulator)
        return .simulator
        #else
        guard let path = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") else {
            os_log("Provisioning profile not found", log: .general, type: .error)
            return .production
        }
        
        guard let embeddedProfile = try? String(contentsOfFile: path, encoding: String.Encoding.ascii) else {
            os_log("Failed to read provisioning profile at path: %@", log: .general, type: .error, path)
            return .production
        }
        
        let scanner = Scanner(string: embeddedProfile)
        var string: NSString?
        
        guard scanner.scanUpTo("<?xml version=\"1.0\" encoding=\"UTF-8\"?>", into: nil), scanner.scanUpTo("</plist>", into: &string) else {
            os_log("Unrecognized provisioning profile structure", log: .general, type: .error)
            return .production
        }
        
        guard let data = string?.appending("</plist>").data(using: String.Encoding.utf8) else {
            os_log("Failed to decode provisioning profile", log: .general, type: .error)
            return .production
        }
        
        guard let plist = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any] else {
            os_log("Failed to serialize provisioning profile", log: .general, type: .error)
            return .production
        }
        
        guard let entitlements = plist["Entitlements"] as? [String: Any], let apsEnvironment = entitlements["aps-environment"] as? String else {
            os_log("No entry for \"aps-environment\" found in Entitlements – defaulting to production", log: .general, type: .info)
            return .production
        }
        
        switch apsEnvironment {
        case "production":
            return .production
        case "development":
            return .development
        default:
            os_log("Unrecognized value for aps-environment: %@", log: .general, type: .error, apsEnvironment)
            return .production
        }
        #endif
    }
    
    open var deviceIdentifier: String {
        return UIDevice.current.identifierForVendor!.uuidString
    }
    
    open var deviceManufacturer: String {
        return "Apple"
    }
    
    open var deviceModel: String {
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
            os_log("Unknown model name: %@", log: .general, type: .error, modelName)
            return modelName
        }
        
        return deviceModel.description
    }
    
    open var deviceName: String {
        return UIDevice.current.name
    }
    
    open var operatingSystemName: String {
        return UIDevice.current.systemName
    }
    
    open var operatingSystemVersion: String {
        return UIDevice.current.systemVersion
    }
    
    open var screenHeight: Int {
        return Int(UIScreen.main.bounds.height)
    }
    
    open var screenWidth: Int {
        return Int(UIScreen.main.bounds.width)
    }
    
    open var sdkVersion: String {
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
    
    open var timeZone: String {
        return (NSTimeZone.local as NSTimeZone).name
    }
    
    // MARK: User Info
    
    open private(set) var userInfo: Attributes? {
        get {
            guard let data = UserDefaults.standard.data(forKey: "io.rover.RoverData.userInfo") else {
                return nil
            }
            
            do {
                return try JSONDecoder.default.decode(Attributes.self, from: data)
            } catch {
                os_log("Failed to decode user info: %@", log: .general, type: .error, error.localizedDescription)
                return nil
            }
        }
        set {
            do {
                let data = try JSONEncoder.default.encode(newValue)
                UserDefaults.standard.set(data, forKey: "io.rover.RoverData.userInfo")
            } catch {
                os_log("Failed to encode user info: %@", log: .general, type: .error, error.localizedDescription)
            }
        }
    }
    
    // MARK: Notifications Authorization
    
    open var notificationAuthorization: String {
        // Refresh status for _next_ time notificationAuthorization is requested
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            UserDefaults.standard.set(
                settings.authorizationStatus.rawValue,
                forKey: "io.rover.RoverNotifications.authorizationStatus"
            )
        }
        
        let authorizationStatus = UNAuthorizationStatus(
            // if value not yet set, then UserDefaults.standard returns 0, which conveniently maps to .notDetermined.
            rawValue: UserDefaults.standard.integer(forKey: "io.rover.RoverNotifications.authorizationStatus")
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
    
    open private(set) var isTestDevice: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "io.rover.RoverData.userInfo")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "io.rover.RoverData.userInfo")
        }
    }

    // MARK: Token
    
    open func setToken(_ data: Data) {
        self.pushToken = DeviceSnapshot.PushToken(
            value: data.map { String(format: "%02.2hhx", $0) }.joined(),
            timestamp: Date()
        )
    }
    
    // MARK: Ad Support
    
    open var advertisingIdentifier: String? {
        return self.adSupportInfoProvider?.advertisingIdentifier
    }
    
    // MARK: Telephony
    
    open var carrierName: String? {
        return self.telephonyInfoProvider?.carrierName
    }
    
    open var radio: String? {
        return self.telephonyInfoProvider?.radio
    }
    
    // MARK: Bluetooth
    
    open var isBluetoothEnabled: Bool? {
        return bluetoothInfoProvider?.isBluetoothEnabled
    }
    
    // MARK: Location
    
    open var location: DeviceSnapshot.Location? {
        return locationInfoProvider?.location
    }
    
    open var locationAuthorization: String? {
        return locationInfoProvider?.locationAuthorization
    }
    
    open var isLocationServicesEnabled: Bool? {
        return locationInfoProvider?.isLocationServicesEnabled
    }
    
    // MARK: User Info
    
    open func updateUserInfo(block: (inout Attributes) -> Void) {
        var userInfo = self.userInfo ?? Attributes()
        block(&userInfo)
        self.userInfo = userInfo
    }
    
    open func clearUserInfo() {
        UserDefaults.standard.set(nil, forKey: "io.rover.RoverData.userInfo")
    }
}
