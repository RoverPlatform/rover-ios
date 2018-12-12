//
//  ExperienceViewController.swift
//  RoverUI
//
//  Created by Sean Rucker on 2017-08-17.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

import UIKit

open class ExperienceViewController: UINavigationController {
    public let experience: Experience
    public let eventQueue: EventQueue
    public let sessionController: SessionController
    
    public init(rootViewController: UIViewController, experience: Experience, eventQueue: EventQueue, sessionController: SessionController) {
        self.experience = experience
        self.eventQueue = eventQueue
        self.sessionController = sessionController
        
        super.init(nibName: nil, bundle: nil)
        viewControllers = [rootViewController]
    }
    
    required public init?(coder aDecoder: NSCoder) {
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
        
        let attributes: [String: Any] = ["experience": experience]
        let event = EventInfo(name: "Experience Presented", namespace: "rover", attributes: Attributes.init(rawValue: attributes))
        eventQueue.addEvent(event)
        
        sessionController.registerSession(identifier: sessionIdentifier) { [attributes] duration in
            var attributes = attributes
            attributes["duration"] = duration
            return EventInfo(name: "Experience Viewed", namespace: "rover", attributes: Attributes.init(rawValue: attributes))
        }
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        let attributes: Attributes = ["experience": experience]
        let event = EventInfo(name: "Experience Dismissed", namespace: "rover", attributes: attributes)
        eventQueue.addEvent(event)
        
        sessionController.unregisterSession(identifier: sessionIdentifier)
    }
    
    #if swift(>=4.2)
    open override var childForStatusBarStyle: UIViewController? {
        return self.topViewController
    }
    #else
    open override var childViewControllerForStatusBarStyle: UIViewController? {
        return self.topViewController
    }
    #endif
}
