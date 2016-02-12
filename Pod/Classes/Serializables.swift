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
    func serialize() -> [String : AnyObject]? {
        guard let serializedUser = User.sharedUser.serialize(), let serializedDevice = Device.CurrentDevice.serialize() else {
            // ERROR
            return nil
        }
        
        switch self {
        case .ApplicationOpen(let date):
            return [
                "data": [
                    "type": "events",
                    "attributes": [
                        "object": "app",
                        "action": "open",
                        "time": date.timeIntervalSince1970,
                        "user": serializedUser,
                        "device": serializedDevice
                    ]
                ]
            ]
        case .DeviceUpdate(let date):
            return [
                "data": [
                    "type": "events",
                    "attributes": [
                        "object": "device",
                        "action": "update",
                        "time": date.timeIntervalSince1970,
                        "user": serializedUser,
                        "device": serializedDevice
                    ]
                ]
            ]
        case .DidEnterBeaconRegion(let region, _):
            return [
                "data": [
                    "type": "events",
                    "attributes": [
                        "action": "enter-beacon-region",
                        "identifier": region.identifier,
                        "uuid": region.proximityUUID.UUIDString,
                        "major-number": region.major!,
                        "minor-number": region.minor!
                    ]
                ]
            ]
        default:
            return nil
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
    
    func serialize() -> [String : AnyObject]? {
        let carrierName = CTTelephonyNetworkInfo().subscriberCellularProvider?.carrierName ?? NSNull()
        
        return [
            "udid": UIDevice.currentDevice().identifierForVendor!.UUIDString,
            "aid": ASIdentifierManager.sharedManager().advertisingIdentifier.UUIDString,
            "token": Device.pushToken ?? NSNull(),
            "locale-lang": NSLocale.preferredLanguages()[0],
            "locale-region": NSLocale.currentLocale().localeIdentifier,
            "time-zone": NSTimeZone.localTimeZone().name,
            "local-notifications-enabled": UIApplication.sharedApplication().currentUserNotificationSettings()?.types.contains(.Alert) ?? false,
            "remote-notifications-enabled": UIApplication.sharedApplication().isRegisteredForRemoteNotifications(),
            "background-mode-enabled": UIApplication.sharedApplication().backgroundRefreshStatus == .Available,
            "location-monitoring-enabled": CLLocationManager.authorizationStatus() == .AuthorizedAlways,
            "bluetooth-enabled": Device.bluetoothOn,
            "carrier": carrierName,
            "os-name": "iOS",
            "platform": "iOS",
            "manufacturer": "Apple",
            "os-version": "\(NSProcessInfo.processInfo().operatingSystemVersion.majorVersion).\(NSProcessInfo.processInfo().operatingSystemVersion.minorVersion).\(NSProcessInfo.processInfo().operatingSystemVersion.patchVersion)",
            "model": self.platform(),
            "sdk-version": "4.0.0"
        ]
    }
}

extension User : Serializable {
    func serialize() -> [String : AnyObject]? {
        return [
            "name": name ?? NSNull(),
            "email": email ?? NSNull(),
            "phone-number": phone ?? NSNull(),
            "alias": alias ?? NSNull(),
            "tags": tags ?? NSNull()
        ]
    }
}
