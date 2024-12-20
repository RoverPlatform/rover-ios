// Copyright (c) 2020-present, Rover Labs, Inc. All rights reserved.
// You are hereby granted a non-exclusive, worldwide, royalty-free license to use,
// copy, modify, and distribute this software in source code or binary form for use
// in connection with the web services and APIs provided by Rover.
//
// This copyright notice shall be included in all copies or substantial portions of 
// the software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import os.log
import UIKit
import RoverFoundation

class ContextManager {
    let persistedPushToken = PersistedValue<Context.PushToken>(storageKey: "io.rover.RoverData.pushToken")
    let persistedUserInfo = PersistedValue<Attributes>(storageKey: "io.rover.RoverData.userInfo")
    let persistedDeviceName = PersistedValue<String>(storageKey: "io.rover.RoverData.deviceName")
    let persistedAppLastSeenTimestamp = PersistedValue<Date>(storageKey: "io.rover.RoverData.appLastSeenTimestamp")
    let reachability = Reachability(hostname: "google.com")!
    let privacyService: PrivacyService
    
    init(privacyService: PrivacyService) {
        self.privacyService = privacyService
    }
}

// MARK: DarkModeContextProvider

extension ContextManager: DarkModeContextProvider {
    var isDarkModeEnabled: Bool? {
        #if swift(>=5.1)
        if #available(iOS 13.0, *) {
            return UIScreen.main.traitCollection.userInterfaceStyle == .dark
        } else {
            return false
        }
        #else
        return false
        #endif
    }
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
        return .development
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

        
    
        guard scanner.scanUpToString("<?xml version=\"1.0\" encoding=\"UTF-8\"?>") != nil,
              let string = scanner.scanUpToString("</plist>") else {
            os_log("Unrecognized provisioning profile structure", log: .context, type: .error)
            return .production
        }
        
        guard let data = string.appending("</plist>").data(using: String.Encoding.utf8) else {
            os_log("Failed to decode provisioning profile", log: .context, type: .error)
            return .production
        }
        
        guard let plist = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any] else {
            os_log("Failed to serialize provisioning profile", log: .context, type: .error)
            return .production
        }
        
        guard let entitlements = plist["Entitlements"] as? [String: Any], let apsEnvironment = entitlements["aps-environment"] as? String else {
            os_log("No entry for \"aps-environment\" found in Entitlements – defaulting to production", log: .context, type: .info)
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
    
    var deviceIdentifier: String? {
        return UIDevice.current.identifierForVendor?.uuidString
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
        
        let modelName = String(modelCode)
        
        guard let deviceModel = DeviceModel(modelName: modelName) else {
            os_log("Unknown model name: %@", log: .context, type: .error, modelName)
            return modelName
        }
        
        return deviceModel.description
    }
    
    var deviceName: String {
        return self.persistedDeviceName.value ?? UIDevice.current.name
    }
    
    var operatingSystemName: String {
        return UIDevice.current.systemName
    }
    
    var operatingSystemVersion: String {
        return UIDevice.current.systemVersion
    }
    
    var screenHeight: Double {
        return UIScreen.main.bounds.height
    }
    
    var screenWidth: Double {
        return UIScreen.main.bounds.width
    }
    
    var sdkVersion: String {
        return Meta.SDKVersion
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
    
    var currentUserInfo: [String: Any] {
        get {
            let attributes: Attributes = self.persistedUserInfo.value ?? Attributes()
            return attributes.flatRawValue()
        }
    }
}

// MARK: DeviceNameManager

extension ContextManager: DeviceNameManager {
    func setDeviceName(_ deviceName: String) {
        self.persistedDeviceName.value = deviceName
    }
}

// MARK: AppLastSeenTimestampManager

extension ContextManager: AppLastSeenTimestampManager {
    func markAppLastSeen() {
        self.persistedAppLastSeenTimestamp.value = Date()
    }
}

// MARK: AppLastSeenContextProvider

extension ContextManager: AppLastSeenContextProvider {
    var appLastSeen: Date? {
        return self.persistedAppLastSeenTimestamp.value
    }
}
