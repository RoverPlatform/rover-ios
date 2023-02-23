// Copyright (c) 2020-present, Rover Labs, Inc. All rights reserved.
// You are hereby granted a non-exclusive, worldwide, royalty-free license to use,
// copy, modify, and distribute this software in source code or binary form for use
// in connection with the web services and APIs provided by Rover.
//
// This copyright notice shall be included in all copies or substantial portions of 
// the software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import CoreTelephony
import os.log
import RoverData

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
