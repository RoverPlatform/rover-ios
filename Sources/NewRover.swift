//
//  Rover.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-03-13.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation
import UIKit
import SafariServices

/// This is
open class Environment {
    public var accountToken: String?
    public var endpoint: URL = URL(string: "https://api.rover.io/graphql")!
    


    open lazy private(set) var urlSession = URLSession(configuration: URLSessionConfiguration.default)

    open func presentWebsite(sourceViewController: UIViewController, url: URL) {
        // open a link using an embedded web browser controller.
        let webViewController = SFSafariViewController(url: url)
        sourceViewController.present(webViewController, animated: true, completion: nil)
    }

    open lazy private(set) var httpClient = HTTPClient(session: urlSession) {
        return AuthContext(
            accountToken: self.accountToken,
            endpoint: URL(string: "https://api.rover.io/graphql")!
        )
    }
    
    open lazy private(set) var experienceStore = ExperienceStoreService(
        client: httpClient
    )
    
    open lazy private(set) var imageStore = ImageStoreService(session: urlSession)
    
    open func presentWebsiteViewController(url: URL) -> UIViewController {
        return SFSafariViewController(url: url)
    }
    
    open func screenViewLayout(screen: Screen) -> UICollectionViewLayout {
        return ScreenViewLayout(screen: screen)
    }

    open func screenViewController(experience: Experience, screen: Screen) -> ScreenViewController {
        return ScreenViewController(
            collectionViewLayout: screenViewLayout(screen: screen),
            experience: experience,
            screen: screen,
            eventQueue: eventQueue,
            imageStore: imageStore,
            sessionController: sessionController,
            viewControllerProvider: { (experience: Experience, screen: Screen) in
                return self.screenViewController(experience: experience, screen: screen)
            },
            presentWebsite: { (url: URL, sourceViewController: UIViewController) in
                self.presentWebsite(sourceViewController: sourceViewController, url: url)
            }
        )
    }
    
    // TODO: doomed/ripout
    open lazy private(set) var eventQueue = FakeEventQueue()
    open lazy private(set) var sessionController = SessionControllerService(eventQueue: eventQueue, keepAliveTime: 30)
    open lazy private(set) var dispatcherService = DispatcherService()
}

class MyOverriddenRover : Environment {
    private let myCustomDispatcherService = DispatcherService()
    override var dispatcherService: DispatcherService { return self.myCustomDispatcherService }
}

/// This is the central
public var Config: Environment = Environment()


// I will have to use classes instead of structs for one big reason  With classes, I will be able to self-reference, needed for passing dependencies down, AND also supporting callbacks for lazy values. However, with classes you lose the ability to have synthesized initializers. However, this needs public visibility, so this loses that anyway.
// Having to reason about all these constraints is arguably something of a misfeature of Swift, but that could maybe be argued on the basis of optimization.
