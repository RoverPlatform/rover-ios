//
//  SDKContextProvider.swift
//  RoverFoundation
//
//  Created by Sean Rucker on 2018-06-15.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

class SDKContextProvider: ContextProvider {
    let logger: Logger
    
    lazy var bundle: Bundle? = {
        if let bundle = Bundle(identifier: "io.rover.RoverFoundation") {
            return bundle
        }
        
        if let bundle = Bundle(identifier: "org.cocoapods.Rover") {
            return bundle
        }
        
        logger.error("Failed to capture SDK version: No bundle found with identifier io.rover.RoverFoundation or org.cocoapods.Rover")
        return nil
    }()
    
    lazy var version: String? = {
        guard let bundle = bundle else {
            return nil
        }
        
        guard let dictionary = bundle.infoDictionary else {
            logger.error("Failed to capture SDK version: Invalid bundle")
            return nil
        }
        
        guard let version = dictionary["CFBundleShortVersionString"] as? String else {
            logger.error("Failed to capture SDK version: No version found in bundle")
            return nil
        }
        
        return version
    }()
    
    init(logger: Logger) {
        self.logger = logger
    }
    
    func captureContext(_ context: Context) -> Context {
        guard let version = version else {
            return context
        }
        
        var nextContext = context
        nextContext.sdkVersion = version
        return nextContext
    }
}
