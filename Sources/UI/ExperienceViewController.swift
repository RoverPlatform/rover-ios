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
        
        NotificationCenter.default.post(
            name: ExperienceViewController.experiencePresentedNotification,
            object: self,
            userInfo: [
                ExperienceViewController.experienceUserInfoKey: experience
            ]
        )
        
        sessionController.registerSession(identifier: sessionIdentifier) { [weak self, experience] duration in
            NotificationCenter.default.post(
                name: ExperienceViewController.experienceViewedNotification,
                object: self,
                userInfo: [
                    ExperienceViewController.experienceUserInfoKey: experience,
                    ExperienceViewController.durationUserInfoKey: duration
                ]
            )
        }
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        NotificationCenter.default.post(
            name: ExperienceViewController.experienceDismissedNotification,
            object: self,
            userInfo: [
                ExperienceViewController.experienceUserInfoKey: experience
            ]
        )
        
        sessionController.unregisterSession(identifier: sessionIdentifier)
    }
}

// MARK: Notification Names

extension ExperienceViewController {
    /// The `ExperienceViewController` sends this notification when it is presented.
    public static let experiencePresentedNotification = Notification.Name("io.rover.experiencePresentedNotification")
    
    /// The `ExperienceViewController` sends this notification when it is dismissed.
    public static let experienceDismissedNotification = Notification.Name("io.rover.experienceDismissedNotification")
    
    /// The `ExperienceViewController` sends this notification when a user finishes viewing an experience. The user
    /// starts viewing an experience when the view controller is presented and finishes when it is dismissed. The
    /// duration the user viewed the experience is included in the `durationUserInfoKey`.
    ///
    /// If the user quickly dismisses the view controller and presents it again (or backgrounds the app and restores it)
    /// the view controller considers this part of the same "viewing session". The notification is not sent until the
    /// user dismisses the view controller and a specified time passes (default is 15 seconds).
    ///
    /// This notification is useful for tracking the amount of time users spend viewing an experience. However if you
    /// want to be notified immediately when a user views an experience you should use the
    /// `experiencePresentedNotification`.
    public static let experienceViewedNotification = Notification.Name("io.rover.experienceViewedNotification")
}

// MARK: User Info Keys

extension ExperienceViewController {
    /// A key whose value is the `Experience` associated with the `ExperienceViewController`.
    public static let experienceUserInfoKey = "experienceUserInfoKey"
    
    /// A key whose value is a `Double` representing the duration of an experience session.
    public static let durationUserInfoKey = "durationUserInfoKey"
}