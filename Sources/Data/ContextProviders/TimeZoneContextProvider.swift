//
//  TimeZoneContextProvider.swift
//  RoverData
//
//  Created by Sean Rucker on 2017-08-14.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

import Foundation

class TimeZoneContextProvider {
    let timeZone: NSTimeZone
    
    var timeZoneName: String {
        return timeZone.name
    }
    
    init(timeZone: NSTimeZone) {
        self.timeZone = timeZone
    }
}

// MARK: ContextProvider

extension TimeZoneContextProvider: ContextProvider {
    func captureContext(_ context: Context) -> Context {
        var nextContext = context
        nextContext.timeZone = timeZoneName
        return nextContext
    }
}
