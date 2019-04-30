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
    
    // This AppDelegate method receives deep links.
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // Your app will likely have its own bespoke routing system for handling links. For the purposes of demonstration, a simple boilerplate example of how to handle deep links follows.  See the documentation for greater details.
        // 'rover-example-app' given here is set in Example/Example/Info.plist as a URL Scheme.
        if url.scheme == "rover-example-app" && url.host == "presentExperience" {
            // The following code demonstrates an simple example for parsing an arbitrarily selected URI scheme.
            let components = URLComponents.init(url: url, resolvingAgainstBaseURL: false)
            guard let experienceId = (components?.queryItems?.first { $0.name == "id" })?.value else {
                return false
            }
            let campaignId = components?.queryItems?.first { $0.name == "campaignID" }?.value
            
            let roverViewController = RoverViewController(experienceId: experienceId, campaignId: campaignId)
            
            // Use our UIApplication.present() helper extension method to find the currently active view controller, and present RoverViewController on top.
            app.present(
                roverViewController,
                animated: true
            )
        }
        return false
    }
    
    // This AppDelegate method receives receives universal links, amongst other things such as Handoff.
    func application(_ app: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        // Your app will likely have its own bespoke routing system for handling links. For the purposes of demonstration, a simple boilerplate example of how to handle universal links follows.  See the documentation for greater details.
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL else {
            return false
        }
        
        // 'example.rover.io' given here needs to be set in your App Links configuration and entitlements. See the documentation for further details.
        if url.host == "example.rover.io" {
            guard let roverViewController = RoverViewController(experienceUrl: url.absoluteString, campaignId: nil) else {
                // the URL did not parse properly, which should not occur here since the URL has arrived from the iOS framework.
                return false
            }
            
            // Use our UIApplication.present() helper extension method to find the currently active view controller, and present RoverViewController on top.
            app.present(
                roverViewController,
                animated: true
            )
            return true
        }
        return false
    }
}
