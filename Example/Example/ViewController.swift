//
//  ViewController.swift
//  Example
//
//  Created by Sean Rucker on 2019-04-30.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import RoverFoundation
import UIKit

class ViewController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Add the notification center to the tab bar
        let notificationCenter = RoverFoundation.shared!.resolve(UIViewController.self, name: "notificationCenter")!
        notificationCenter.tabBarItem = UITabBarItem(title: "Notifications", image: nil, tag: 0)
        
        // Add the settings view controller to the tab bar.  Note that you typically wouldn't want to add this to the tab bar in your application.  Refer to the documentation.
        let settingsViewController = RoverFoundation.shared!.resolve(UIViewController.self, name: "settings")!
        settingsViewController.tabBarItem = UITabBarItem(title: "Settings", image: nil, tag: 0)
        
        viewControllers = [
            notificationCenter,
            settingsViewController
        ]
    }
}
