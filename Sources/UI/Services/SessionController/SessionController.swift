//
//  SessionController.swift
//  RoverUI
//
//  Created by Sean Rucker on 2018-05-21.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

#if !COCOAPODS
import RoverData
#endif

public protocol SessionController: AnyObject {
    func registerSession(identifier: String, completionHandler: @escaping (Double) -> EventInfo)
    func unregisterSession(identifier: String)
}
