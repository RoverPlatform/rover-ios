//
//  AppDelegate.swift
//  Rover
//
//  Created by ata_n on 01/05/2016.
//  Copyright (c) 2016 ata_n. All rights reserved.
//

import UIKit
import Rover

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        
        setupRover()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(didUpdateAccount), name: RoverAccountUpdatedNotification, object: nil)
        
        // Override point for customization after application launch.
        return true
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
        
        Rover.didReceiveRemoteNotification(userInfo, fetchCompletionHandler: completionHandler)
    }
    
    func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject]) {
        
    }
    
    func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
        Rover.didRegisterForRemoteNotification(deviceToken: deviceToken)
    }
    
    func application(application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: NSError) {

    }
    
    func setupRover() {
        AccountManager.sharedManager
        if let account = AccountManager.currentAccount {
            Rover.setup(applicationToken: account.applicationToken)
            Rover.registerForNotifications()
        }
    }
    
    func didUpdateAccount(note: NSNotification) {
        setupRover()
    }

}