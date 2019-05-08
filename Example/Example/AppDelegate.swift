//
//  AppDelegate.swift
//  Example
//
//  Created by Andrew Clunis on 2019-04-26.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import os.log
import Rover
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    // As an alternative to implementing a `RoverViewControllerDelegate` you can observe `Notification`s sent by the
    // `RoverViewController` through the default `NotificationCenter`. The `ExampleRoverViewControllerObserver` shows
    // how you can observe these `Notification`s and extract data from the `userInfo`.
    let exampleRoverViewControllerObserver = ExampleRoverViewControllerObserver()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Pass your account token from the Rover Settings app to the Rover SDK.
        Rover.accountToken = "<YOUR_SDK_TOKEN>"
        return true
    }
    
    // This app delegate method is called when any app (your own included) calls the
    // `open(_:options:completionHandler:)` method on `UIApplication` with a URL that matches one of the schemes setup
    // in your `Info.plist` file. These custom URL schemes are commonly referred to as "deep links". This Example app
    // uses a custom URL scheme `example` which is configured in Example/Example/Info.plist.
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
            app.present(roverViewController, animated: true)
            return true
        }
        
        return false
    }
}
