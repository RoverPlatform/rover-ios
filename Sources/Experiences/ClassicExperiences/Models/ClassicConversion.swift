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

public struct ClassicConversion: Decodable {
    public var tag: String
    public var expires: Duration
    
    
    public init(tag: String, expires: Duration) {
        self.tag = tag
        self.expires = expires
    }
}

public struct Duration: Decodable {
    public enum Unit: String, Decodable {
        case seconds = "s"
        case minutes = "m"
        case hours = "h"
        case days = "d"
    }
    
    public var value: Int
    public var unit: Unit
    
    
    public init(value: Int, unit: Unit) {
        self.value = value
        self.unit = unit
    }
    
    public var timeInterval: TimeInterval {
        let base: Int
        switch self.unit {
        case .seconds:
            base = 1
        case .minutes:
            base = 60
        case .hours:
            base = 60 * 60
        case .days:
            base = 24 * 60 * 60
        }
        return TimeInterval(self.value * base)
    }
}
