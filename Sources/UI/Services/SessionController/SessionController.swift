//
//  SessionController.swift
//  RoverUI
//
//  Created by Sean Rucker on 2018-05-21.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

public protocol SessionController: class {
    func registerSession(identifier: String, completionHandler: @escaping (Double) -> EventInfo)
    func unregisterSession(identifier: String)
}
