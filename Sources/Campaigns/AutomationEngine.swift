//
//  AutomationEngine.swift
//  RoverCampaigns
//
//  Created by Andrew Clunis on 2019-02-15.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import CoreData
import Foundation
import os

/// Observes emitted Rover events, and if there is an Automated Campaign is relevant for it, schedules an iOS notification for display.
open class AutomationEngine {
    private let eventPipeline: EventPipeline
    private let device: Device
    private let managedObjectContext: NSManagedObjectContext
    private var eventObserverChit: NSObjectProtocol?
    
    init(
        eventPipeline: EventPipeline,
        managedObjectContext: NSManagedObjectContext,
        device: Device
    ) {
        self.eventPipeline = eventPipeline
        self.managedObjectContext = managedObjectContext
        self.device = device
    }
    
    func beginObservingEvents() {
        self.eventObserverChit = self.eventPipeline.observeNewEvents { [weak self] events in
            guard let self = self else {
                return
            }
            
            do {
                try events.forEach { event in
                    let matchingCampaigns = try self.automatedCampaignsMatching(
                        event: event
                    )
                    os_log("%s campaigns match event.", String(describing: matchingCampaigns.count))
                    matchingCampaigns.forEach { matchingCampaign in
                        if let notificationDeliverable = matchingCampaign.deliverable as? CampaignNotificationDeliverable {
                            scheduleNotificationFromCampaignDeliverable(
                                notificationDeliverable,
                                withDelay: matchingCampaign.delayDateComponents
                            )
                        }
                    }
                }
            } catch {
                os_log("Unable to obtain campaigns that match : %s", log: .campaigns, type: .error, String(describing: error))
            }
        }
    }
    
    open func automatedCampaignsMatching(event: Event) throws -> [AutomatedCampaign] {
        return try AutomatedCampaignsFilter.automatedCampaignsMatching(
            event: event,
            forDevice: device.deviceSnapshot,
            in: managedObjectContext
        )
    }
}

extension AutomatedCampaign {
    var delayDateComponents: DateComponents {
        switch self.delayUnit {
        case .seconds:
            return DateComponents(second: self.delayValue)
        case .minutes:
            return DateComponents(minute: self.delayValue)
        case .hours:
            return DateComponents(hour: self.delayValue)
        case .days:
            return DateComponents(day: self.delayValue)
        }
    }
}
