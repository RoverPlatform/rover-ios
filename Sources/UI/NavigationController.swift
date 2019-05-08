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
        
        guard let viewController = parent as? RoverViewController else {
            return
        }
        
        viewController.delegate?.viewController(viewController, didPresentExperience: experience)
        
        NotificationCenter.default.post(
            name: RoverViewController.experiencePresentedNotification,
            object: viewController,
            userInfo: [
                RoverViewController.experienceUserInfoKey: experience
            ]
        )
        
        sessionController.registerSession(
            identifier: sessionIdentifier,
            completionHandler: { [weak viewController, experience] duration in
                guard let viewController = viewController else {
                    return nil
                }
                
                viewController.delegate?.viewController(
                    viewController,
                    didViewExperience: experience,
                    duration: duration
                )
                
                return Notification(
                    name: RoverViewController.experienceViewedNotification,
                    object: viewController,
                    userInfo: [
                        RoverViewController.experienceUserInfoKey: experience,
                        RoverViewController.durationUserInfoKey: duration
                    ]
                )
            }
        )
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        guard let viewController = parent as? RoverViewController else {
            return
        }
        
        viewController.delegate?.viewController(viewController, didDismissExperience: experience)
        
        NotificationCenter.default.post(
            name: RoverViewController.experienceDismissedNotification,
            object: viewController,
            userInfo: [
                RoverViewController.experienceUserInfoKey: experience
            ]
        )
        
        sessionController.unregisterSession(identifier: sessionIdentifier)
    }
    
    override open var childForStatusBarStyle: UIViewController? {
        return self.topViewController
    }
}
