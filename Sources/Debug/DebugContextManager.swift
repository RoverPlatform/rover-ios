//
//  DebugContextManager.swift
//  RoverDebug
//
//  Created by Sean Rucker on 2018-06-25.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

class DebugContextManager {
    let persistedValue = PersistedValue<Bool>(storageKey: "io.rover.RoverDebug.isTestDevice")
    
    init() { }
}

extension DebugContextManager: DebugContextProvider {
    var isTestDevice: Bool {
        return persistedValue.value ?? false
    }
}
