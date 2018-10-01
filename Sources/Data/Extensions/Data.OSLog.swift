//
//  OSLog.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-09-27.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import os.log

extension OSLog {
    public static let context = OSLog(subsystem: "io.rover", category: "Context")
    public static let events = OSLog(subsystem: "io.rover", category: "Events")
    public static let networking = OSLog(subsystem: "io.rover", category: "Networking")
    public static let persistence = OSLog(subsystem: "io.rover", category: "Persistence")
    public static let sync = OSLog(subsystem: "io.rover", category: "Sync")
}
