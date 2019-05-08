//
//  ExampleRoverViewControllerDelegate.swift
//  Example
//
//  Created by Sean Rucker on 2019-05-08.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import os.log
import Rover

class ExampleRoverViewControllerDelegate: RoverViewControllerDelegate {
    private let log = OSLog(subsystem: "io.rover.Example", category: "Delegate")
    
    func viewController(_ viewController: RoverViewController, didPresentExperience experience: Experience) {
        os_log(.default, log: log, "Experience Presented: \"%@\" (campaignID=%@)", experience.name, viewController.campaignID ?? "none")
    }
    
    func viewController(_ viewController: RoverViewController, didDismissExperience experience: Experience) {
        os_log(.default, log: log, "Experience Dismissed: \"%@\" (campaignID=%@)", experience.name, viewController.campaignID ?? "none")
    }
    
    func viewController(_ viewController: RoverViewController, didViewExperience experience: Experience, duration: Double) {
        os_log(.default, log: log, "Experience Viewed: \"%@\" (campaignID=%@), for %f seconds", experience.name, viewController.campaignID ?? "none", duration)
    }
    
    func viewController(_ viewController: RoverViewController, didPresentScreen screen: Screen, experience: Experience) {
        os_log(.default, log: log, "Screen Presented: \"%@\"", screen.name)
    }
    
    func viewController(_ viewController: RoverViewController, didDismissScreen screen: Screen, experience: Experience) {
        os_log(.default, log: log, "Screen Dismissed: \"%@\"", screen.name)
    }
    
    func viewController(_ viewController: RoverViewController, didViewScreen screen: Screen, experience: Experience, duration: Double) {
        os_log(.default, log: log, "Screen Viewed: \"%@\", for %f seconds", screen.name, duration)
    }
    
    func viewController(_ viewController: RoverViewController, didTapBlock block: Block, screen: Screen, experience: Experience) {
        os_log(.default, log: log, "Block Tapped: \"%@\"", block.name)
    }
}
