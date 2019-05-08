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
        let log = OSLog(subsystem: "io.rover.Example", category: "Observer")
        
        observerTokens = [
            NotificationCenter.default.addObserver(forName: RoverViewController.experiencePresentedNotification, object: nil, queue: nil) { notification in
                let viewController = notification.object as! RoverViewController
                let experience = notification.userInfo?[RoverViewController.experienceUserInfoKey] as! Experience
                os_log(.default, log: log, "Experience Presented: \"%@\" (campaignID=%@)", experience.name, viewController.campaignID ?? "none")
            },
            NotificationCenter.default.addObserver(forName: RoverViewController.experienceDismissedNotification, object: nil, queue: nil) { notification in
                let viewController = notification.object as! RoverViewController
                let experience = notification.userInfo?[RoverViewController.experienceUserInfoKey] as! Experience
                os_log(.default, log: log, "Experience Dismissed: \"%@\" (campaignID=%@)", experience.name, viewController.campaignID ?? "none")
            },
            NotificationCenter.default.addObserver(forName: RoverViewController.experienceViewedNotification, object: nil, queue: nil) { notification in
                let viewController = notification.object as! RoverViewController
                let experience = notification.userInfo?[RoverViewController.experienceUserInfoKey] as! Experience
                let duration = notification.userInfo?[RoverViewController.durationUserInfoKey] as! Double
                os_log(.default, log: log, "Experience Viewed: \"%@\" (campaignID=%@), for %f seconds", experience.name, viewController.campaignID ?? "none", duration)
            },
            NotificationCenter.default.addObserver(forName: RoverViewController.screenPresentedNotification, object: nil, queue: nil) { notification in
                let screen = notification.userInfo?[RoverViewController.screenUserInfoKey] as! Screen
                os_log(.default, log: log, "Screen Presented: \"%@\"", screen.name)
            },
            NotificationCenter.default.addObserver(forName: RoverViewController.screenDismissedNotification, object: nil, queue: nil) { notification in
                let screen = notification.userInfo?[RoverViewController.screenUserInfoKey] as! Screen
                os_log(.default, log: log, "Screen Dismissed: \"%@\"", screen.name)
            },
            NotificationCenter.default.addObserver(forName: RoverViewController.screenViewedNotification, object: nil, queue: nil) { notification in
                let screen = notification.userInfo?[RoverViewController.screenUserInfoKey] as! Screen
                let duration = notification.userInfo?[RoverViewController.durationUserInfoKey] as! Double
                os_log(.default, log: log, "Screen Viewed: \"%@\", for %f seconds", screen.name, duration)
            },
            NotificationCenter.default.addObserver(forName: RoverViewController.blockTappedNotification, object: nil, queue: nil) { notification in
                let block = notification.userInfo?[RoverViewController.blockUserInfoKey] as! Block
                os_log(.default, log: log, "Block Tapped: \"%@\"", block.name)
            }
        ]
    }
    
    func stopObservingRoverNotifications() {
        observerTokens.forEach { token in
            NotificationCenter.default.removeObserver(token)
        }
    }
}
