//
//  UIAssembler.swift
//  RoverCampaignsUI
//
//  Created by Sean Rucker on 2018-05-21.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import SafariServices

public struct UIAssembler {
    public var urlSchemes: [String]
    
    public var sessionKeepAliveTime: Int
    
    public var isLifeCycleTrackingEnabled: Bool
    public var isVersionTrackingEnabled: Bool
    
    public init(urlSchemes: [String] = [], sessionKeepAliveTime: Int = 30, isLifeCycleTrackingEnabled: Bool = true, isVersionTrackingEnabled: Bool = true) {
        self.urlSchemes = urlSchemes
        self.sessionKeepAliveTime = sessionKeepAliveTime
        self.isLifeCycleTrackingEnabled = isLifeCycleTrackingEnabled
        self.isVersionTrackingEnabled = isVersionTrackingEnabled
    }
}

// MARK: Assembler

extension UIAssembler: Assembler {
    public func assemble(container: Container) {
        // MARK: Action (openURL)
        
        container.register(Action.self, name: "openURL", scope: .transient) { (_, url: URL) in
            OpenURLAction(url: url)
        }
        
        // MARK: Action (presentView)
        
        container.register(Action.self, name: "presentView", scope: .transient) { (_, viewControllerToPresent: UIViewController) in
            PresentViewAction(
                viewControllerToPresent: viewControllerToPresent,
                animated: true
            )
        }
        
        // MARK: Action (presentWebsite)
        
        container.register(Action.self, name: "presentWebsite", scope: .transient) { (resolver, url: URL) in
            let viewControllerToPresent = resolver.resolve(UIViewController.self, name: "website", arguments: url)!
            return resolver.resolve(Action.self, name: "presentView", arguments: viewControllerToPresent)!
        }
        
        // MARK: ImageStore
        
        container.register(ImageStore.self) { _ in
            let session = URLSession(configuration: URLSessionConfiguration.ephemeral)
            return ImageStoreService(session: session)
        }
        
        // MARK: LifeCycleTracker
        
        container.register(LifeCycleTracker.self) { resolver in
            let eventQueue = resolver.resolve(EventQueue.self)!
            let sessionController = resolver.resolve(SessionController.self)!
            return LifeCycleTrackerService(eventQueue: eventQueue, sessionController: sessionController)
        }
        
        // MARK: Router
        
        container.register(Router.self) { resolver in
            let dispatcher = resolver.resolve(Dispatcher.self)!
            return RouterService(urlSchemes: self.urlSchemes, dispatcher: dispatcher)
        }
        
        // MARK: SessionController
        
        container.register(SessionController.self) { [sessionKeepAliveTime] resolver in
            let eventQueue = resolver.resolve(EventQueue.self)!
            return SessionControllerService(eventQueue: eventQueue, keepAliveTime: sessionKeepAliveTime)
        }
        
        // MARK: UIViewController (website)
        
        container.register(UIViewController.self, name: "website", scope: .transient) { (_, url: URL) in
            SFSafariViewController(url: url)
        }
        
        // MARK: VersionTracker
        
        container.register(VersionTracker.self) { resolver in
            VersionTrackerService(
                bundle: Bundle.main,
                eventQueue: resolver.resolve(EventQueue.self)!,
                userDefaults: UserDefaults.standard
            )
        }
    }
    
    public func containerDidAssemble(resolver: Resolver) {
        if isVersionTrackingEnabled {
            resolver.resolve(VersionTracker.self)!.checkAppVersion()
        }
        
        if isLifeCycleTrackingEnabled {
            resolver.resolve(LifeCycleTracker.self)!.enable()
        }
    }
}
