// Copyright (c) 2020-present, Rover Labs, Inc. All rights reserved.
// You are hereby granted a non-exclusive, worldwide, royalty-free license to use,
// copy, modify, and distribute this software in source code or binary form for use
// in connection with the web services and APIs provided by Rover.
//
// This copyright notice shall be included in all copies or substantial portions of 
// the software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import UIKit
import RoverFoundation
import RoverData
import RoverUI

public struct ExperiencesAssembler: Assembler {
    public init() { }

    public func assemble(container: Container) {
        
        // MARK: Action (presentExperience)
        
        container.register(Action.self, name: "presentExperience", scope: .transient) { (resolver, url: URL) in
            let viewControllerToPresent = resolver.resolve(UIViewController.self, name: "experience", arguments: url)!
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
        
        // MARK: NewExperienceManager
        
        container.register(ExperienceManager.self) { resolver in
            let eventQueue = resolver.resolve(EventQueue.self)!
            let userInfoContextProvider = resolver.resolve(UserInfoContextProvider.self)!
            let conversionsTracker = resolver.resolve(ConversionsTrackerService.self)!
            return ExperienceManager(
                eventQueue: eventQueue,
                userInfoContextProvider: userInfoContextProvider,
                conversionsTracker: conversionsTracker)
        }
        
        // MARK: RouteHandler (experience)
        
        container.register(RouteHandler.self, name: "experience") { resolver in
            let actionProvider: (URL) -> Action? = { [weak resolver] url in
                resolver?.resolve(Action.self, name: "presentExperience", arguments: url)
            }
            
            let associatedDomains = resolver.resolve([String].self, name: "associatedDomains")!
            
            return ExperienceRouteHandler(
                actionProvider: actionProvider,
                associatedDomains: associatedDomains
            )
        }

        
        // MARK: RoverObserver
        
        container.register(RoverObserver.self) { resolver in
            RoverObserver(eventQueue: resolver.resolve(EventQueue.self)!, conversionsTracker: resolver.resolve(ConversionsTrackerService.self)!)
        }
        
        // MARK: UIViewController (experience)
        
        container.register(UIViewController.self, name: "experience", scope: .transient) { (resolver, url: URL) in
            let viewController = ExperienceViewController()
            viewController.loadExperience(with: url)
            return viewController
        }
    }
    
    public func containerDidAssemble(resolver: Resolver) {
        if let router = resolver.resolve(Router.self) {
            let handler = resolver.resolve(RouteHandler.self, name: "experience")!
            router.addHandler(handler)
        }
        
        resolver.resolve(RoverObserver.self)?.enable()
        
        // MARK: Analytics
        //TODO: adjust analytics to match the rest of the SDK
        MiniAnalytics.shared.enable()
    }
}
