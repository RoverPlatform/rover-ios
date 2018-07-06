//
//  DebugContextProvider.swift
//  RoverDebug
//
//  Created by Sean Rucker on 2018-06-25.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

class DebugContextProvider: ContextProvider {
    let testDeviceManager: TestDeviceManager
    
    init(testDeviceManager: TestDeviceManager) {
        self.testDeviceManager = testDeviceManager
    }
    
    func captureContext(_ context: Context) -> Context {
        var nextContext = context
        nextContext.isTestDevice = testDeviceManager.isTestDevice
        return nextContext
    }
}
