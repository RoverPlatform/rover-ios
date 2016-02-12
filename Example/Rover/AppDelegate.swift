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
        
        
        Rover.setup(applicationToken: "0628d761f3cebf6a586aa02cc4648bd2") // has to happen on app startup
    
        Rover.startMonitoring() // asks for location permissions
        Rover.registerForNotifications() // asks for notification permissions
        
        //Rover.identify("my@email.address")
        //Rover.user.setAttribute(key: "myKey", value: "myValue")
        
        
        //Rover.addObserver(SomeObjectConformingToRoverInterface)
        
        // Override point for customization after application launch.
        return true
    }

    func application(application: UIApplication, didReceiveLocalNotification notification: UILocalNotification) {
//        if Rover.didReceiveLocalNotification(notification) {
//            return;
//        }
    }
    
    func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject]) {
//        if Rover.didReceiveRemoteNotification(userInfo: userInfo) {
//            return;
//        }
    }
    
    func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
        Rover.didRegisterForRemoteNotification(deviceToken: deviceToken)
    }
    
    func application(application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: NSError) {

    }


}

