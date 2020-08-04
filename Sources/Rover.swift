//
//  Rover.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-03-13.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation
import UIKit

/// Set your Rover Account Token (API Key) here.
public var accountToken: String? {
    didSet {
        Analytics.shared.enable()
    }
}
