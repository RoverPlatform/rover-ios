//
//  Event.swift
//  Pods
//
//  Created by Ata Namvari on 2016-01-25.
//
//

import Foundation
import CoreLocation

public enum Event {
    case DidEnterBeaconRegion(CLBeaconRegion, BeaconConfiguration?)
    case DidExitBeaconRegion(CLBeaconRegion, BeaconConfiguration?)
    
    func call(observer: RoverObserver) {
        switch self {
        case .DidEnterBeaconRegion(let region, let config):
            guard let config = config else { return }
            observer.roverDidEnterBeaconRegion?(region, config: config)
        case .DidExitBeaconRegion(let region, let config):
            guard let config = config else { return }
            observer.roverDidExitBeaconRegion?(region, config: config)
        }
    }
    
}


extension Event : Serializable {
    public func serialize() -> [String : AnyObject]? {
        switch self {
        case .DidEnterBeaconRegion(let region, _):
            return [
                "data": [
                    "type": "events",
                    "attributes": [
                        "action": "enter-beacon-region",
                        "protocol": "iBeacon",
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

//extension Event : Mappable {
//    
//    func map(JSON: [String: Any]) {
////        switch self {
////        case .DidEnterBeaconRegion(let region):
////            region.someValue = ""
////        }
//    }
//    
//    init(JSON: [String : AnyObject]) {
//        self = .DidEnterBeaconRegion(CLBeaconRegion(), nil)
//    }
//    
//    
//    static func munc() -> Event {
//        return .DidEnterBeaconRegion(CLBeaconRegion(), nil)
//    }
//}


public class BeaconConfiguration : NSObject {
    let identifier: String
    
    let UUID: NSUUID
    let majorNumber: Int16
    let minorNumber: Int16
    
    init(UUID: NSUUID, majorNumber: Int16, minorNumber: Int16, identifier: String) {
        self.identifier = identifier
        self.UUID = UUID
        self.majorNumber = majorNumber
        self.minorNumber = minorNumber
    }
}

extension BeaconConfiguration : Mappable {
    static func instance(JSON: [String : AnyObject], included: [Any]?) -> BeaconConfiguration? {
        return nil
    }
}

