//
//  Logger.swift
//  RoverFoundation
//
//  Created by Sean Rucker on 2017-08-11.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

import Foundation

public protocol Logger {
    func addObserver(block: @escaping (String, LogLevel) -> Void) -> NSObjectProtocol
    func removeObserver(_ token: NSObjectProtocol)
    
    @discardableResult func debug(_ message: String) -> String?
    @discardableResult func warn(_ message: String) -> String?
    @discardableResult func error(_ message: String) -> String?
    @discardableResult func warnUnlessMainThread(_ message: String) -> String?
    @discardableResult func warnIfMainThread(_ message: String) -> String?
}
