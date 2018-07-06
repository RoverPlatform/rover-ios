//
//  ReachabilityContextProvider.swift
//  RoverData
//
//  Created by Sean Rucker on 2017-08-14.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

class ReachabilityContextProvider: ContextProvider {
    let logger: Logger
    
    init(logger: Logger) {
        self.logger = logger
    }
    
    func captureContext(_ context: Context) -> Context {
        guard let reachability = Reachability(hostname: "google.com") else {
            logger.warn("Failed to initialize Reachability client")
            return context
        }
        
        var nextContext = context
        nextContext.isWifiEnabled = reachability.isReachableViaWiFi
        nextContext.isCellularEnabled = reachability.isReachableViaWWAN
        return nextContext
    }
}
