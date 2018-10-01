//
//  ExperiencesAssembler.swift
//  RoverExperiences
//
//  Created by Sean Rucker on 2018-05-04.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UIKit

public struct ExperiencesAssembler: Assembler {
    public init() { }
    
    public func assemble(container: Container) {
        
        // MARK: Action (presentExperience)
        
        container.register(Action.self, name: "presentExperience", scope: .transient) { (resolver, campaignID: ID) in
            let identifier = ExperienceIdentifier.campaignID(id: campaignID)
            return resolver.resolve(Action.self, name: "presentExperience", arguments: identifier)!
        }
        
        container.register(Action.self, name: "presentExperience", scope: .transient) { (resolver, identifier: ExperienceIdentifier) in
            let viewControllerToPresent = resolver.resolve(UIViewController.self, name: "experience", arguments: identifier)!
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
            return ExperienceRouteHandler(actionProvider: { identifier in
                return resolver.resolve(Action.self, name: "presentExperience", arguments: identifier)!
            })
        }
        
        // MARK: UICollectionViewLayout (screen)
        
        container.register(UICollectionViewLayout.self, name: "screen", scope: .transient) { (resolver, screen: Screen) in
            return ScreenViewLayout(screen: screen)
        }
        
        // MARK: UIViewController (experience)
        
        container.register(UIViewController.self, name: "experience", scope: .transient) { (resolver, identifier: ExperienceIdentifier) in
            return ExperienceContainer(
                identifier: identifier,
                store: resolver.resolve(ExperienceStore.self)!,
                viewControllerProvider: { experience in
                    return resolver.resolve(UIViewController.self, name: "experience", arguments: experience)!
                }
            )
        }
        
        container.register(UIViewController.self, name: "experience", scope: .transient) { (resolver, experience: Experience) in
            return ExperienceViewController(
                rootViewController: resolver.resolve(UIViewController.self, name: "screen", arguments: experience, experience.homeScreen)!,
                experience: experience,
                eventQueue: resolver.resolve(EventQueue.self)!,
                sessionController: resolver.resolve(SessionController.self)!
            )
        }
        
        // MARK: UIViewController (screen)
        
        container.register(UIViewController.self, name: "screen", scope: .transient) { (resolver, experience: Experience, screen: Screen) in
            return ScreenViewController(
                collectionViewLayout: resolver.resolve(UICollectionViewLayout.self, name: "screen", arguments: screen)!,
                experience: experience,
                screen: screen,
                dispatcher: resolver.resolve(Dispatcher.self)!,
                eventQueue: resolver.resolve(EventQueue.self)!,
                imageStore: resolver.resolve(ImageStore.self)!,
                sessionController: resolver.resolve(SessionController.self)!,
                viewControllerProvider: { (experience, screen) in
                    return resolver.resolve(UIViewController.self, name: "screen", arguments: experience, screen)!
                },
                presentWebsiteActionProvider: { url in
                    return resolver.resolve(Action.self, name: "presentWebsite", arguments: url)!
                }
            )
        }
    }
    
    public func containerDidAssemble(resolver: Resolver) {
        if let router = resolver.resolve(Router.self) {
            let handler = resolver.resolve(RouteHandler.self, name: "experience")!
            router.addHandler(handler)
        }
    }
}
