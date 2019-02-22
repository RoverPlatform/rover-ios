//
//  CampaignsAssembler.swift
//  RoverCampaigns
//
//  Created by Andrew Clunis on 2018-12-17.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreData
import Foundation
import os
import UIKit

public struct CampaignsAssembler {
    public var influenceTime: Int
    public var isInfluenceTrackingEnabled: Bool
    public var appGroup: String?
    
    public init(isInfluenceTrackingEnabled: Bool = true, influenceTime: Int = 120, appGroup: String? = nil) {
        self.isInfluenceTrackingEnabled = isInfluenceTrackingEnabled
        self.influenceTime = influenceTime
        self.appGroup = appGroup
    }
}

extension CampaignsAssembler: Assembler {
    public func assemble(container: Container) {
        // MARK: InfluenceTracker
        
        container.register(InfluenceTracker.self) { resolver in
            InfluenceTrackerService(
                influenceTime: self.influenceTime,
                eventPipeline: resolver.resolve(EventPipeline.self),
                notificationCenter: NotificationCenter.default,
                userDefaults: UserDefaults(suiteName: self.appGroup)!
            )
        }
        
        // MARK: NotificationHandler
        
        container.register(NotificationHandler.self) { resolver in
            let websiteViewControllerProvider: NotificationCenterViewController.WebsiteViewControllerProvider = { [weak resolver] url in
                resolver?.resolve(UIViewController.self, name: "website", arguments: url)!
            }
            
            return NotificationHandlerService(
                influenceTracker: resolver.resolve(InfluenceTracker.self)!,
                eventPipeline: resolver.resolve(EventPipeline.self)!,
                websiteViewControllerProvider: websiteViewControllerProvider
            )
        }
        
        // MARK: Automated Campaigns
        
        container.register(AutomatedCampaignsFilter.self) { resolver in
            AutomatedCampaignsFilter(
                managedObjectContext: resolver.resolve(NSManagedObjectContext.self, name: "backgroundContext")!
            )
        }
        
        container.register(AutomationEngine.self) { resolver in
            AutomationEngine(
                eventPipeline: resolver.resolve(EventPipeline.self)!,
                managedObjectContext: resolver.resolve(NSManagedObjectContext.self, name: "backgroundContext")!,
                automatedCampaignsFilter: resolver.resolve(AutomatedCampaignsFilter.self)!,
                device: resolver.resolve(Device.self)!
            )
        }
    }

    public func containerDidAssemble(resolver: Resolver) {
        if isInfluenceTrackingEnabled {
            let influenceTracker = resolver.resolve(InfluenceTracker.self)!
            influenceTracker.startMonitoring()
        }
        
        resolver.resolve(AutomationEngine.self)!.beginObservingEvents()
    }
}
