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
        homeScreenViewController: UIViewController,
        experience: Experience,
        campaignID: String?
    ) {
        self.experience = experience
        self.campaignID = campaignID
        
        super.init(nibName: nil, bundle: nil)
        viewControllers = [homeScreenViewController]
    }
    
    @available(*, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        var userInfo: [String: Any] = [
            ExperienceViewController.experienceUserInfoKey: experience
        ]
        
        if let campaignID = campaignID {
            userInfo[ExperienceViewController.campaignIDUserInfoKey] = campaignID
        }
        
        NotificationCenter.default.post(
            name: ExperienceViewController.experiencePresentedNotification,
            object: self,
            userInfo: userInfo
        )
        
        SessionController.shared.registerSession(identifier: sessionIdentifier) { [weak self] duration in
            userInfo[ExperienceViewController.durationUserInfoKey] = duration
            NotificationCenter.default.post(
                name: ExperienceViewController.experienceViewedNotification,
                object: self,
                userInfo: userInfo
            )
        }
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        var userInfo: [String: Any] = [
            ExperienceViewController.experienceUserInfoKey: experience
        ]
        
        if let campaignID = campaignID {
            userInfo[ExperienceViewController.campaignIDUserInfoKey] = campaignID
        }
        
        NotificationCenter.default.post(
            name: ExperienceViewController.experienceDismissedNotification,
            object: self,
            userInfo: userInfo
        )
        
        SessionController.shared.unregisterSession(identifier: sessionIdentifier)
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
    /// user dismisses the view controller and a specified time passes (default is 10 seconds).
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
    
    /// A key whose value is an optional `String` containing the `campaignID` passed into the `RoverViewController` when
    /// it was initialized.
    public static let campaignIDUserInfoKey = "campaignIDUserInfoKey"
    
    /// A key whose value is a `Double` representing the duration of an experience session.
    public static let durationUserInfoKey = "durationUserInfoKey"
}
