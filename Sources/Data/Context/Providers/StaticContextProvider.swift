//
//  StaticContextProvider.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-09-30.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

public protocol StaticContextProvider: AnyObject {
    var appBadgeNumber: Int { get }
    var appBuild: String { get }
    var appIdentifier: String { get }
    var appVersion: String { get }
    var buildEnvironment: Context.BuildEnvironment { get }
    var deviceIdentifier: String { get }
    var deviceManufacturer: String { get }
    var deviceModel: String { get }
    var deviceName: String { get }
    var operatingSystemName: String { get }
    var operatingSystemVersion: String { get }
    var screenHeight: Int { get }
    var screenWidth: Int { get }
    var sdkVersion: String { get }
}
