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
    let settingsViewController = UIViewController()
    let notificationCenterViewController = UIViewController()
    
    lazy var router: Router = {
        let experienceViewControllerProvider: (ExperienceIdentifier) -> UIViewController = { [weak self] identifier in
            DummyExperienceViewController(experienceIdentifier: identifier)
        }

        let settingsViewControllerProvider: () -> UIViewController = { [weak self] in
            self!.settingsViewController
        }

        let notificationCenterViewControllerProvider: () -> UIViewController = { [weak self] in
            self!.notificationCenterViewController
        }
        
        return Router(
            associatedDomains: ["www.example.com"],
            urlSchemes: ["rv-test-suite"],
            experienceViewControllerProvider: experienceViewControllerProvider,
            settingsViewControllerProvider: settingsViewControllerProvider,
            notificationCenterViewControllerProvider: notificationCenterViewControllerProvider
        )
    }()
    
    func testLinkThroughUserActivity() {
        let userActivity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        userActivity.webpageURL = URL(string: "https://www.example.com/my-experience")!
        let viewController = self.router.viewController(for: userActivity)
        XCTAssertNotNil(viewController)
    }
    
    func testValidUniversalLink() {
        let userActivity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        userActivity.webpageURL = URL(string: "https://www.example.com/my-experience")!
        let viewController = self.router.viewController(for: userActivity) as! DummyExperienceViewController
        XCTAssertEqual(viewController.experienceIdentifier, ExperienceIdentifier.campaignURL(url: URL(string: "https://www.example.com/my-experience")!))
    }
    
    func testInvalidUniversalLink() {
        let viewController = self.router.viewController(for: URL(string: "https://www.invalid.com/my-experience")!)
        XCTAssertNil(viewController)
    }
    
    func testValidSettingsDeepLink() {
        let viewController = self.router.viewController(for: URL(string: "rv-test-suite://settings")!)
        XCTAssertEqual(viewController, settingsViewController)
    }
    
    func testValidLegacySettingsDeepLink() {
        let viewController = self.router.viewController(for: URL(string: "rv-test-suite://presentSettings")!)
        XCTAssertEqual(viewController, settingsViewController)
    }
    
    func testValidExperienceDeepLink() {
        let viewController = self.router.viewController(for: URL(string: "rv-test-suite://experience?id=deadbeef")!) as! DummyExperienceViewController
        XCTAssertEqual(viewController.experienceIdentifier, ExperienceIdentifier.experienceID(id: "deadbeef"))
    }
    
    func testValidCampaignDeepLink() {
        let viewController = self.router.viewController(for: URL(string: "rv-test-suite://experience?campaignID=deadbeef")!) as! DummyExperienceViewController
        XCTAssertEqual(viewController.experienceIdentifier, ExperienceIdentifier.campaignID(id: "deadbeef"))
    }
    
    func testInvalidCampaignDeepLink() {
        let viewController = self.router.viewController(for: URL(string: "rv-test-suite://experience?foo=bar")!) as? DummyExperienceViewController
        XCTAssertNil(viewController)
    }
    
    func testValidLegacyExperienceDeepLink() {
        let viewController = self.router.viewController(for: URL(string: "rv-test-suite://presentExperience?id=deadbeef")!)  as! DummyExperienceViewController
        XCTAssertEqual(viewController.experienceIdentifier, ExperienceIdentifier.experienceID(id: "deadbeef"))
    }
    
    func testValidNotificationCenterDeepLink() {
        let viewController = self.router.viewController(for: URL(string: "rv-test-suite://notificationCenter")!)
        XCTAssertEqual(viewController, notificationCenterViewController)
    }
    
    func testValidNotificationCenterSettingsDeepLink() {
        let viewController = self.router.viewController(for: URL(string: "rv-test-suite://presentNotificationCenter")!)
        XCTAssertEqual(viewController, notificationCenterViewController)
    }
    
    class DummyExperienceViewController: UIViewController {
        let experienceIdentifier: ExperienceIdentifier
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("No NSCoding in tests.")
        }
        
        init(experienceIdentifier: ExperienceIdentifier) {
            self.experienceIdentifier = experienceIdentifier
            super.init(nibName: nil, bundle: nil)
        }
    }
}
