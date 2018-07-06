//
//  AppContextProvider.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-02-08.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UIKit

class AppContextProvider: ContextProvider {
    let bundle: Bundle
    let logger: Logger
    
    lazy var info: [String: Any] = {
        var info = [String: Any]()
        
        if let infoDictionary = bundle.infoDictionary {
            for (key, value) in infoDictionary {
                info[key] = value
            }
        } else {
            logger.warn("Failed to load infoDictionary from bundle")
        }
        
        if let localizedInfoDictionary = bundle.localizedInfoDictionary {
            for (key, value) in localizedInfoDictionary {
                info[key] = value
            }
        }
        
        return info
    }()
    
    lazy var appVersion: String? = {
        guard let shortVersion = info["CFBundleShortVersionString"] as? String else {
            logger.warn("Failed to capture appVersion")
            return nil
        }
        
        return shortVersion
    }()
    
    lazy var appBuild: String? = {
        guard let bundleVersion = info["CFBundleVersion"] as? String else {
            logger.warn("Failed to capture appBuild")
            return nil
        }
        
        return bundleVersion
    }()
    
    lazy var appIdentifier: String? = {
        guard let bundleIdentifier = bundle.bundleIdentifier else {
            logger.warn("Failed to capture appNamespace")
            return nil
        }
        
        return bundleIdentifier
    }()
    
    var badgeNumber: Int? {
        if Thread.isMainThread {
            return UIApplication.shared.applicationIconBadgeNumber
        } else {
            return DispatchQueue.main.sync {
                return UIApplication.shared.applicationIconBadgeNumber
            }
        }
    }
    
    init(bundle: Bundle, logger: Logger) {
        self.bundle = bundle
        self.logger = logger
    }
    
    func captureContext(_ context: Context) -> Context {
        var nextContext = context
        nextContext.appVersion = appVersion
        nextContext.appBuild = appBuild
        nextContext.appIdentifier = appIdentifier
        nextContext.appBadgeNumber = badgeNumber
        return nextContext
    }
}
