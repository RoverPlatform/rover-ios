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

import CoreLocation

extension CLRegion {
    public func reportsSame(region: CLRegion) -> Bool {
        if type(of: self) != type(of: region) {
            return false
        }
        
        switch self {
        case is CLBeaconRegion:
            return self.reportsSame(region: region as! CLBeaconRegion)
        case is CLCircularRegion:
            return self.reportsSame(region: region as! CLCircularRegion)
        default: return false
        }
    }

    public func tagIdentifier(tag: String) -> CLRegion {
        switch self {
        case is CLBeaconRegion:
            return CLBeaconRegion(
                uuid: (self as! CLBeaconRegion).uuid,
                identifier: "\(tag):\(self.identifier)"
            )
        case is CLCircularRegion:
            return CLCircularRegion(
                center: (self as! CLCircularRegion).center,
                radius: (self as! CLCircularRegion).radius,
                identifier: "\(tag):\(self.identifier)"
            )
        default:
            fatalError("Provided object is not a known subclass of CLRegion.")
        }
    }
    func untaggedIdentifier(tag: String) -> String {
        let tagPrefix = "\(tag):"
        guard self.identifier.hasPrefix(tagPrefix) else {
            return self.identifier
        }
        return String(self.identifier.dropFirst(tagPrefix.count))
        
    }
}
