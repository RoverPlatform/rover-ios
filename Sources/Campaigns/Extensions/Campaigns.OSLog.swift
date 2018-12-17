//
//  OSLog.swift
//  RoverCampaigns
//
//  Created by Sean Rucker on 2018-09-27.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.

import os.log

extension OSLog {
    public static let campaigns = OSLog(subsystem: "io.rover", category: "Campaigns")
}
