//
//  TelephonyManager.swift
//  RoverTelephony
//
//  Created by Sean Rucker on 2018-10-22.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import CoreTelephony
import os.log
#if !COCOAPODS
import RoverData
#endif

class TelephonyManager {
    let telephonyNetworkInfo = CTTelephonyNetworkInfo()
    
    init() { }
}

extension TelephonyManager: TelephonyContextProvider {
    var carrierName: String? {
        guard let carrierName = telephonyNetworkInfo.subscriberCellularProvider?.carrierName else {
            os_log("Failed to capture carrier name (this is expected behaviour if you are running a simulator)", log: .telephony, type: .debug)
            return nil
        }
        
        return carrierName
    }
    
    var radio: String? {
        var radio = telephonyNetworkInfo.currentRadioAccessTechnology
        let prefix = "CTRadioAccessTechnology"
        if radio == nil {
            radio = "None"
        } else if radio!.hasPrefix(prefix) {
            radio = (radio! as NSString).substring(from: prefix.count)
        }
        
        if let radio = radio {
            return radio
        } else {
            os_log("Failed to capture radio", log: .telephony, type: .debug)
            return nil
        }
    }
}
