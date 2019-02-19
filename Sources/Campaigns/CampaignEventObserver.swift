//
//  CampaignEventObserver.swift
//  RoverCampaigns
//
//  Created by Andrew Clunis on 2019-02-15.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation
import CoreData
import os

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
        self.eventObserverChit = self.eventPipeline.observers.add(block: { [self] event in
            do {
                
                let matchingCampaigns = try campaignsMatching(event: event, forDevice: self.device.snapshot, in: self.managedObjectContext)
                os_log("%s campaigns match event.", String(describing: matchingCampaigns.count))
                matchingCampaigns.forEach({ (matchingCampaign) in
                    os_log("Campaign: %s", matchingCampaign.eventTriggerEventName)
                })
            } catch {
                os_log("Unable to obtain campaigns that match : %s", String(describing: error))
            }
        })
    }
}
