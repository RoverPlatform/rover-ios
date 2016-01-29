//
//  Config.swift
//  Pods
//
//  Created by Ata Namvari on 2016-01-21.
//
//

import Foundation

public struct Config {
    
    public var applicationToken: String
    public var allowedUserNotificationType: UIUserNotificationType = [.Alert, .Sound, .Badge]
    public var notificationSoundName: String?
    public var serverURL = "https://api.rover.io/v1"
    //public var loggingLevel = LogLevel.Warn
    
    
    public init (applicationToken: String) {
        self.applicationToken = applicationToken
        
    }
}