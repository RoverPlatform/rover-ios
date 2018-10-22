//
//  Telephony.OSLog.swift
//  RoverTelephony
//
//  Created by Sean Rucker on 2018-10-22.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import os.log

extension OSLog {
    public static let telephony = OSLog(subsystem: "io.rover", category: "Telephony")
}
