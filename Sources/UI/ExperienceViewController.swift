//
//  ExperienceViewController.swift
//  Rover
//
//  Created by Sean Rucker on 2017-08-17.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

import UIKit

/// View controller responsible for navigation behaviour between screens of an Experience.
open class ExperienceViewController: UINavigationController {
    private let sessionController: SessionController
    public let experience: Experience
    public let campaignID: String?
    
    override open var childForStatusBarStyle: UIViewController? {
        return self.topViewController
    }
    
    var roverViewController: RoverViewController? {
        return parent as? RoverViewController
    }
    
    var sessionIdentifier: String {
        var identifier = "experience-\(experience.id)"
        
        if let campaignID = self.campaignID {
            identifier = "\(identifier)-campaign-\(campaignID)"
        }
        
        return identifier
    }
    
    public init(
        sessionController: SessionController,
        homeScreenViewController: UIViewController,
        experience: Experience,
        campaignID: String?
    ) {
        self.experience = experience
        self.campaignID = campaignID
        self.sessionController = sessionController
        
        super.init(nibName: nil, bundle: nil)
        viewControllers = [homeScreenViewController]
    }
    
    @available(*, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        roverViewController?.didPresentExperience(experience)
        sessionController.registerSession(identifier: sessionIdentifier) { [weak self, experience] duration in
            self?.roverViewController?.didViewExperience(experience, duration: duration)
        }
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        roverViewController?.didDismissExperience(experience)
        sessionController.unregisterSession(identifier: sessionIdentifier)
    }
}
