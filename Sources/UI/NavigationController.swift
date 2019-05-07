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
    public let campaignID: String?

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
    
    lazy var sessionIdentifier: String = {
        var identifier = "experience-\(experience.id)"
        
        if let campaignID = self.campaignID {
            identifier = "\(identifier)-campaign-\(campaignID)"
        }
        
        return identifier
    }()
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let viewController = parent as? RoverViewController {
            viewController.delegate?.viewController(
                viewController,
                didPresentExperience: experience,
                campaignID: campaignID
            )
        }
        
        var userInfo: [String: Any] = [
            "experience": experience.attributes
        ]
        
        if let campaignID = self.campaignID {
            userInfo["campaignID"] = campaignID
        }
        
        NotificationCenter.default.post(
            name: .RVExperiencePresented,
            object: self,
            userInfo: userInfo
        )
        
        sessionController.registerSession(identifier: sessionIdentifier) { [weak self] duration in
            if let viewController = self?.parent as? RoverViewController, let experience = self?.experience {
                viewController.delegate?.viewController(
                    viewController,
                    didViewExperience: experience,
                    campaignID: self?.campaignID,
                    duration: duration
                )
            }
            
            userInfo["duration"] = duration
            return Notification(
                name: .RVExperienceViewed,
                object: self,
                userInfo: userInfo
            )
        }
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if let viewController = parent as? RoverViewController {
            viewController.delegate?.viewController(
                viewController,
                didDismissExperience: experience,
                campaignID: campaignID
            )
        }
        
        var userInfo: [String: Any] = [
            "experience": experience.attributes
        ]
        
        if let campaignID = self.campaignID {
            userInfo["campaignID"] = campaignID
        }
        
        NotificationCenter.default.post(
            name: .RVExperienceDismissed,
            object: self,
            userInfo: userInfo
        )
        
        sessionController.unregisterSession(identifier: sessionIdentifier)
    }
    
    override open var childForStatusBarStyle: UIViewController? {
        return self.topViewController
    }
}
