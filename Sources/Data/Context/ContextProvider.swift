//
//  ContextProvider.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-09-30.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

public protocol ContextProvider {
    var context: Context { get }
}
