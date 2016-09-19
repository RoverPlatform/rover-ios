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
                "source": source ?? NSNull() as Any,
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
        case .didLaunchExperience(let experience, let date):
            timestamp = date
            serializedAttributes = [
                "object": "experience",
                "action": "launched",
                "experience-id": experience.identifier
            ]
        case .didDismissExperience(let experience, let date):
            timestamp = date
            serializedAttributes = [
                "object": "experience",
                "action": "dismissed",
                "experience-id": experience.identifier
            ]
        case .didViewScreen(let screen, let experience, let fromScreen, let fromBlock, let date):
            timestamp = date
            serializedAttributes = [
                "object": "experience",
                "action": "screen-viewed",
                "experience-id": experience.identifier,
                "screen-id": screen.identifier ?? NSNull() as Any,
                "from-screen-id": fromScreen?.identifier ?? NSNull() as Any,
                "from-block-id": fromBlock?.identifier ?? NSNull() as Any
            ]
        case .didPressBlock(let block, let screen, let experience, let date):
            timestamp = date
            serializedAttributes = [
                "object": "experience",
                "action": "block-clicked",
                "block-id": block.identifier ?? "",
                "screen-id": screen.identifier ?? "",
                "experience-id": experience.identifier,
                "block-action": block.action?.serialize() ?? NSNull()
            ]
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
        let localeComponents = Locale.components(fromIdentifier: Locale.current.identifier)
        let localeLanguage = localeComponents[NSLocale.Key.languageCode.rawValue]
        let localeRegion = localeComponents[NSLocale.Key.countryCode.rawValue]
        let localNotificationsEnabled = UIApplication.shared.currentUserNotificationSettings?.types.contains(.alert) ?? false
        let deviceToken: AnyObject = Device.pushToken as AnyObject? ?? NSNull()
        
        return [
            "app-identifier": Bundle.main.bundleIdentifier ?? "",
            "udid": UIDevice.current.identifierForVendor!.uuidString,
            "aid": ASIdentifierManager.shared().advertisingIdentifier.uuidString,
            "ad-tracking": ASIdentifierManager.shared().isAdvertisingTrackingEnabled ,
            "token": deviceToken,
            "locale-lang": localeLanguage ?? "",
            "locale-region": localeRegion ?? "",
            "time-zone": TimeZone.autoupdatingCurrent.identifier,
            "local-notifications-enabled": localNotificationsEnabled,
            "remote-notifications-enabled": UIApplication.shared.isRegisteredForRemoteNotifications,
            "background-enabled": UIApplication.shared.backgroundRefreshStatus == .available,
            "location-monitoring-enabled": CLLocationManager.authorizationStatus() == .authorizedAlways,
            "bluetooth-enabled": Device.bluetoothOn,
            "carrier": carrierName,
            "os-name": "iOS",
            "platform": "iOS",
            "manufacturer": "Apple",
            "os-version": "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)",
            "model": self.platform(),
            "sdk-version": "1.0.0",
            "gimbal-mode": Rover.sharedInstance?.gimbalMode ?? false,
            "development": true
        ]
    }
}

extension Customer : Serializable {
    public func serialize() -> [String : Any] {
        let firstName = self.firstName ?? NSNull() as Any
        let lastName = self.lastName ?? NSNull() as Any
        let phoneNumber = self.phone ?? NSNull() as Any
        let identifier = self.identifier ?? NSNull() as Any
        let gender = self.gender ?? NSNull() as Any
        let age = self.age ?? NSNull() as Any
        let tags = self.tags ?? NSNull() as Any
        let email = self.email ?? NSNull() as Any
        
        return [
            "first-name": firstName,
            "last-name": lastName,
            "email": email,
            "phone-number": phoneNumber,
            "identifier": identifier,
            "gender": gender,
            "age": age,
            "tags": tags
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
        var type: String?
        
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
