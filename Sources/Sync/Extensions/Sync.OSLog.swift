//
//  Sync.OSLog.swift
//  RoverSync
//
//  Created by Andrew Clunis on 2018-11-16.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import os.log

extension OSLog {
    public static let networking = OSLog(subsystem: "io.rover", category: "Networking")
    public static let sync = OSLog(subsystem: "io.rover", category: "Sync")
}
