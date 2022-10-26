//
//  ExperiencesAssembler.swift
//  RoverExperiences
//
//  Created by Sean Rucker on 2018-05-04.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UIKit
#if !COCOAPODS
import RoverFoundation
import RoverData
import RoverUI
#endif

public struct ExperiencesAssembler: Assembler {
    public init() { }
    
    public func assemble(container: Container) {
        
        // MARK: Action (presentExperience)
        
        container.register(Action.self, name: "presentExperience", scope: .transient) { (resolver, id: String, campaignID: String?, screenID: String?) in
            let viewControllerToPresent = resolver.resolve(UIViewController.self, name: "experience", arguments: id, campaignID, screenID)!
            return resolver.resolve(Action.self, name: "presentView", arguments: viewControllerToPresent)!
        }
        
        container.register(Action.self, name: "presentExperience", scope: .transient) { (resolver, universalLink: URL, campaignID: String?, screenID: String?) in
            let viewControllerToPresent = resolver.resolve(UIViewController.self, name: "experience", arguments: universalLink, campaignID, screenID)!
            return resolver.resolve(Action.self, name: "presentView", arguments: viewControllerToPresent)!
        }
        
        // MARK: ExperienceStore
        
        container.register(ExperienceStore.self) { resolver in
            let client = resolver.resolve(FetchExperienceClient.self)!
            return ExperienceStoreService(client: client)
        }
        
        // MARK: FetchExperienceClient
        
        container.register(FetchExperienceClient.self) { resolver in
            return resolver.resolve(HTTPClient.self)!
        }
        
        // MARK: RouteHandler (experience)
        
        container.register(RouteHandler.self, name: "experience") { resolver in            
            let idActionProvider: (String, String?, String?) -> Action? = { [weak resolver] id, campaignID, screenID in
                resolver?.resolve(Action.self, name: "presentExperience", arguments: id, campaignID, screenID)
            }
            
            let universalLinkActionProvider: (URL, String?, String?) -> Action? = { [weak resolver] universalLink, campaignID, screenID in
                resolver?.resolve(Action.self, name: "presentExperience", arguments: universalLink, campaignID, screenID)
            }
            
            return ExperienceRouteHandler(
                idActionProvider: idActionProvider,
                universalLinkActionProvider: universalLinkActionProvider
            )
        }
        
        // MARK: Services
        container.register(ConversionsContextProvider.self) { resolver in
                   resolver.resolve(ExperienceConversionsManager.self)!
               }
        
        container.register(ExperienceConversionsManager.self) { resolver in
            ExperienceConversionsManager()
        }
        
        // MARK: RoverObserver
        
        container.register(RoverObserver.self) { resolver in
            RoverObserver(eventQueue: resolver.resolve(EventQueue.self)!, conversionsManager: resolver.resolve(ExperienceConversionsManager.self)!)
        }
        
        // MARK: UIViewController (experience)
        
        container.register(UIViewController.self, name: "experience", scope: .transient) { (resolver, id: String, campaignID: String?, screenID: String?) in
            let viewController = RoverViewController()
            viewController.loadExperience(id: id, campaignID: campaignID, initialScreenID: screenID)
            return viewController
        }
        
        container.register(UIViewController.self, name: "experience", scope: .transient) { (resolver, universalLink: URL, campaignID: String?, screenID: String?) in
            let viewController = RoverViewController()
            viewController.loadExperience(universalLink: universalLink, campaignID: campaignID, initialScreenID: screenID)
            return viewController
        }
        
        // MARK: Analytics
        //TODO: adjust analytics to match the rest of the SDK
        Analytics.shared.enable()
    }
    
    public func containerDidAssemble(resolver: Resolver) {
        if let router = resolver.resolve(Router.self) {
            let handler = resolver.resolve(RouteHandler.self, name: "experience")!
            router.addHandler(handler)
        }
        
        resolver.resolve(RoverObserver.self)?.enable()
    }
}
