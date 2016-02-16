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
    
    case ApplicationOpen(date: NSDate)
    case DeviceUpdate(date: NSDate)
    
    case DidUpdateLocation(CLLocation, date: NSDate)
    
    case DidEnterBeaconRegion(CLBeaconRegion, config: BeaconConfiguration?, date: NSDate)
    case DidExitBeaconRegion(CLBeaconRegion, config: BeaconConfiguration?, date: NSDate)

    case DidEnterCircularRegion(CLCircularRegion, location: Location?, date: NSDate)
    case DidExitCircularRegion(CLCircularRegion, location: Location?, date: NSDate)
}

extension Event {
    
    func call(observer: RoverObserver) {
        switch self {
        case .DidEnterBeaconRegion(_, let config?, _):
            observer.didEnterBeaconRegion?(config: config)
        case .DidExitBeaconRegion(_, let config?, _):
            observer.didExitBeaconRegion?(config: config)
        case .DidEnterCircularRegion(_, let location?, _):
            observer.didEnterGeofence?(location: location)
        case .DidExitCircularRegion(_, let location?, _):
            observer.didExitGeofence?(location: location)
        default:
            break
        }
    }
    
    var properties: [String: Any] {
        switch self {
        case .DidUpdateLocation(let location, let date):
            return ["location": location, "date": date]
        case .DidEnterBeaconRegion(let region, let config, let date):
            return ["region": region, "config": config, "date": date]
        case .DidExitBeaconRegion(let region, let config, let date):
            return ["region": region, "config": config, "date": date]
        case .DidEnterCircularRegion(let region, let location, let date):
            return ["region": region, "location": location, "date": date]
        case .DidExitCircularRegion(let region, let location, let date):
            return ["region": region, "location": location, "date": date]
        default:
            return [String: Any]()
        }
    }
}




