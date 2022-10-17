//
//  InfluenceTracker.swift
//  RoverNotifications
//
//  Created by Sean Rucker on 2018-03-11.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

public protocol InfluenceTracker {
    func startMonitoring()
    func stopMonitoring()
    func clearLastReceivedNotification()
}
