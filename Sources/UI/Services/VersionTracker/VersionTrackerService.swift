// Copyright (c) 2020-present, Rover Labs, Inc. All rights reserved.
// You are hereby granted a non-exclusive, worldwide, royalty-free license to use,
// copy, modify, and distribute this software in source code or binary form for use
// in connection with the web services and APIs provided by Rover.
//
// This copyright notice shall be included in all copies or substantial portions of 
// the software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import Foundation
import os.log
import RoverFoundation
import RoverData

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
