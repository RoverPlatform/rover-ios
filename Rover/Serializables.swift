//
//  Serializables.swift
//  Pods
//
//  Created by Ata Namvari on 2016-02-01.
//
//

import Foundation
import AdSupport
import CoreLocation
import CoreBluetooth
import CoreTelephony

extension Event : Serializable {
    public func serialize() -> [String : Any] {
        let serializedCustomer = Customer.sharedCustomer.serialize()
        let serializedDevice = Device.currentDevice.serialize()
        
        var timestamp: Date
        var serializedAttributes: [String : Any]
        
        switch self {
        case .applicationOpen(let date):
            timestamp = date
            serializedAttributes = [
                "object": "app",
                "action": "open"
            ]
        case .deviceUpdate(let date):
            timestamp = date
            serializedAttributes = [
                "object": "device",
                "action": "update"
            ]
        case .didUpdateLocation(let location, let date):
            timestamp = date
            serializedAttributes = [
                "object": "location",
                "action": "update",
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude,
                "accuracy": location.horizontalAccuracy
            ]
        case .didEnterBeaconRegion(let region, _, _, let date):
            timestamp = date
            serializedAttributes = [
                "object": "beacon-region",
                "action": "enter",
                "identifier": region.identifier,
                "uuid": region.proximityUUID.uuidString,
                "major-number": region.major!,
                "minor-number": region.minor!
            ]
        case .didExitBeaconRegion(let region, _, _, let date):
            timestamp = date
            serializedAttributes = [
                "object": "beacon-region",
                "action": "exit",
                "identifier": region.identifier,
                "uuid": region.proximityUUID.uuidString,
                "major-number": region.major!,
                "minor-number": region.minor!
            ]
        case .didOpenMessage(let message, let source, let date):
            timestamp = date
            serializedAttributes = [
                "object": "message",
                "action": "open",
                "source": source,
                "message-id": message.identifier
            ]
        default:
            timestamp = Date()
            serializedAttributes = [String : AnyObject]()
        }
        
        _swiftBugWorkaround(serializedAttributes: &serializedAttributes , timestamp: &timestamp)
        
        serializedAttributes["time"] = rvDateFormatter.string(from: timestamp)
        serializedAttributes["user"] = serializedCustomer
        serializedAttributes["device"] = serializedDevice
        
        return [
            "data": [
                "type": "events",
                "attributes": serializedAttributes
            ]
        ]
    }
    
    func _swiftBugWorkaround(serializedAttributes: inout [String: Any], timestamp: inout Date) {
        switch self {
        case .didEnterCircularRegion(let region, _, let date):
            timestamp = date
            serializedAttributes = [
                "object": "geofence-region",
                "action": "enter",
                "identifier": region.identifier,
                // Remove this stuff later
                "latitude": region.center.latitude,
                "longitude": region.center.longitude,
                "radius": region.radius
            ]
        case .didExitCircularRegion(let region, _, let date):
            timestamp = date
            serializedAttributes = [
                "object": "geofence-region",
                "action": "exit",
                "identifier": region.identifier,
                "latitude": region.center.latitude,
                "longitude": region.center.longitude,
                "radius": region.radius
            ]
        case .didEnterGimbalPlace(let gimbalPlaceId, let date):
            timestamp = date
            serializedAttributes = [
                "object": "gimbal-place",
                "action": "enter",
                "gimbal-place-id": gimbalPlaceId
            ]
        case .didExitGimbalPlace(let gimbalPlaceId, let date):
            timestamp = date
            serializedAttributes = [
                "object": "gimbal-place",
                "action": "exit",
                "gimbal-place-id": gimbalPlaceId
            ]
        case .didLaunchExperience(let experience, let session, let date, let campaignID):
            timestamp = date
            serializedAttributes = [
                "object": "experience",
                "action": "launched",
                "experience-id": experience.identifier,
                "version-id": experience.version ?? NSNull() as Any,
                "experience-session-id": session
            ]
            
            if let campaignID = campaignID {
                serializedAttributes["campaign-id"] = campaignID
            }
        case .didDismissExperience(let experience, let session, let date, let campaignID):
            timestamp = date
            serializedAttributes = [
                "object": "experience",
                "action": "dismissed",
                "experience-id": experience.identifier,
                "version-id": experience.version ?? NSNull() as Any,
                "experience-session-id": session
            ]
            
            if let campaignID = campaignID {
                serializedAttributes["campaign-id"] = campaignID
            }
        case .didViewScreen(let screen, let experience, let fromScreen, let fromBlock, let session, let date, let campaignID):
            timestamp = date
            serializedAttributes = [
                "object": "experience",
                "action": "screen-viewed",
                "experience-id": experience.identifier,
                "screen-id": screen.identifier ?? NSNull() as Any,
                "from-screen-id": fromScreen?.identifier ?? NSNull() as Any,
                "from-block-id": fromBlock?.identifier ?? NSNull() as Any,
                "version-id": experience.version ?? NSNull() as Any,
                "experience-session-id": session
            ]
            
            if let campaignID = campaignID {
                serializedAttributes["campaign-id"] = campaignID
            }
        case .didPressBlock(let block, let screen, let experience, let session, let date, let campaignID):
            timestamp = date
            serializedAttributes = [
                "object": "experience",
                "action": "block-clicked",
                "block-id": block.identifier ?? "",
                "screen-id": screen.identifier ?? "",
                "experience-id": experience.identifier,
                "block-action": block.action?.serialize() ?? NSNull() as Any,
                "version-id": experience.version ?? NSNull() as Any,
                "experience-session-id": session
            ]
            
            if let campaignID = campaignID {
                serializedAttributes["campaign-id"] = campaignID
            }
        default:
            break
        }
    }
}

extension Device : Serializable {
    func platform() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8 , value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
    
    func serialize() -> [String : Any] {
        let carrierName: Any = CTTelephonyNetworkInfo().subscriberCellularProvider?.carrierName ?? NSNull()
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let osVersionString = "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
        let localeComponents: [String: String] = Locale.components(fromIdentifier: Locale.current.identifier)
        let localeLanguage = localeComponents[NSLocale.Key.languageCode.rawValue] ?? ""
        let localeRegion = localeComponents[NSLocale.Key.countryCode.rawValue] ?? ""
        let localNotificationsEnabled = UIApplication.shared.currentUserNotificationSettings?.types.contains(.alert) ?? false
        let deviceToken: Any = Device.pushToken ?? NSNull()
        let appIdentifier = Bundle.main.bundleIdentifier ?? ""
        let udid = UIDevice.current.identifierForVendor!.uuidString
        let backgroundEnabled = UIApplication.shared.backgroundRefreshStatus == .available
        let locationMonitoringEnabled = CLLocationManager.authorizationStatus() == .authorizedAlways
        let gimbalMode = Rover.sharedInstance?.gimbalMode ?? false
        let aid = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        let adTracking = ASIdentifierManager.shared().isAdvertisingTrackingEnabled
        let timeZone = TimeZone.autoupdatingCurrent.identifier
        let remoteNotificationRegistered = UIApplication.shared.isRegisteredForRemoteNotifications
        let bluetoothStatus = Device.bluetoothOn
        let isDevelopment = Rover.isDevelopment
        
        return [
            "app-identifier": appIdentifier,
            "udid": udid,
            "aid": aid,
            "ad-tracking": adTracking ,
            "token": deviceToken,
            "locale-lang": localeLanguage,
            "locale-region": localeRegion,
            "time-zone": timeZone,
            "local-notifications-enabled": localNotificationsEnabled,
            "remote-notifications-enabled": remoteNotificationRegistered,
            "background-enabled": backgroundEnabled,
            "location-monitoring-enabled": locationMonitoringEnabled,
            "bluetooth-enabled": bluetoothStatus,
            "carrier": carrierName,
            "os-name": "iOS",
            "platform": "iOS",
            "manufacturer": "Apple",
            "os-version": osVersionString,
            "model": self.platform(),
            "sdk-version": "1.8.0",
            "gimbal-mode": gimbalMode,
            "development": isDevelopment
        ]
    }
}

extension Customer : Serializable {
    public func serialize() -> [String : Any] {
        let firstName: Any = self.firstName ?? NSNull()
        let lastName: Any = self.lastName ?? NSNull()
        let phoneNumber: Any = self.phone ?? NSNull()
        let identifier: Any = self.identifier ?? NSNull()
        let gender: Any = self.gender ?? NSNull()
        let age: Any = self.age ?? NSNull()
        let tags: Any = self.tags ?? NSNull()
        let email: Any = self.email ?? NSNull()
        
        return [
            "first-name": firstName,
            "last-name": lastName,
            "email": email,
            "phone-number": phoneNumber,
            "identifier": identifier,
            "gender": gender,
            "age": age,
            "tags": tags,
            "traits": traits
        ]
    }
}

extension Message : Serializable {
    public func serialize() -> [String : Any] {
        return [
            "data": [
                "type": "messages",
                "id": identifier,
                "attributes": [
                    "read": read
                ]
            ]
        ]
    }
}

extension Block.Action : Serializable {
    public func serialize() -> [String : Any] {
        switch self {
        case .screen(let identifier):
            return [
                "type": "go-to-screen",
                "screen-id": identifier
            ]
        case .deeplink(let url):
            return [
                "type": "open-url",
                "url": url.absoluteString
            ]
        default:
            return [:]
        }
    }
}
