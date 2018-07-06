//
//  VersionTrackerService.swift
//  RoverUI
//
//  Created by Sean Rucker on 2018-06-21.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

class VersionTrackerService: VersionTracker {
    let bundle: Bundle
    let eventQueue: EventQueue
    let logger: Logger
    let userDefaults: UserDefaults
    
    init(bundle: Bundle, eventQueue: EventQueue, logger: Logger, userDefaults: UserDefaults) {
        self.bundle = bundle
        self.eventQueue = eventQueue
        self.logger = logger
        self.userDefaults = userDefaults
    }
    
    func checkAppVersion() {
        guard let info = bundle.infoDictionary else {
            logger.error("Failed to check app version – missing bundle info")
            return
        }
        
        logger.debug("Checking app version")
        
        let currentVersion = info["CFBundleShortVersionString"] as? String
        let currentBuild = info["CFBundleVersion"] as? String
        
        let versionString: (String?, String?) -> String = { version, build in
            if let version = version {
                if let build = build {
                    return "\(version) (\(build))"
                }
                
                return "\(version)"
            }
            
            return "n/a"
        }
        
        let currentVersionString = versionString(currentVersion, currentBuild)
        logger.debug("Current version: \(currentVersionString)")
        
        let previousVersion = userDefaults.string(forKey: "io.rover.appVersion")
        let previousBuild = userDefaults.string(forKey: "io.rover.appBuild")
        
        let previousVersionString = versionString(previousVersion, previousBuild)
        logger.debug("Previous version: \(previousVersionString)")
        
        if previousVersion == nil || previousBuild == nil {
            logger.debug("Previous version not found – first time running app with Rover")
            trackAppInstalled()
        } else if currentVersion != previousVersion || currentBuild != previousBuild {
            logger.debug("Current and previous versions do not match – app has been updated")
            trackAppUpdated(fromVersion: previousVersion, build: previousBuild)
        } else {
            logger.debug("Current and previous versions match – nothing to track")
        }
        
        userDefaults.set(currentVersion, forKey: "io.rover.appVersion")
        userDefaults.set(currentBuild, forKey: "io.rover.appBuild")
    }
    
    func trackAppInstalled() {
        let event = EventInfo(name: "App Installed", namespace: "rover")
        eventQueue.addEvent(event)
    }
    
    func trackAppUpdated(fromVersion previousVersion: String?, build previousBuild: String?) {
        var attributes = Attributes()
        if let previousVersion = previousVersion {
            attributes["previousVersion"] = previousVersion
        }
        
        if let previousBuild = previousBuild {
            attributes["previousBuild"] = previousBuild
        }
        
        let event = EventInfo(name: "App Updated", namespace: "rover", attributes: attributes)
        eventQueue.addEvent(event)
    }
}
