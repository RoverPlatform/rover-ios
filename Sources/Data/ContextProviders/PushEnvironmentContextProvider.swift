//
//  PushEnvironmentContextProvider.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-05-22.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

class PushEnvironmentContextProvider: ContextProvider {
    let bundle: Bundle
    let logger: Logger
    
    lazy var pushEnvironment: String? = {
        guard let path = bundle.path(forResource: "embedded", ofType: "mobileprovision") else {
            logger.warn("Could not detect push environment: Provisioning profile not found (this is expected behaviour if you are running a simulator)")
            return "production"
        }
        
        guard let embeddedProfile = try? String(contentsOfFile: path, encoding: String.Encoding.ascii) else {
            logger.warn("Could not detect push environment: Failed to read provisioning profile at \(path)")
            return "production"
        }
        
        let scanner = Scanner(string: embeddedProfile)
        var string: NSString?
        
        guard scanner.scanUpTo("<?xml version=\"1.0\" encoding=\"UTF-8\"?>", into: nil), scanner.scanUpTo("</plist>", into: &string) else {
            logger.warn("Could not detect push environment: Unrecognized provisioning profile structure")
            return "production"
        }
        
        guard let data = string?.appending("</plist>").data(using: String.Encoding.utf8) else {
            logger.warn("Could not detect push environment: Failed to decode provisioning profile")
            return "production"
        }
        
        guard let plist = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any] else {
            logger.warn("Could not detect push environment: Failed to serialize provisioning profile")
            return "production"
        }
        
        guard let entitlements = plist["Entitlements"] as? [String: Any] else {
            logger.warn("Could not detect push environment: No entitlements found in provisioning profile")
            return "production"
        }
        
        guard let pushEnvironment = entitlements["aps-environment"] as? String else {
            logger.warn("Could not detect push environment: aps environment missing from entitlements")
            return "production"
        }
        
        return pushEnvironment
    }()
    
    init(bundle: Bundle, logger: Logger) {
        self.bundle = bundle
        self.logger = logger
    }
    
    func captureContext(_ context: Context) -> Context {
        var nextContext = context
        nextContext.pushEnvironment = pushEnvironment
        return nextContext
    }
}
