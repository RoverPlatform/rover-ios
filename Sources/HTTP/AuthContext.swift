//
//  AuthContext.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-03-20.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation

/// Describes how to reach and authenticate with Rover's cloud services.
public struct AuthContext {
    var accountToken: String?
    var endpoint: URL
}
