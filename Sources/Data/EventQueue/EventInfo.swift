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
import RoverFoundation

public struct EventInfo {
    public let name: String
    public let namespace: String?
    public let attributes: Attributes?
    public let timestamp: Date?
    
    public init(name: String, namespace: String? = nil, attributes: Attributes? = nil, timestamp: Date? = nil) {
        self.name = name
        self.namespace = namespace
        self.attributes = attributes
        self.timestamp = timestamp
    }
}

public extension EventInfo {
    /// Create an EventInfo that tracks a Screen Viewed event for Analytics use.  Use it for tracking screens & content in your app belonging to components other than Rover.
    init(
        screenViewedWithName screenName: String,
        contentID: String? = nil,
        contentName: String? = nil
    ) {
        let eventAttributes: Attributes = [:]
        
        eventAttributes["screenName"] = screenName
        
        if let contentID = contentID {
            eventAttributes["contentID"] = contentID
        }
        
        if let contentName = contentName {
            eventAttributes["contentName"] = contentName
        }

        // using a nil namespace to represent events for screens owned by the app vendor.
        self.init(name: "Screen Viewed", attributes: eventAttributes)
    }
}
