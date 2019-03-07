//
//  ContextManager.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-02-16.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import os.log
import UIKit

class ContextManager {
    let persistedPushToken = PersistedValue<Context.PushToken>(storageKey: "io.rover.RoverData.pushToken")
    let persistedUserInfo = PersistedValue<Attributes>(storageKey: "io.rover.RoverData.userInfo")
    let reachability = Reachability(hostname: "google.com")!
    
    init() { }
}

// MARK: LocaleContextProvider

extension ContextManager: LocaleContextProvider {
    var localeLanguage: String? {
        return Locale.current.languageCode
    }
    
    var localeRegion: String? {
        return Locale.current.regionCode
    }
    
    var localeScript: String? {
        return Locale.current.scriptCode
    }
}

// MARK: PushTokenContextProvider

extension ContextManager: PushTokenContextProvider {
    var pushToken: Context.PushToken? {
        return self.persistedPushToken.value
    }
}

// MARK: ReachabilityContextProvider

extension ContextManager: ReachabilityContextProvider {
    var isCellularEnabled: Bool {
        return self.reachability.isReachableViaWWAN
    }
    
    var isWifiEnabled: Bool {
        return self.reachability.isReachableViaWiFi
    }
}

// MARK: StaticContextProvider

extension ContextManager: StaticContextProvider {
    var appBadgeNumber: Int {
        if Thread.isMainThread {
            return UIApplication.shared.applicationIconBadgeNumber
        } else {
            return DispatchQueue.main.sync {
                UIApplication.shared.applicationIconBadgeNumber
            }
        }
    }
    
    var appBuild: String {
        return Bundle.main.infoDictionary!["CFBundleVersion"] as! String
    }
    
    var appIdentifier: String {
        return Bundle.main.bundleIdentifier!
    }
    
    var appVersion: String {
        return Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String
    }
    
    var buildEnvironment: Context.BuildEnvironment {
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
    
    var deviceIdentifier: String {
        return UIDevice.current.identifierForVendor!.uuidString
    }
    
    var deviceManufacturer: String {
        return "Apple"
    }
    
    var deviceModel: String {
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
    
    var deviceName: String {
        return UIDevice.current.name
    }
    
    var operatingSystemName: String {
        return UIDevice.current.systemName
    }
    
    var operatingSystemVersion: String {
        return UIDevice.current.systemVersion
    }
    
    var screenHeight: Int {
        return Int(UIScreen.main.bounds.height)
    }
    
    var screenWidth: Int {
        return Int(UIScreen.main.bounds.width)
    }
    
    var sdkVersion: String {
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
}

// MARK: TimeZoneContextProvider

extension ContextManager: TimeZoneContextProvider {
    var timeZone: String {
        return (NSTimeZone.local as NSTimeZone).name
    }
}

// MARK: TokenManager

extension ContextManager: TokenManager {
    func setToken(_ data: Data) {
        self.persistedPushToken.value = Context.PushToken(
            value: data.map { String(format: "%02.2hhx", $0) }.joined(),
            timestamp: Date()
        )
    }
}

// MARK: UserInfoManager

extension ContextManager: UserInfoContextProvider {
    var userInfo: Attributes? {
        return self.persistedUserInfo.value
    }
}

// MARK: UserInfoManager

extension ContextManager: UserInfoManager {
    func updateUserInfo(block: (inout Attributes) -> Void) {
        var userInfo = self.persistedUserInfo.value ?? Attributes()
        block(&userInfo)
        self.persistedUserInfo.value = userInfo
    }
    
    func clearUserInfo() {
        self.persistedUserInfo.value = nil
    }
}
