//
//  AppDelegate.swift
//  Example
//
//  Created by Andrew Clunis on 2019-04-26.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import UIKit
import Rover

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        return true
    }
    
    // This AppDelegate overrides receives 
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if url.host == "presentExperience" {
            let components = URLComponents.init(url: url, resolvingAgainstBaseURL: false)
            guard let experienceId = components?.queryItems?.first { $0.name == "id" }?.value {
                return false
            }
            let campaignId = components?.queryItems?.first { $0.name == "campaignID" }?.value
            
            RoverViewController(identifier: <#T##ExperienceIdentifier#>)
        }
        return false
    }


}

