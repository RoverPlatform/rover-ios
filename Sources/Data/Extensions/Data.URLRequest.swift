//
//  URLRequest.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-09-11.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation
import UIKit
#if !COCOAPODS
import RoverFoundation
#endif

extension URLRequest {
    public mutating func setAccountToken(_ accountToken: String) {
        self.setValue(accountToken, forHTTPHeaderField: "x-rover-account-token")
    }

    /// Replace the standard CFNetwork-created User Agent with a more useful one.
    mutating func setRoverUserAgent() {
        // we want to add the Rover SDK version to the User Agent. Sadly, we cannot get our hands on the default user agent sent by CFNetwork, so we have to start from scratch, including reproducing the fields in the stock user agent:
        
        // AppName/$version. (a value exists for this by default, but this version is a bit better than the stock version of this value, which has the app build number rather than version)
        let appBundleDict = Bundle.main.infoDictionary
        let appName = appBundleDict?["CFBundleName"] as? String ?? "unknown"
        let appVersion = appBundleDict?["CFBundleShortVersionString"] as? String ?? "unknown"
        let appDescriptor = appName + "/" + appVersion
        
        // CFNetwork/$version (reproducing it; it exists in the standard iOS user agent, and perhaps some ops tooling will benefit from it being stock)
        let cfNetworkInfo = Bundle(identifier: "com.apple.CFNetwork")?.infoDictionary
        let cfNetworkVersion = cfNetworkInfo?["CFBundleShortVersionString"] as? String ?? "unknown"
        let cfNetworkDescriptor = "CFNetwork/\(cfNetworkVersion)"
        
        // Darwin/$version (reproducing it; it exists in the standard iOS user agent, and perhaps some ops tooling will benefit from it being stock)
        var sysinfo = utsname()
        uname(&sysinfo)
        let dv = String(bytes: Data(bytes: &sysinfo.release, count: Int(_SYS_NAMELEN)), encoding: .ascii)?.trimmingCharacters(in: .controlCharacters) ?? "unknown"
        let darwinDescriptor = "Darwin/\(dv)"
        
        // iOS/$ios-version
        let osDescriptor = "iOS/" + UIDevice.current.systemVersion
        
        // RoverSDK/$rover-sdk-version
        

        let roverVersion = Meta.SDKVersion
        self.setValue("\(appDescriptor) \(cfNetworkDescriptor) \(darwinDescriptor) \(osDescriptor) RoverCampaignsSDK/\(roverVersion)", forHTTPHeaderField: "User-Agent")
    }
}
