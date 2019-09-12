//
//  ExperienceViewController.swift
//  Rover
//
//  Created by Sean Rucker on 2017-08-17.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

import UIKit

/// The `ExperienceViewController` displays a Rover experience and is responsible for navigation behavior between
/// its screens. It posts [`Notification`s](https://developer.apple.com/documentation/foundation/notification) through
/// the default [`NotificationCenter`](https://developer.apple.com/documentation/foundation/notificationcenter) when it
/// is presented, dismissed and viewed.
///
/// When the `ExperienceViewController` navigates to a Rover screen, it instantiates a view controller by calling its
/// factory method `screenViewController(experience:screen:)`. The default implementation returns an instance of
/// `ScreenViewController` but you can override this method if you wan to use a different view controller.
open class ExperienceViewController: UINavigationController {
    public let experience: Experience
    public let campaignID: String?
    
    #if swift(>=4.2)
    override open var childForStatusBarStyle: UIViewController? {
        return self.topViewController
    }
    #else
    override open var childViewControllerForStatusBarStyle: UIViewController? {
        return self.topViewController
    }
    #endif
    
    public init(experience: Experience, campaignID: String?, initialScreenID: String? = nil) {
        self.experience = experience
        self.campaignID = campaignID
        super.init(nibName: nil, bundle: nil)
        
        let homeScreen: Screen
        if let initialScreenID = initialScreenID {
            homeScreen = experience.screens.first { $0.id == initialScreenID } ?? experience.homeScreen
        } else {
            homeScreen = experience.homeScreen
        }
        
        let homeScreenViewController = screenViewController(
            experience: experience,
            screen: homeScreen
        )
        
        viewControllers = [homeScreenViewController]
    }
    
    @available(*, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Notifications
    
    private var sessionIdentifier: String {
        var identifier = "experience-\(experience.id)"
        
        if let campaignID = self.campaignID {
            identifier = "\(identifier)-campaign-\(campaignID)"
        }
        
        return identifier
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
    
    // MARK: Factories
    
    open func screenViewController(experience: Experience, screen: Screen) -> ScreenViewController {
        return ScreenViewController(
            collectionViewLayout: ScreenViewLayout(screen: screen),
            experience: experience,
            campaignID: self.campaignID,
            screen: screen,
            viewControllerFactory: { [weak self] experience, screen in
                self?.screenViewController(experience: experience, screen: screen)
            }
        )
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
