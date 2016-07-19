//: Playground - noun: a place where people can play

import UIKit
import Foundation
import Rover

var rvDateFormatter: NSDateFormatter {
    let dateFormatter = NSDateFormatter()
    let enUSPOSIXLocale = NSLocale(localeIdentifier: "en_US_POSIX")
    dateFormatter.locale = enUSPOSIXLocale
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZ"
    return dateFormatter
}

rvDateFormatter.stringFromDate(NSDate())