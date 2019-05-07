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
        // Pass your account token from the Rover Settings app to the Rover SDK.
        Rover.accountToken = "<YOUR_SDK_TOKEN>"
        return true
    }
    
    // This app delegate method is called when any app (your own included) calls the
    // `open(_:options:completionHandler:)` method on `UIApplication` with a URL that matches one of the schemes setup
    // in your `Info.plist` file. These custom URL schemes are commonly referred to as "deep links". This Example app
    // uses a custom URL scheme `example`  which is configured in Example/Example/Info.plist.
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        
        // You will need to setup a specific URL structure to be used for presenting Rover experiences in your app. The
        // simplest approach is to use a specific URL path/host and include the experience ID and (optional) campaign
        // ID as query parameters. The below example demonstrates how to route URLs in the format
        // `example://experience?id=<EXPERIENCE_ID>&campaignID=<CAMPAIGN_ID>` to a Rover experience.
        if url.host == "experience" {
            guard let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else {
                return false
            }
            
            guard let experienceID = queryItems.first(where: { $0.name == "id" })?.value else {
                return false
            }
            
            let campaignID = queryItems.first(where: { $0.name == "campaignID" })?.value
            let viewController = RoverViewController(experienceID: experienceID, campaignID: campaignID)
            
            // Optionally assign a delegate to the view controller to be notified when certain experience "events"
            // occur. E.g. when a screen is displayed or a block is tapped. This example assigns the app delegate itself
            // as the `RoverViewController`'s delegate. This of course requires your app delegate to implement the
            // `RoverViewControllerDelegate` protocol. 
            viewController.delegate = self
            
            // Use Rover's UIApplication.present() helper extension method to find the currently active view controller,
            // and present the RoverViewController on top.
            app.present(viewController, animated: true)
            return true
        }
        
        // If the standard approach above does not meet your needs you can setup any arbitrary URL to launch a Rover
        // experience as long as you can extract the experience ID from it. For example you could use a path based
        // approach which includes the experience ID and optional campaign ID as path components instead of query
        // string parameters. The below example demonstrates how to route URLs in the format
        // `example://experience/<EXPERIENCE_ID>/<CAMPAIGN_ID>` to a Rover experience.
        if let host = url.host, host.starts(with: "experience") {
            let components = host.components(separatedBy: "/")
            guard components.indices.contains(1) else {
                return false
            }
            
            let experienceID = components[1]
            let campaignID = components.indices.contains(2) ? components[2] : nil
            let viewController = RoverViewController(experienceID: experienceID, campaignID: campaignID)
            app.present(viewController, animated: true)
            return true
        }
        
        return false
    }
    
    // This app delegate method is called in response to the user opening a Universal Link, amongst other things such
    // as Handoff.
    func application(_ app: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        
        // Check `activityType` to see if this method was called in response to a Universal Link.
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL else {
            return false
        }
        
        // Check the URL to see if the domain matches the one assigned to your Rover account. The `example.rover.io`
        // domain used below needs to be set in your App Links configuration and entitlements. See the documentation
        // for further details.
        if url.host == "example.rover.io" {
            let roverViewController = RoverViewController(experienceURL: url)
            
            // Use our UIApplication.present() helper extension method to find the currently active view controller,
            // and present RoverViewController on top.
            app.present(roverViewController, animated: true)
            return true
        }
        
        return false
    }
}

// Extending your app delegate to implement the `RoverViewControllerDelegate` allows it app to be notified when certain
// experience "events" occur. E.g. when a screen is displayed or a block is tapped. In order for this to function you
// must assign your app delegate as the `RoverViewController` delegate after it is instantiated. An example of this can
// be found in the `application(_:open:options:)` implementation above where we are handling deep links and presenting
// the `RoverViewController`.
//
// E.g. viewController.delegate = self
extension AppDelegate: RoverViewControllerDelegate {
    func viewController(_ viewController: RoverViewController, didPresentExperience experience: Experience) {
        print("Experience Presented", experience.name)
    }
    
    func viewController(_ viewController: RoverViewController, didDismissExperience experience: Experience) {
        print("Experience Dismissed", experience.name)
    }
    
    func viewController(_ viewController: RoverViewController, didViewExperience experience: Experience, duration: Double) {
        print("Experience Viewed", experience.name, duration)
    }
    
    func viewController(_ viewController: RoverViewController, didPresentScreen screen: Screen, experience: Experience) {
        print("Screen Presented", screen.name, experience.name)
    }
    
    func viewController(_ viewController: RoverViewController, didDismissScreen screen: Screen, experience: Experience) {
        print("Screen Dismissed", screen.name, experience.name)
    }
    
    func viewController(_ viewController: RoverViewController, didViewScreen screen: Screen, experience: Experience, duration: Double) {
        print("Screen Viewed", screen.name, experience.name, duration)
    }
    
    func viewController(_ viewController: RoverViewController, didTapBlock block: Block, screen: Screen, experience: Experience) {
        print("Block Tapped", block.name, screen.name, experience.name)
    }
}
