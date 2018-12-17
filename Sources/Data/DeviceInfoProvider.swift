//
//  DeviceInfoProvider.swift
//  RoverData
//
//  Created by Andrew Clunis on 2018-12-12.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

public protocol DeviceInfoProvider {
    var deviceSnapshot: DeviceSnapshot { get }
}
