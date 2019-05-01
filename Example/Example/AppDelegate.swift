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
        Rover.accountToken = "YOUR_SDK_TOKEN"
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // This app delegate method is called when any app (your own included) calls the `open(_:options:completionHandler:)` method on `UIApplication` with a URL that matches one of the schemes setup in your `Info.plist` file. These custom URL schemes are commonly referred to as "deep links". The `rover-example-app` scheme used below is set in Example/Example/Info.plist as a URL Scheme. Your app will likely have its own bespoke routing system for handling "deep links". For the purposes of demonstration, a simple boilerplate example follows. See the documentation for greater details.
        
        if url.scheme == "rover-example-app" && url.host == "presentExperience" {
            // Capture the ID of the Rover experience from the URL.
            let components = URLComponents.init(url: url, resolvingAgainstBaseURL: false)
            guard let experienceID = components?.queryItems?.first(where: { $0.name == "id" })?.value else {
                return false
            }
            
            // Capture the (optional) campaign ID from the URL.
            let campaignID = components?.queryItems?.first(where: { $0.name == "campaignID" })?.value
            
            // Instantiate a `RoverViewController` with the experience and (optional) campaign ID.
            let viewController = RoverViewController(experienceID: experienceID, campaignID: campaignID)
            
            // Use our UIApplication.present() helper extension method to find the currently active view controller, and present RoverViewController on top.
            app.present(viewController, animated: true)
            return true
        }
        
        return false
    }
    
    func application(_ app: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        // This app delegate method is called in response to the user opening a Universal Link, amongst other things such as Handoff. Before we continue, check `activityType` to see if this method was called in response to a Universal Link.
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL else {
            return false
        }
        
        // Check the URL to see if the domain matches the one assigned to your Rover account. the `example.rover.io` domain used below needs to be set in your App Links configuration and entitlements. See the documentation for further details.
        if url.host == "example.rover.io" {
            let roverViewController = RoverViewController(experienceURL: url)
            
            // Use our UIApplication.present() helper extension method to find the currently active view controller, and present RoverViewController on top.
            app.present(roverViewController, animated: true)
            return true
        }
        
        return false
    }
}
