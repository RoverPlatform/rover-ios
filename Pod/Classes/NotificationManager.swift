//
//  NotificationManager.swift
//  Pods
//
//  Created by Ata Namvari on 2016-01-21.
//
//

import Foundation
import UIKit

public class NotificationManager {

    public func registerForRemoteNotifications () {
        UIApplication.sharedApplication().registerForRemoteNotifications()
        UIApplicationDidBecomeActiveNotification
    }
    
}