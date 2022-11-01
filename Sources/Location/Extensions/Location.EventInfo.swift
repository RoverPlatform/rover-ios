//
//  EventInfo.swift
//  RoverLocation
//
//  Created by Sean Rucker on 2018-09-20.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

#if !COCOAPODS
import RoverData
#endif

extension EventInfo {
    static let locationUpdate = EventInfo(name: "Location Updated", namespace: "rover")
}
