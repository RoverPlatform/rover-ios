//
//  TokenManager.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-02-16.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

public protocol TokenManager {
    var pushToken: String? { get }
    
    func setToken(_ data: Data)
    func removeToken()
}
