//
//  Notification.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-03-18.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation

typealias RoverEventName = String

extension Notification {
    /// Build a Notification to be dispatched on the iOS Notification Center for a Rover event.
    init(forRoverEvent eventName: RoverEventName, withAttributes attributes: [String: Any]) {
        let mergedAttributes = attributes.merging(["name": eventName]) { a, _ in a }
        self.init(name: Notification.Name("RoverEmitterDidEmitEvent"), object: nil, userInfo: mergedAttributes)
    }
}

// A signle file with all Notification.Name extensions provides a nice self-documenting file for developers to look at
extension Notification.Name {
    
    /// This event is dispatched when an experience is viewed. The userInfo will include properties for the experienceID, screenID etc....
    public static let RVExperienceViewed = Notification.Name("io.rover.ExperienceViewed")
    
    // The RV prefix adds discoverability through auto-complete
    public static let RVScreenViewed = Notification.Name("io.rover.ScreenViewed")
    
    // The io.rover namespace on the raw value ensures no collisions
    public static let RVBlockTapped = Notification.Name("io.rover.BlockTapped")
}

// Using Notification.Name constants facilitates the standard (compile-checked) approach of targeting specific events
NotificationCenter.default.addObserver(forName: .RVBlockTapped, object: nil, queue: nil) { notification in

}

// Campaigns SDK dumping all Rover events into the event queue
NotificationCenter.default.addObserver(forName: nil, object: nil, queue: nil) { notification in
    
    /// Check if this is a Rover event, otherwise no-op
    guard notification.name.rawValue.starts(with: "io.rover") else {
        return
    }
    
    // Remove the prefix from the event name and "humanzie" the rest of the name.
    // This is predicated on the idea that we will name the raw value of the events in the Rover SDK to match what we're using today
    let count = "io.rover".count
    let name = notification.name.rawValue.dropFirst(count).humanize()
    
    let eventInfo = EventInfo(name: name, attributes: ...)
}

// Warning, the below code was copied from the internet untested ;)
extension String.SubSequence {
    func humanize() -> String {
        return unicodeScalars.reduce("") {
            if CharacterSet.uppercaseLetters.contains($1) {
                return ($0 + " " + String($1))
            }
            else {
                return $0 + String($1)
            }
        }
    }
}
