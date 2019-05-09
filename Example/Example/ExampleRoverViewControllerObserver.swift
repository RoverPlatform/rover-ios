//
//  ExampleRoverViewControllerObserver.swift
//  Example
//
//  Created by Sean Rucker on 2019-05-08.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation
import os.log
import Rover

class ExampleRoverViewControllerObserver {    
    private var observerTokens: [NSObjectProtocol] = []
    
    init() {
        startObservingRoverNotifications()
    }
    
    func startObservingRoverNotifications() {        
        observerTokens = [
            NotificationCenter.default.addObserver(forName: ExperienceViewController.experiencePresentedNotification, object: nil, queue: nil) { notification in
                let campaignID = notification.userInfo?[ExperienceViewController.campaignIDUserInfoKey] as? String
                let experience = notification.userInfo?[ExperienceViewController.experienceUserInfoKey] as! Experience
                os_log("Experience Presented: \"%@\" (campaignID=%@)", experience.name, campaignID ?? "none")
            },
            NotificationCenter.default.addObserver(forName: ExperienceViewController.experienceDismissedNotification, object: nil, queue: nil) { notification in
                let campaignID = notification.userInfo?[ExperienceViewController.campaignIDUserInfoKey] as? String
                let experience = notification.userInfo?[ExperienceViewController.experienceUserInfoKey] as! Experience
                os_log("Experience Dismissed: \"%@\" (campaignID=%@)", experience.name, campaignID ?? "none")
            },
            NotificationCenter.default.addObserver(forName: ExperienceViewController.experienceViewedNotification, object: nil, queue: nil) { notification in
                let campaignID = notification.userInfo?[ExperienceViewController.campaignIDUserInfoKey] as? String
                let experience = notification.userInfo?[ExperienceViewController.experienceUserInfoKey] as! Experience
                let duration = notification.userInfo?[ExperienceViewController.durationUserInfoKey] as! Double
                os_log("Experience Viewed: \"%@\" (campaignID=%@), for %f seconds", experience.name, campaignID ?? "none", duration)
            },
            NotificationCenter.default.addObserver(forName: ScreenViewController.screenPresentedNotification, object: nil, queue: nil) { notification in
                let screen = notification.userInfo?[ScreenViewController.screenUserInfoKey] as! Screen
                os_log("Screen Presented: \"%@\"", screen.name)
            },
            NotificationCenter.default.addObserver(forName: ScreenViewController.screenDismissedNotification, object: nil, queue: nil) { notification in
                let screen = notification.userInfo?[ScreenViewController.screenUserInfoKey] as! Screen
                os_log("Screen Dismissed: \"%@\"", screen.name)
            },
            NotificationCenter.default.addObserver(forName: ScreenViewController.screenViewedNotification, object: nil, queue: nil) { notification in
                let screen = notification.userInfo?[ScreenViewController.screenUserInfoKey] as! Screen
                let duration = notification.userInfo?[ScreenViewController.durationUserInfoKey] as! Double
                os_log("Screen Viewed: \"%@\", for %f seconds", screen.name, duration)
            },
            NotificationCenter.default.addObserver(forName: ScreenViewController.blockTappedNotification, object: nil, queue: nil) { notification in
                let block = notification.userInfo?[ScreenViewController.blockUserInfoKey] as! Block
                os_log("Block Tapped: \"%@\"", block.name)
            }
        ]
    }
    
    func stopObservingRoverNotifications() {
        observerTokens.forEach { token in
            NotificationCenter.default.removeObserver(token)
        }
    }
}
