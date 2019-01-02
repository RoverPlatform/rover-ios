//
//  UI.OSLog.swift
//  RoverUI
//
//  Created by Andrew Clunis on 2018-11-16.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import os.log

extension OSLog {
    public static let ui = OSLog(subsystem: "io.rover", category: "UI")
}
