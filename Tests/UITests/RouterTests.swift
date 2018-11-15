//
//  RouterTests.swift
//  RoverUITests
//
//  Created by Sean Rucker on 2018-11-15.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import XCTest
@testable import RoverUI

class RouterTests: XCTestCase {
    let router: Router = {
        let experienceViewControllerProvider: (ExperienceIdentifier) -> UIViewController = { _ in
            return UIViewController()
        }
        
        let settingsViewControllerProvider: () -> UIViewController = {
            UIViewController()
        }
        
        let notificationCenterViewControllerProvider: () -> UIViewController = {
            UIViewController()
        }
        
        return Router(
            associatedDomains: ["www.example.com"],
            urlSchemes: [], 
            experienceViewControllerProvider: experienceViewControllerProvider,
            settingsViewControllerProvider: settingsViewControllerProvider,
            notificationCenterViewControllerProvider: notificationCenterViewControllerProvider
        )
    }()
    
    func testValidUniversalLink() {
        let userActivity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        userActivity.webpageURL = URL(string: "https://www.example.com/my-experience")!
        let viewController = self.router.viewController(for: userActivity)
        XCTAssertNotNil(viewController)
    }
    
    func testInvalidUniversalLink() {
        let userActivity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        userActivity.webpageURL = URL(string: "https://www.invalid.com/my-experience")!
        let viewController = self.router.viewController(for: userActivity)
        XCTAssertNil(viewController)
    }
}
