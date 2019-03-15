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

/// This is the central entry point to the Rover SDK.  It contains the entire graph of Rover and its internal dependencies, as a global, static singleton.
public var Config: Environment = Environment()

/// This object encapsulates the entire object graph of the Rover SDK and all of its internal dependencies.
///
/// It effectively serves as the backplane of the Rover SDK.
open class Environment {
    /// Set your Rover Account Token (API Key) here.
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
    
    open func experienceNavigationViewController(experience: Experience) -> ExperienceNavigationViewController {
        let homeScreenViewController = screenViewController(experience: experience, screen: experience.homeScreen)
        return ExperienceNavigationViewController(
            eventQueue: eventQueue,
            sessionController: self.sessionController,
            homeScreenViewController: homeScreenViewController,
            experience: experience
        )
    }
    
    // TODO: doomed/ripout
    open lazy private(set) var eventQueue = FakeEventQueue()
    open lazy private(set) var sessionController = SessionController()
    open lazy private(set) var dispatcherService = DispatcherService()
}
