//
//  OSLog.swift
//  RoverLocation
//
//  Created by Sean Rucker on 2018-09-27.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import os.log

extension OSLog {
    public static let location = OSLog(subsystem: "io.rover", category: "Location")
}
