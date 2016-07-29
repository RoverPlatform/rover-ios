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
    
    case DidReceiveMessage(Message)
    case DidOpenMessage(Message, source: String, date: NSDate)
    
    case DidEnterGimbalPlace(id: String, date: NSDate)
    case DidExitGimbalPlace(id: String, date: NSDate)
    
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
        case .DidOpenMessage(let message, let source, let date):
            return ["message": message, "source": source, "date": date]
        case .DidEnterGimbalPlace(let placeId, let date):
            return ["gimbalPlaceId": placeId, "date": date]
        case .DidEnterGimbalPlace(let placeId, let date):
            return ["gimbalPlaceId": placeId, "date": date]
        default:
            return [:]
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
        case .DidReceiveMessage(let message):
            observer.didReceiveMessage?(message)
        default:
            break
        }
    }

}




