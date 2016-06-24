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
    public func serialize() -> [String : AnyObject] {
        let serializedCustomer = Customer.sharedCustomer.serialize()
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
        case .DidOpenMessage(let message, let source, let date):
            timestamp = date
            serializedAttributes = [
                "object": "message",
                "action": "open",
                "source": source ?? NSNull(),
                "message-id": message.identifier
            ]
        default:
            timestamp = NSDate()
            serializedAttributes = [String : AnyObject]()
        }
        
        _swiftBugWorkaround(serializedAttributes: &serializedAttributes , timestamp: &timestamp)
        
        serializedAttributes["time"] = rvDateFormatter.stringFromDate(timestamp)
        serializedAttributes["user"] = serializedCustomer
        serializedAttributes["device"] = serializedDevice
        
        return [
            "data": [
                "type": "events",
                "attributes": serializedAttributes
            ]
        ]
    }
    
    func _swiftBugWorkaround(inout serializedAttributes serializedAttributes: [String: AnyObject], inout timestamp: NSDate) {
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
        let deviceToken: AnyObject = Device.pushToken ?? NSNull()
        
        return [
            "app-identifier": NSBundle.mainBundle().bundleIdentifier ?? "",
            "udid": UIDevice.currentDevice().identifierForVendor!.UUIDString,
            "aid": ASIdentifierManager.sharedManager().advertisingIdentifier.UUIDString,
            "ad-tracking": ASIdentifierManager.sharedManager().advertisingTrackingEnabled ,
            "token": deviceToken,
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

extension Customer : Serializable {
    public func serialize() -> [String : AnyObject] {
        let firstName: AnyObject = self.firstName ?? NSNull()
        let lastName: AnyObject = self.lastName ?? NSNull()
        let phoneNumber: AnyObject = self.phone ?? NSNull()
        let identifier: AnyObject = self.identifier ?? NSNull()
        let gender: AnyObject = self.gender ?? NSNull()
        let age: AnyObject = self.age ?? NSNull()
        let tags: AnyObject = self.tags ?? NSNull()
        let email: AnyObject = self.email ?? NSNull()
        
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
    public func serialize() -> [String : AnyObject] {
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
