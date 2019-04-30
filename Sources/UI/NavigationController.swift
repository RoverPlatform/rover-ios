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
        
        let userInfo: [String: Any?] = [
            "experience": experience.attributes,
            "campaignID": self.campaignID
        ]
        
        NotificationCenter.default.post(
            name: .RVExperiencePresented,
            object: self,
            userInfo: userInfo.compactMapValues { $0 }
        )
        
        sessionController.registerSession(identifier: sessionIdentifier) { duration in
            Notification(
                name: .RVExperienceViewed,
                object: self,
                userInfo: userInfo.merging(["duration": duration]) { a, _ in a }.compactMapValues { $0 }
            )
        }
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        let userInfo: [String: Any?] = [
            "experience": experience.attributes,
            "campaignID": self.campaignID
        ]
        
        NotificationCenter.default.post(
            name: .RVExperienceDismissed,
            object: self,
            userInfo: userInfo.compactMapValues { $0 }
        )
        
        sessionController.unregisterSession(identifier: sessionIdentifier)
    }
    
    override open var childForStatusBarStyle: UIViewController? {
        return self.topViewController
    }
}
