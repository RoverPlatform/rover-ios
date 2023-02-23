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

public struct Event: Codable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case namespace
        case attributes
        case context = "device"
        case timestamp
    }
    
    public let id = UUID()
    
    public var name: String
    public var namespace: String?
    public var attributes: Attributes?
    public var context: Context
    public var timestamp: Date
    
    public init(name: String, context: Context, namespace: String? = nil, attributes: Attributes? = nil, timestamp: Date = Date()) {
        self.name = name
        self.namespace = namespace
        self.attributes = attributes
        self.context = context
        self.timestamp = timestamp
    }
}

// MARK: Hashable

extension Event: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id.hashValue)
    }
}
