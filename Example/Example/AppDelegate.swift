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
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Pass your account token from the Rover Settings app to the Rover SDK.
        Rover.accountToken = "<YOUR_SDK_TOKEN>"
        
        // Enable reporting of various Rover "events" such as when an experience is viewed or a button in a Rover
        // experience is tapped.
        Rover.Analytics.shared.enable()
        
        // This method demonstrates how to observe the Rover events mentioned above in your own app.
        observeRoverNotifications()
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
   
    // This method demonstrates how to observe various Rover "events" such as when an experience is viewed or a
    // button in a Rover experience is tapped. This is particularly useful for integrating with your mobile analytics
    // or marketing auotmation provider. The Rover documentation provides specific examples for many of the popular
    // providers.
    func observeRoverNotifications() {
        NotificationCenter.default.addObserver(forName: ExperienceViewController.experiencePresentedNotification, object: nil, queue: nil) { notification in
            let campaignID = notification.userInfo?[ExperienceViewController.campaignIDUserInfoKey] as? String
            let experience = notification.userInfo?[ExperienceViewController.experienceUserInfoKey] as! Experience
            os_log("Experience Presented: \"%@\" (campaignID=%@)", experience.name, campaignID ?? "none")
        }
        
        NotificationCenter.default.addObserver(forName: ExperienceViewController.experienceDismissedNotification, object: nil, queue: nil) { notification in
            let campaignID = notification.userInfo?[ExperienceViewController.campaignIDUserInfoKey] as? String
            let experience = notification.userInfo?[ExperienceViewController.experienceUserInfoKey] as! Experience
            os_log("Experience Dismissed: \"%@\" (campaignID=%@)", experience.name, campaignID ?? "none")
        }
        
        NotificationCenter.default.addObserver(forName: ExperienceViewController.experienceViewedNotification, object: nil, queue: nil) { notification in
            let campaignID = notification.userInfo?[ExperienceViewController.campaignIDUserInfoKey] as? String
            let experience = notification.userInfo?[ExperienceViewController.experienceUserInfoKey] as! Experience
            let duration = notification.userInfo?[ExperienceViewController.durationUserInfoKey] as! Double
            os_log("Experience Viewed: \"%@\" (campaignID=%@), for %f seconds", experience.name, campaignID ?? "none", duration)
        }
        
        NotificationCenter.default.addObserver(forName: ScreenViewController.screenPresentedNotification, object: nil, queue: nil) { notification in
            let screen = notification.userInfo?[ScreenViewController.screenUserInfoKey] as! Screen
            os_log("Screen Presented: \"%@\"", screen.name)
        }
        
        NotificationCenter.default.addObserver(forName: ScreenViewController.screenDismissedNotification, object: nil, queue: nil) { notification in
            let screen = notification.userInfo?[ScreenViewController.screenUserInfoKey] as! Screen
            os_log("Screen Dismissed: \"%@\"", screen.name)
        }
        
        NotificationCenter.default.addObserver(forName: ScreenViewController.screenViewedNotification, object: nil, queue: nil) { notification in
            let screen = notification.userInfo?[ScreenViewController.screenUserInfoKey] as! Screen
            let duration = notification.userInfo?[ScreenViewController.durationUserInfoKey] as! Double
            os_log("Screen Viewed: \"%@\", for %f seconds", screen.name, duration)
        }
        
        NotificationCenter.default.addObserver(forName: ScreenViewController.blockTappedNotification, object: nil, queue: nil) { notification in
            let block = notification.userInfo?[ScreenViewController.blockUserInfoKey] as! Block
            os_log("Block Tapped: \"%@\"", block.name)
        }
    }
}
