//
//  TelephonyInfoProvider.swift
//  RoverUI
//
//  Created by Sean Rucker on 2018-09-30.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

public protocol TelephonyInfoProvider: AnyObject {
    var carrierName: String? { get }
    var radio: String? { get }
}
