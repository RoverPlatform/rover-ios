//
//  AttributesContextProvider.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-02-08.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

struct AttributesContextProvider: ContextProvider {
    let deviceAttributes: DeviceAttributes
    
    func captureContext(_ context: Context) -> Context {
        var nextContext = context
        nextContext.attributes = deviceAttributes.current()
        return nextContext
    }
}
