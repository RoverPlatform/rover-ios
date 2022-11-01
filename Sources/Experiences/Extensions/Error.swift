//
//  Error.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-08-09.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation

extension Error {
    /// Give a more verbose description of an error (particularly, including any details in `userInfo`).
    var debugDescription: String {
        return "Error: \(self.localizedDescription), details: \((self as NSError).userInfo.debugDescription)"
    }
}
