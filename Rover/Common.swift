//
//  Common.swift
//  Pods
//
//  Created by Ata Namvari on 2016-01-29.
//
//

import Foundation

@objc enum LogLevel: Int {
    case error = 0
    case warn = 1
    case info = 2
    case debug = 3
    case trace = 4
    case report = 5
}

var logLevel: LogLevel = .report

public let RoverLogReportNotification = "RoverLogReportNotification"

func rvLog(_ message: @autoclosure () -> String, data: Any? = nil, level: LogLevel = .debug, filename: String = #file, function: String = #function, line: Int = #line) {
    
    if logLevel == .report {
        let m = message()
        DispatchQueue.main.async(execute: {
            NotificationCenter.default.post(name: Notification.Name(rawValue: RoverLogReportNotification), object: m)
        })
    }
    
    if !(level.rawValue > logLevel.rawValue) {
        print("Rover [\(level.rawValue)] - [\((filename as NSString).lastPathComponent).\(function) - Line \(line)] => \(message())")
        if (data != nil) {
            print("    - \(data!)")
        }
    }
    
}

var rvDateFormatter: DateFormatter {
    let dateFormatter = DateFormatter()
    let enUSPOSIXLocale = Locale(identifier: "en_US_POSIX")
    dateFormatter.locale = enUSPOSIXLocale
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZ"
    return dateFormatter
}
