//
//  CampaignsAssembler.swift
//  RoverCampaigns
//
//  Created by Andrew Clunis on 2018-12-17.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation
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

extension CampaignsAssembler : Assembler {
    public func assemble(container: Container) {
        // MARK: InfluenceTracker
        
        container.register(InfluenceTracker.self) { resolver in
            return InfluenceTrackerService(
                influenceTime: self.influenceTime,
                eventPipeline: resolver.resolve(EventPipeline.self),
                notificationCenter: NotificationCenter.default,
                userDefaults: UserDefaults(suiteName: self.appGroup)!
            )
        }
        
        // MARK: NotificationHandler
        
        container.register(NotificationHandler.self) { resolver in
            let websiteViewControllerProvider: NotificationCenterViewController.WebsiteViewControllerProvider = { [weak resolver] url in
                return resolver?.resolve(UIViewController.self, name: "website", arguments: url)!
            }
            
            return NotificationHandlerService(
                influenceTracker: resolver.resolve(InfluenceTracker.self)!,
                notificationStore: resolver.resolve(NotificationStore.self)!,
                eventPipeline: resolver.resolve(EventPipeline.self)!,
                websiteViewControllerProvider: websiteViewControllerProvider
            )
        }
    }
    
    public func containerDidAssemble(resolver: Resolver) {
        if isInfluenceTrackingEnabled {
            let influenceTracker = resolver.resolve(InfluenceTracker.self)!
            influenceTracker.startMonitoring()
        }
    }
}
