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
import RoverFoundation

extension CLBeaconRegion {
    public var attributes: Attributes {
        var attributes: [String: Any] = [
            "uuid": uuid.uuidString
        ]
        
        if let major = major {
            attributes["major"] = major.intValue
        }
        
        if let minor = minor {
            attributes["minor"] = minor.intValue
        }
        
        return Attributes(rawValue: attributes)
    }
    
    public func reportsSame(region: CLBeaconRegion) -> Bool {
        return uuid == region.uuid &&
        major == region.major &&
        minor == region.minor
    }
}
