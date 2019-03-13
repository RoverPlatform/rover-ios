//
//  NotificationCenterObserver.swift
//  RoverCampaignsData
//
//  Created by Andrew Clunis on 2019-03-12.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation
import os

class NotificationCenterObserver {
    // The naming convention for NotificationCenter events is "did" or "will".
    
    // Explicit? ExperienceDidEmitEvent
    // Open-ended? RoverEmitterDidEmitEvent
    
    init() {
//        NotificationCenter.default.addObserver(forName: "RoverEmitterDidEmitEvent", object: nil, queue: nil) { notification in
//            os_log("GOT EVENT")
//        }
    }
}
