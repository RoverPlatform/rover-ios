//
//  AdSupportContextProvider.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-10-22.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

public protocol AdSupportContextProvider: AnyObject {
    var advertisingIdentifier: String? { get }
}
