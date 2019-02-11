//
//  Scribbles.swift
//  RoverCampaigns
//
//  Created by Andrew Clunis on 2019-02-08.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation

class CampaignUpdateObserver {
    
}

struct CampaignEventPipeline {
    // stage 1:  monitor for campaign updates.  do so right from Core Data.
    
//    init() {
//        NotificationCenter.default.addObserver(self, selector: #selector(contextObjectsDidChange(_:)), name: Notification.Name.NSManagedObjectContextObjectsDidChange, object: nil)
//    }
//
//    @objc
//    func contextObjectsDidChange(_ notification: Foundation.Notification) {
//
//    }
}

struct SegmentModel {
}

protocol Segmentable {
    var segment: SegmentModel { get }
}

extension AutomatedCampaign: Segmentable {
    var segment: SegmentModel {
        fatalError("stand-in")
    }
}

extension ScheduledCampaign: Segmentable {
    var segment: SegmentModel {
        fatalError("stand-in")
    }
}

extension Array where Element == Segmentable {
    // filter segmentables
    func filterForDevice(deviceSnapshot: DeviceSnapshot) {
        // TODO: evaluate predicates.
    }
}

struct CampaignNotificationPipeline {
    // whenever sync completes:
    let eventObserver: NSObjectProtocol?
    
    init(
        eventPipeline: EventPipeline
    ) {
        self.eventObserver = eventPipeline.observers.add { event in
            // STEP 1. Query for applicable scheduled campaigns and applicable automated campaigns.
            
            
            
            // STEP 2.
        }

    }
    
    private func 
}
