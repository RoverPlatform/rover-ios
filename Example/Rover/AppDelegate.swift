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
        
        Router.baseURLString = {
            if let url = NSUserDefaults.standardUserDefaults().stringForKey("ROVER_SERVER_URL") {
                return url
            }
            return "https://rover-content-api-development.herokuapp.com/v1"
        }()
        
        Rover.setup(applicationToken: "6c546189dc45df1293bddc18c0b54786")
        //Rover.setup(applicationToken: "0628d761f3cebf6a586aa02cc4648bd2") // has to happen on app startup
        Rover.addObserver(self)
    
        //Rover.startMonitoring() // asks for location permissions
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
        
        Rover.didReceiveLocalNotification(notification)
    }
    
    
    func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
        Rover.didReceiveRemoteNotification(userInfo, fetchCompletionHandler: completionHandler)
    }
    
    func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
        Rover.didRegisterForRemoteNotification(deviceToken: deviceToken)
    }
    
    func application(application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: NSError) {

    }


}

extension AppDelegate : RoverObserver {
    
    func didDeliverMessage(message: Message) {
//        if UIApplication.sharedApplication().applicationState == .Active {
//            let alert = UIAlertView(title: message.title, message: message.text, delegate: nil, cancelButtonTitle: "OK")
//            alert.show()
//        }
    }
    
}