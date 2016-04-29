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
    func serialize() -> [String : AnyObject] {
        let serializedUser = User.sharedUser.serialize()
        let serializedDevice = Device.CurrentDevice.serialize()
        
        var timestamp: NSDate
        var serializedAttributes: [String : AnyObject]
        
        switch self {
        case .ApplicationOpen(let date):
            timestamp = date
            serializedAttributes = [
                "object": "app",
                "action": "open"
            ]
        case .DeviceUpdate(let date):
            timestamp = date
            serializedAttributes = [
                "object": "device",
                "action": "update"
            ]
        case .DidUpdateLocation(let location, let date):
            timestamp = date
            serializedAttributes = [
                "object": "location",
                "action": "update",
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude
            ]
        case .DidEnterBeaconRegion(let region, _, _, let date):
            timestamp = date
            serializedAttributes = [
                "object": "beacon-region",
                "action": "enter",
                "identifier": region.identifier,
                "uuid": region.proximityUUID.UUIDString,
                "major-number": region.major!,
                "minor-number": region.minor!
            ]
        case .DidExitBeaconRegion(let region, _, _, let date):
            timestamp = date
            serializedAttributes = [
                "object": "beacon-region",
                "action": "exit",
                "identifier": region.identifier,
                "uuid": region.proximityUUID.UUIDString,
                "major-number": region.major!,
                "minor-number": region.minor!
            ]
        default:
            timestamp = NSDate()
            serializedAttributes = [String : AnyObject]()
        }
        
        _swiftBugWorkaround(serializedAttributes: &serializedAttributes , timestamp: &timestamp)
        
        serializedAttributes["time"] = rvDateFormatter.stringFromDate(timestamp)
        serializedAttributes["user"] = serializedUser
        serializedAttributes["device"] = serializedDevice
        
        return [
            "data": [
                "type": "events",
                "attributes": serializedAttributes
            ]
        ]
    }
    
    func _swiftBugWorkaround(inout serializedAttributes serializedAttributes: [String: AnyObject], inout timestamp timestamp: NSDate) {
        switch self {
        case .DidEnterCircularRegion(let region, _, let date):
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
        case .DidExitCircularRegion(let region, _, let date):
            timestamp = date
            serializedAttributes = [
                "object": "geofence-region",
                "action": "exit",
                "identifier": region.identifier,
                "latitude": region.center.latitude,
                "longitude": region.center.longitude,
                "radius": region.radius
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
            guard let value = element.value as? Int8 where value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
    
    func serialize() -> [String : AnyObject] {
        let carrierName = CTTelephonyNetworkInfo().subscriberCellularProvider?.carrierName ?? NSNull()
        let osVersion = NSProcessInfo.processInfo().operatingSystemVersion
        let localeComponents = NSLocale.componentsFromLocaleIdentifier(NSLocale.currentLocale().localeIdentifier)
        let localeLanguage = localeComponents[NSLocaleLanguageCode]
        let localeRegion = localeComponents[NSLocaleCountryCode]
        let localNotificationsEnabled = UIApplication.sharedApplication().currentUserNotificationSettings()?.types.contains(.Alert) ?? false
        
        return [
            "app-identifier": NSBundle.mainBundle().bundleIdentifier ?? "",
            "udid": UIDevice.currentDevice().identifierForVendor!.UUIDString,
            "aid": ASIdentifierManager.sharedManager().advertisingIdentifier.UUIDString,
            "ad-tracking": ASIdentifierManager.sharedManager().advertisingTrackingEnabled ,
            "token": Device.pushToken ?? NSNull(),
            "locale-lang": localeLanguage ?? "",
            "locale-region": localeRegion ?? "",
            "time-zone": NSTimeZone.localTimeZone().name,
            "local-notifications-enabled": localNotificationsEnabled,
            "remote-notifications-enabled": UIApplication.sharedApplication().isRegisteredForRemoteNotifications(),
            "background-enabled": UIApplication.sharedApplication().backgroundRefreshStatus == .Available,
            "location-monitoring-enabled": CLLocationManager.authorizationStatus() == .AuthorizedAlways,
            "bluetooth-enabled": Device.bluetoothOn,
            "carrier": carrierName,
            "os-name": "iOS",
            "platform": "iOS",
            "manufacturer": "Apple",
            "os-version": "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)",
            "model": self.platform(),
            "sdk-version": "4.0.0",
            "development": true
        ]
    }
}

extension User : Serializable {
    func serialize() -> [String : AnyObject] {
        return [
            "name": name ?? NSNull(),
            "email": email ?? NSNull(),
            "phone-number": phone ?? NSNull(),
            "identifier": identifier ?? NSNull(),
            "gender": gender ?? NSNull(),
            "age": age ?? NSNull(),
            "tags": tags ?? NSNull()
        ]
    }
}

extension Message : Serializable {
    func serialize() -> [String : AnyObject] {
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
