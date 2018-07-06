//
//  ContextProvider.swift
//  RoverData
//
//  Created by Sean Rucker on 2017-09-01.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

public protocol ContextProvider {
    func captureContext(_ context: Context) -> Context
}
