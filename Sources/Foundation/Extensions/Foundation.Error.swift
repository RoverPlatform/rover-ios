//
//  Error.swift
//  RoverCampaigns
//
//  Created by Andrew Clunis on 2020-01-30.
//  Copyright © 2020 Rover Labs Inc. All rights reserved.
//

import Foundation

public extension Error {
    /// Give a more verbose description of an error (particularly, including any details in `userInfo`).
    var logDescription: String {
        return "Error: \(self.localizedDescription), details: \((self as NSError).userInfo.debugDescription)"
    }
}
