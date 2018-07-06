//
//  PushTokenContextProvider.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-05-22.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

struct PushTokenContextProvider: ContextProvider {
    let tokenManager: TokenManager
    
    func captureContext(_ context: Context) -> Context {
        var nextContext = context
        nextContext.pushToken = tokenManager.pushToken
        return nextContext
    }
}
