//
//  UserInfo.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-02-15.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

public protocol UserInfo {
    func restore()
    func current() -> Attributes
    func update(_ block: (inout Attributes) -> Void)
    func clear()
}
