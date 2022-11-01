//
//  AdSupportManager.swift
//  RoverAdSupport
//
//  Created by Sean Rucker on 2018-10-22.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import AdSupport
#if !COCOAPODS
import RoverData
#endif

class AdSupportManager {
    let identifierManager = ASIdentifierManager.shared()
    
    init() { }
}

extension AdSupportManager: AdSupportContextProvider {
    var advertisingIdentifier: String? {
        guard self.identifierManager.isAdvertisingTrackingEnabled else {
            return nil
        }
        
        return self.identifierManager.advertisingIdentifier.uuidString
    }
}
