//
//  Common.swift
//  Pods
//
//  Created by Ata Namvari on 2016-01-29.
//
//

import Foundation

@objc enum LogLevel: Int {
    case Error = 0
    case Warn = 1
    case Info = 2
    case Debug = 3
    case Trace = 4
    case Report = 5
}

var logLevel: LogLevel = .Report

public let RoverLogReportNotification = "RoverLogReportNotification"

func rvLog(@autoclosure message: () -> String, data: Any? = nil, level: LogLevel = .Debug, filename: String = #file, function: String = #function, line: Int = #line) {
    
    if logLevel == .Report {
        let m = message()
        dispatch_async(dispatch_get_main_queue(), {
            NSNotificationCenter.defaultCenter().postNotificationName(RoverLogReportNotification, object: m)
        })
    }
    
    if !(level.rawValue > logLevel.rawValue) {
        print("Rover [\(level.rawValue)] - [\((filename as NSString).lastPathComponent).\(function) - Line \(line)] => \(message())")
        if (data != nil) {
            print("    - \(data!)")
        }
    }
    
}

var rvDateFormatter: NSDateFormatter {
    let dateFormatter = NSDateFormatter()
    let enUSPOSIXLocale = NSLocale(localeIdentifier: "en_US_POSIX")
    dateFormatter.locale = enUSPOSIXLocale
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZ"
    return dateFormatter
}