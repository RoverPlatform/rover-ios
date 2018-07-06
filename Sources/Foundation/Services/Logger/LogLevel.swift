//
//  LogLevel.swift
//  RoverFoundation
//
//  Created by Sean Rucker on 2017-08-17.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

public enum LogLevel: Int, CustomStringConvertible {
    case debug
    case warn
    case error
    case none
    
    public var description: String {
        switch self {
        case .debug:
            return "Debug"
        case .warn:
            return "Warn"
        case .error:
            return "Error"
        case .none:
            return ""
        }
    }
}
