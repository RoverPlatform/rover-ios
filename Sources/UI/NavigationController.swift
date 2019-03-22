//
//  NavigationController.swift
//  Rover
//
//  Created by Sean Rucker on 2017-08-17.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

import UIKit

/// View controller responsible for navigation behaviour between screens of an Experience.
open class NavigationController: UINavigationController {
    private let sessionController: SessionController
    public let experience: Experience

    public init(
        sessionController: SessionController,
        homeScreenViewController: UIViewController,
        experience: Experience
    ) {
        self.experience = experience
        self.sessionController = sessionController
        
        super.init(nibName: nil, bundle: nil)
        viewControllers = [homeScreenViewController]
    }
    
    @available(*, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var sessionIdentifier: String = {
        var identifier = "experience-\(experience.id)"
        
        if let campaignID = experience.campaignID {
            identifier = "\(identifier)-campaign-\(campaignID)"
        }
        
        return identifier
    }()
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let attributes: [String: Any] = ["experience": experience.attributes]
        
        NotificationCenter.default.post(
            Notification(forRoverEvent: .experiencePresented, withAttributes: attributes)
        )
        
        sessionController.registerSession(identifier: sessionIdentifier) { duration in
            Notification(forRoverEvent: .experienceViewed, withAttributes: attributes.merging(["duration": duration]) { a, _ in a })
        }
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        let attributes = ["experience": experience.attributes]
        
        NotificationCenter.default.post(
            Notification(forRoverEvent: .experienceDismissed, withAttributes: attributes)
        )
        
        sessionController.unregisterSession(identifier: sessionIdentifier)
    }
    
    override open var childForStatusBarStyle: UIViewController? {
        return self.topViewController
    }
}

extension RoverEventName {
    static var experiencePresented = "Experience Presented"
    static var experienceDismissed = "Experience Dismissed"
    static var experienceViewed = "Experience Viewed"
}
