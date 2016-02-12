//
//  Common.swift
//  Pods
//
//  Created by Ata Namvari on 2016-01-29.
//
//

import Foundation

enum LogLevel: Int {
    case Error = 0
    case Warn = 1
    case Info = 2
    case Debug = 3
    case Trace = 4
}

var logLevel: LogLevel = .Debug

func rvLog(@autoclosure message: () -> String, level: LogLevel = .Debug, filename: String = __FILE__, function: String = __FUNCTION__, line: Int = __LINE__) {
    
    if !(level.rawValue > logLevel.rawValue) {
        print("Rover [\(level)] - [\((filename as NSString).lastPathComponent).\(function) - Line \(line)] => \(message())")
    }
    
}
