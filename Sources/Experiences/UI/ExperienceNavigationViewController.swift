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
    public let experience: Experience

    public init(
        homeScreenViewController: UIViewController,
        experience: Experience
    ) {
        self.experience = experience
        
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
        
        
        // TODO: EVENT YO
        let attributes: [String: Any] = ["experience": experience]
//        let event = EventInfo(name: "Experience Presented", namespace: "rover", attributes: attributes)
//        eventQueue.addEvent(event)
        
//        sessionController.registerSession(identifier: sessionIdentifier) { [attributes] duration in
//            var attributes = attributes
//            attributes["duration"] = duration
//            return EventInfo(name: "Experience Viewed", namespace: "rover", attributes: attributes)
//        }
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // TODO: EVENT YO
//        let attributes: Attributes = ["experience": experience]
//        let event = EventInfo(name: "Experience Dismissed", namespace: "rover", attributes: attributes)
//        eventQueue.addEvent(event)
        
//        sessionController.unregisterSession(identifier: sessionIdentifier)
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
