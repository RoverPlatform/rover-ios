//
//  ExperienceNavigationViewController.swift
//  Rover
//
//  Created by Sean Rucker on 2017-08-17.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

import UIKit

/// View controller responsible for navigation behaviour between screens of an Experience.
open class ExperienceNavigationViewController: UINavigationController {
    private let eventQueue: EventQueue
    private let sessionController: SessionController
    public let experience: Experience

    public init(
        eventQueue: EventQueue,
        sessionController: SessionController,
        homeScreenViewController: UIViewController,
        experience: Experience
    ) {
        self.eventQueue = eventQueue
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
        let event = EventInfo(name: "Experience Presented", namespace: "rover", attributes: attributes)
        eventQueue.addEvent(event)
        
        sessionController.registerSession(
            identifier: sessionIdentifier,
            sessionCompletedInfo: EventInfo(name: "Experience Viewed", namespace: "rover", attributes: attributes)
        )
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        let attributes = ["experience": experience.attributes]
        let event = EventInfo(name: "Experience Dismissed", namespace: "rover", attributes: attributes)
        eventQueue.addEvent(event)
        
        sessionController.unregisterSession(identifier: sessionIdentifier)
    }
    
    #if swift(>=4.2)
    override open var childForStatusBarStyle: UIViewController? {
        return self.topViewController
    }
    #else
    open override var childViewControllerForStatusBarStyle: UIViewController? {
        return self.topViewController
    }
    #endif
}
