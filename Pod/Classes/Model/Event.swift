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
    
    case DidEnterBeaconRegion(CLBeaconRegion, config: BeaconConfiguration?, place: Place?, date: NSDate)
    case DidExitBeaconRegion(CLBeaconRegion, config: BeaconConfiguration?, place: Place?,  date: NSDate)

    case DidEnterCircularRegion(CLCircularRegion, place: Place?, date: NSDate)
    case DidExitCircularRegion(CLCircularRegion, place: Place?, date: NSDate)
    
    case DidOpenMessage(identifier: String, source: String, date: NSDate)
    
    var properties: [String: Any] {
        switch self {
        case .DidUpdateLocation(let location, let date):
            return ["location": location, "date": date]
        case .DidEnterBeaconRegion(let region, let config, let location, let date):
            return ["region": region, "config": config, "location": location, "date": date]
        case .DidExitBeaconRegion(let region, let config, let location, let date):
            return ["region": region, "config": config, "location": location, "date": date]
        case .DidEnterCircularRegion(let region, let location, let date):
            return ["region": region, "location": location, "date": date]
        case .DidExitCircularRegion(let region, let location, let date):
            return ["region": region, "location": location, "date": date]
        case .DidOpenMessage(let identifier, let source, let date):
            return ["identifier": identifier, "source": source, "date": date]
        default:
            return [String: Any]()
        }
    }
    
}

extension Event {
    
    func call(observer: RoverObserver) {
        switch self {
        case .DidEnterBeaconRegion(_, let config?, let place?, _):
            observer.didEnterBeaconRegion?(config: config, place: place)
        case .DidExitBeaconRegion(_, let config?, let place?, _):
            observer.didExitBeaconRegion?(config: config, place: place)
        case .DidEnterCircularRegion(_, let place?, _):
            observer.didEnterGeofence?(place: place)
        case .DidExitCircularRegion(_, let place?, _):
            observer.didExitGeofence?(place: place)
        default:
            break
        }
    }

}




