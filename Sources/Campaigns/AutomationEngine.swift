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

/// Observes emitted Rover events, and if there is an Automated Campaign is relevant for it, schedules an iOS notification for display.
class AutomationEngine {
    private let eventPipeline: EventPipeline
    private let device: Device
    private let managedObjectContext: NSManagedObjectContext
    private let automatedCampaignsFilter: AutomatedCampaignsFilter
    private var eventObserverChit: NSObjectProtocol?
    
    init(
        eventPipeline: EventPipeline,
        managedObjectContext: NSManagedObjectContext,
        automatedCampaignsFilter: AutomatedCampaignsFilter,
        device: Device
    ) {
        self.eventPipeline = eventPipeline
        self.managedObjectContext = managedObjectContext
        self.automatedCampaignsFilter = automatedCampaignsFilter
        self.device = device
    }
    
    func beginObservingEvents() {
        self.eventObserverChit = self.eventPipeline.observeNewEvents { [weak self] events in
            guard let self = self else {
                return
            }
            do {
                try events.forEach { event in
                    let matchingCampaigns = try self.automatedCampaignsFilter.automatedCampaignsMatching(
                        event: event,
                        forDevice: self.device.snapshot,
                        in: self.managedObjectContext
                    )
                    os_log("%s campaigns match event.", String(describing: matchingCampaigns.count))
                    matchingCampaigns.forEach { matchingCampaign in
                        os_log("Campaign: %s", matchingCampaign.eventTriggerEventName)
                    }
                    // TODO: Activate Tap behaviour for the event.
                }
            } catch {
                os_log("Unable to obtain campaigns that match : %s", log: .campaigns, type: .error, String(describing: error))
            }
        }
    }
}
