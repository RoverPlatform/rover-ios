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

import Foundation
import UIKit
import RoverFoundation

extension URLRequest {
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
        self.setValue("\(appDescriptor) \(cfNetworkDescriptor) \(darwinDescriptor) \(osDescriptor) RoverSDK/\(roverVersion)", forHTTPHeaderField: "User-Agent")
    }
}
