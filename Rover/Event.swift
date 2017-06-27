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
    
    case applicationOpen(date: Date)
    case deviceUpdate(date: Date)
    
    case didUpdateLocation(CLLocation, date: Date)
    
    case didEnterBeaconRegion(CLBeaconRegion, config: BeaconConfiguration?, place: Place?, date: Date)
    case didExitBeaconRegion(CLBeaconRegion, config: BeaconConfiguration?, place: Place?,  date: Date)

    case didEnterCircularRegion(CLCircularRegion, place: Place?, date: Date)
    case didExitCircularRegion(CLCircularRegion, place: Place?, date: Date)
    
    case didReceiveMessage(Message)
    case didOpenMessage(Message, source: String, date: Date)
    
    case didEnterGimbalPlace(id: String, date: Date)
    case didExitGimbalPlace(id: String, date: Date)
    
    case didLaunchExperience(Experience, session: String, date: Date, campaignID: String?)
    case didDismissExperience(Experience, session: String, date: Date, campaignID: String?)
    case didViewScreen(Screen, experience: Experience, fromScreen: Screen?, fromBlock: Block?, session: String, date: Date, campaignID: String?)
    case didPressBlock(Block, screen: Screen, experience: Experience, session: String, date: Date, campaignID: String?)
    
    var properties: [String: Any] {
        switch self {
        case .didUpdateLocation(let location, let date):
            return ["location": location, "date": date]
        case .didEnterBeaconRegion(let region, let config, let location, let date):
            return ["region": region, "config": config, "location": location, "date": date]
        case .didExitBeaconRegion(let region, let config, let location, let date):
            return ["region": region, "config": config, "location": location, "date": date]
        case .didEnterCircularRegion(let region, let location, let date):
            return ["region": region, "location": location, "date": date]
        case .didExitCircularRegion(let region, let location, let date):
            return ["region": region, "location": location, "date": date]
        case .didOpenMessage(let message, let source, let date):
            return ["message": message, "source": source, "date": date]
        case .didEnterGimbalPlace(let placeId, let date):
            return ["gimbalPlaceId": placeId, "date": date]
        case .didEnterGimbalPlace(let placeId, let date):
            return ["gimbalPlaceId": placeId, "date": date]
        default:
            return [:]
        }
    }
    
}

extension Event {
    
    func call(_ observer: RoverObserver) {
        switch self {
        case .didEnterBeaconRegion(_, let config?, let place?, _):
            observer.didEnterBeaconRegion?(config: config, place: place)
        case .didExitBeaconRegion(_, let config?, let place?, _):
            observer.didExitBeaconRegion?(config: config, place: place)
        case .didEnterCircularRegion(_, let place?, _):
            observer.didEnterGeofence?(place: place)
        case .didExitCircularRegion(_, let place?, _):
            observer.didExitGeofence?(place: place)
        case .didReceiveMessage(let message):
            observer.didReceiveMessage?(message)
        default:
            break
        }
    }

}




