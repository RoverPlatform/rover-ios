//
//  Device.swift
//  Pods
//
//  Created by Ata Namvari on 2016-02-01.
//
//

import Foundation
import UIKit

enum Device {
    case CurrentDevice
    
    private static var _pushToken: String?
    static var pushToken: String? {
        get {
            guard _pushToken == nil else { return _pushToken }
            _pushToken = NSUserDefaults.standardUserDefaults().objectForKey("ROVER_PUSH_TOKEN") as? String
            return _pushToken
        }
        set {
            _pushToken = newValue
            NSUserDefaults.standardUserDefaults().setObject(newValue, forKey:"ROVER_PUSH_TOKEN")
        }
    }
    
    static var bluetoothOn: Bool = false
    
}