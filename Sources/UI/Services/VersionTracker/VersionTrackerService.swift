//
//  VersionTrackerService.swift
//  RoverUI
//
//  Created by Sean Rucker on 2018-06-21.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation
import os.log
#if !COCOAPODS
import RoverFoundation
import RoverData
#endif

class VersionTrackerService: VersionTracker {
    let bundle: Bundle
    let eventQueue: EventQueue
    let userDefaults: UserDefaults
    
    init(bundle: Bundle, eventQueue: EventQueue, userDefaults: UserDefaults) {
        self.bundle = bundle
        self.eventQueue = eventQueue
        self.userDefaults = userDefaults
    }
    
    func checkAppVersion() {
        guard let info = bundle.infoDictionary else {
            os_log("Failed to check app version – missing bundle info", log: .general, type: .error)
            return
        }
        
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
        os_log("Current version: %@", log: .general, type: .debug, currentVersionString)
        
        let previousVersion = userDefaults.string(forKey: "io.rover.appVersion")
        let previousBuild = userDefaults.string(forKey: "io.rover.appBuild")
        
        let previousVersionString = versionString(previousVersion, previousBuild)
        os_log("Previous version: %@", log: .general, type: .debug, previousVersionString)
        
        if previousVersion == nil || previousBuild == nil {
            os_log("Previous version not found – first time running app with Rover", log: .general, type: .debug)
            trackAppInstalled()
        } else if currentVersion != previousVersion || currentBuild != previousBuild {
            os_log("Current and previous versions do not match – app has been updated", log: .general, type: .debug)
            trackAppUpdated(fromVersion: previousVersion, build: previousBuild)
        } else {
            os_log("Current and previous versions match – nothing to track", log: .general, type: .debug)
        }
        
        userDefaults.set(currentVersion, forKey: "io.rover.appVersion")
        userDefaults.set(currentBuild, forKey: "io.rover.appBuild")
    }
    
    func trackAppInstalled() {
        let event = EventInfo(name: "App Installed", namespace: "rover")
        eventQueue.addEvent(event)
    }
    
    func trackAppUpdated(fromVersion previousVersion: String?, build previousBuild: String?) {
        let attributes = Attributes()
        if let previousVersion = previousVersion {
            attributes.rawValue["previousVersion"] = previousVersion
        }
        
        if let previousBuild = previousBuild {
            attributes.rawValue["previousBuild"] = previousBuild
        }
        
        let event = EventInfo(name: "App Updated", namespace: "rover", attributes: attributes)
        eventQueue.addEvent(event)
    }
}
