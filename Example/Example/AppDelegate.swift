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
        Rover.accountToken = "blank"
        return true
    }
    
    // This AppDelegate overrides receives 
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if url.host == "presentExperience" {
            let components = URLComponents.init(url: url, resolvingAgainstBaseURL: false)
            guard let experienceId = (components?.queryItems?.first { $0.name == "id" })?.value else {
                return false
            }
            let campaignId = components?.queryItems?.first { $0.name == "campaignID" }?.value
            
            // TODO: conversation with Sean here about what guidance to provide to iOS developers about launching the freshly minted RoverViewController.
            // Do we include boilerplate analagous to the Action object in 2.x, which has "smarts" in it for discovering the kind of active view controller is up (tab bar, nav, or modal "presented" view controller), and grabbing what it's currently showing, and presenting on top of it?  or just leave that up to the customers?
            app.present(
                RoverViewController(experienceId: experienceId, campaignId: campaignId),
                animated: true
            )
        }
        return false
    }


}

