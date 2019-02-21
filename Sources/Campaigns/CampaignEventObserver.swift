//
//  CampaignEventObserver.swift
//  RoverCampaigns
//
//  Created by Andrew Clunis on 2019-02-15.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import CoreData
import Foundation
import os

/// Observes emitted Rover events, and if an Automated Campaign is relevant for it, triggers it.
class CampaignEventObserver {
    private let eventPipeline: EventPipeline
    private let device: Device
    private let managedObjectContext: NSManagedObjectContext
    private var eventObserverChit: NSObjectProtocol?
    
    init(eventPipeline: EventPipeline, managedObjectContext: NSManagedObjectContext, device: Device) {
        self.eventPipeline = eventPipeline
        self.managedObjectContext = managedObjectContext
        self.device = device
    }
    
    func beginObservingEvents() {
        self.eventObserverChit = self.eventPipeline.observers.add { [self] event in
            do {
                let matchingCampaigns = try automatedCampaignsMatching(event: event, forDevice: self.device.snapshot, in: self.managedObjectContext)
                os_log("%s campaigns match event.", String(describing: matchingCampaigns.count))
                matchingCampaigns.forEach { matchingCampaign in
                    os_log("Campaign: %s", matchingCampaign.eventTriggerEventName)
                }
                // TODO: Activate Tap behaviour for the event.
            } catch {
                os_log("Unable to obtain campaigns that match : %s", String(describing: error))
            }
        }
    }
}
