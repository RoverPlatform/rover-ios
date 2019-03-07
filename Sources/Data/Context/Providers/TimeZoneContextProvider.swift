//
//  TimeZoneContextProvider.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-09-30.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

public protocol TimeZoneContextProvider: AnyObject {
    var timeZone: String { get }
}
