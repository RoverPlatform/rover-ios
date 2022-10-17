//
//  TokenManager.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-09-29.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

public protocol TokenManager {
    func setToken(_ deviceToken: Data)
}
