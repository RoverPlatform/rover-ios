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

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        setupRover()
        
        NotificationCenter.default.addObserver(self, selector: #selector(didUpdateAccount), name: NSNotification.Name(rawValue: RoverAccountUpdatedNotification), object: nil)
        
        #if DEBUG
            Rover.isDevelopment = true
        #else
            Rover.isDevelopment = false
        #endif
        //Rover.isDevelopment = true
        // Override point for customization after application launch.
        return true
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
        Rover.didReceiveRemoteNotification(userInfo, fetchCompletionHandler: nil)
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("token: \(deviceToken)")
        Rover.didRegisterForRemoteNotification(deviceToken: deviceToken)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {

    }
    
    func setupRover() {
        AccountManager.sharedManager
        if let account = AccountManager.currentAccount {
            Rover.setup(applicationToken: account.applicationToken)
            Rover.registerForNotifications()
        }
    }
    
    func didUpdateAccount(_ note: Notification) {
        setupRover()
    }
    
    func application(_ application: UIApplication, handleOpen url: URL) -> Bool {
        print("url: \(url)")
        return true
    }

}
